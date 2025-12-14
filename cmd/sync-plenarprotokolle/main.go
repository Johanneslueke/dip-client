package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	"github.com/Johanneslueke/dip-client/internal/utility"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	var (
		baseURL       = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey        = flag.String("key", "", "API key")
		dbPath        = flag.String("db", "dip.db", "SQLite database path")
		limit         = flag.Int("limit", 0, "Maximum number of plenarprotokolle to fetch (0 = all)")
		checkpointDir = flag.String("checkpoint-dir", ".checkpoints", "Directory to store checkpoints")
		failedDir     = flag.String("failed-dir", ".failed", "Directory to store failed record IDs")
		resume        = flag.Bool("resume", false, "Resume from last checkpoint")
		end           = flag.String("end", "", "End date for sync (YYYY-MM-DD)")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	dipClient, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create API client: %v", err)
	}

	sqlDB, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer sqlDB.Close()

	sqlDB.SetMaxOpenConns(24)
	sqlDB.SetMaxIdleConns(24)
	sqlDB.SetConnMaxLifetime(time.Hour)

	if err := utility.RunMigrations(sqlDB); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	queries := db.New(sqlDB)
	ctx := context.Background()
	limiter := utility.NewRateLimiter(120, time.Minute)
	progress := utility.NewProgressTracker(*limit)
	failedTracker := utility.NewFailedRecordsTracker(*failedDir, "plenarprotokolle")

	// Checkpoint and signal handling
	var datumEnd *openapi_types.Date
	var lastProcessedDate time.Time
	interrupted := false

	if *resume {
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "plenarprotokolle")
		if err != nil {
			log.Printf("Warning: Failed to load checkpoint: %v", err)
		} else if checkpoint != nil {
			lastProcessedDate = checkpoint.LastSyncDate
			date := openapi_types.Date{Time: lastProcessedDate}
			datumEnd = &date
			log.Printf("Resuming from checkpoint: %s", lastProcessedDate.Format("2006-01-02"))
		}
	}

	if *end != "" {
		endTime, err := time.Parse("2006-01-02", *end)
		if err != nil {
			log.Fatalf("Invalid end date format: %v", err)
		}
		date := openapi_types.Date{Time: endTime}
		datumEnd = &date
	}

	signalHandler := utility.NewSignalHandler(
		func() {
			interrupted = true
			if !lastProcessedDate.IsZero() {
				if err := utility.SaveCheckpoint(*checkpointDir, "plenarprotokolle", lastProcessedDate); err != nil {
					log.Printf("Error saving checkpoint: %v", err)
				} else {
					log.Printf("Checkpoint saved at %s", lastProcessedDate.Format("2006-01-02"))
				}
			}
		},
		nil,
	)
	defer signalHandler.Stop()

	var cursor *string

	log.Printf("Starting to fetch plenarprotokolle from API...")

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println() // New line after progress updates
			log.Printf("Interrupted after processing %d plenarprotokolle", progress.Total)
			return
		}

		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetPlenarprotokollListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		resp, err := dipClient.GetPlenarprotokollList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch plenarprotokolle: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.Total += len(resp.Documents)
		progress.PrintProgress(progress.Total, int(resp.NumFound))

		for _, plenarprotokoll := range resp.Documents {
			storePlenarprotokoll(ctx, queries, plenarprotokoll, failedTracker)

			// Track the last processed date for checkpoint
			if plenarprotokoll.Aktualisiert.After(lastProcessedDate) {
				lastProcessedDate = plenarprotokoll.Aktualisiert
			}

			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d plenarprotokolle", *limit)
				goto done
			}
		}

		if resp.Cursor == "" {
			break
		}
		cursor = &resp.Cursor
	}

done:
	fmt.Println() // New line after progress updates
	elapsed, rate := progress.GetStats()
	log.Printf("Successfully stored %d plenarprotokolle in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))

	// Save failed records if any
	if failedTracker.Count() > 0 {
		if err := failedTracker.Save(); err != nil {
			log.Printf("Warning: Failed to save failed records: %v", err)
		} else {
			log.Printf("⚠️  %d records failed due to DB locks, saved to %s/plenarprotokolle.failed.json", failedTracker.Count(), *failedDir)
		}
	}

	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "plenarprotokolle"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storePlenarprotokoll(ctx context.Context, q *db.Queries, plenarprotokoll client.Plenarprotokoll, failedTracker *utility.FailedRecordsTracker) {
	existing, err := q.GetPlenarprotokoll(ctx, plenarprotokoll.Id)
	if err != nil && err != sql.ErrNoRows {
		failedTracker.RecordIfDBLocked(plenarprotokoll.Id, "GetPlenarprotokoll", err)
		log.Printf("Warning: Failed to check if plenarprotokoll %s exists: %v", plenarprotokoll.Id, err)
		return
	}

	ptrToNullString := func(s *string) sql.NullString {
		if s == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: *s, Valid: true}
	}

	ptrIntToNullInt64 := func(i *int) sql.NullInt64 {
		if i == nil {
			return sql.NullInt64{Valid: false}
		}
		return sql.NullInt64{Int64: int64(*i), Valid: true}
	}

	ptrInt32ToNullInt64 := func(i *int32) sql.NullInt64 {
		if i == nil {
			return sql.NullInt64{Valid: false}
		}
		return sql.NullInt64{Int64: int64(*i), Valid: true}
	}

	quadrantToNullString := func(q *client.Quadrant) sql.NullString {
		if q == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: string(*q), Valid: true}
	}

	// Extract Fundstelle fields
	fundstelle := plenarprotokoll.Fundstelle
	params := db.CreatePlenarprotokollParams{
		ID:                        plenarprotokoll.Id,
		Titel:                     plenarprotokoll.Titel,
		Dokumentnummer:            plenarprotokoll.Dokumentnummer,
		Dokumentart:               string(plenarprotokoll.Dokumentart),
		Typ:                       string(plenarprotokoll.Typ),
		Herausgeber:               string(plenarprotokoll.Herausgeber),
		Datum:                     plenarprotokoll.Datum.String(),
		Aktualisiert:              plenarprotokoll.Aktualisiert.Format(time.RFC3339),
		PdfHash:                   ptrToNullString(plenarprotokoll.PdfHash),
		Sitzungsbemerkung:         ptrToNullString(plenarprotokoll.Sitzungsbemerkung),
		VorgangsbezugAnzahl:       int64(plenarprotokoll.VorgangsbezugAnzahl),
		Wahlperiode:               ptrInt32ToNullInt64(plenarprotokoll.Wahlperiode),
		FundstelleDokumentnummer:  fundstelle.Dokumentnummer,
		FundstelleDatum:           fundstelle.Datum.String(),
		FundstelleDokumentart:     string(fundstelle.Dokumentart),
		FundstelleHerausgeber:     string(fundstelle.Herausgeber),
		FundstelleID:              fundstelle.Id,
		FundstelleAnfangsseite:    ptrIntToNullInt64(fundstelle.Anfangsseite),
		FundstelleEndseite:        ptrIntToNullInt64(fundstelle.Endseite),
		FundstelleAnfangsquadrant: quadrantToNullString(fundstelle.Anfangsquadrant),
		FundstelleEndquadrant:     quadrantToNullString(fundstelle.Endquadrant),
		FundstelleSeite:           ptrToNullString(fundstelle.Seite),
		FundstellePdfUrl:          ptrToNullString(fundstelle.PdfUrl),
		FundstelleTop:             ptrInt32ToNullInt64(fundstelle.Top),
		FundstelleTopZusatz:       ptrToNullString(fundstelle.TopZusatz),
	}

	if existing.ID != "" {
		updateParams := db.UpdatePlenarprotokollParams{
			ID:                  plenarprotokoll.Id,
			Titel:               params.Titel,
			Aktualisiert:        params.Aktualisiert,
			PdfHash:             params.PdfHash,
			Sitzungsbemerkung:   params.Sitzungsbemerkung,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
		}
		if _, err := q.UpdatePlenarprotokoll(ctx, updateParams); err != nil {
			failedTracker.RecordIfDBLocked(plenarprotokoll.Id, "UpdatePlenarprotokoll", err)
			log.Printf("Warning: Failed to update plenarprotokoll %s: %v", plenarprotokoll.Id, err)
			return
		}
	} else {
		if _, err := q.CreatePlenarprotokoll(ctx, params); err != nil {
			failedTracker.RecordIfDBLocked(plenarprotokoll.Id, "CreatePlenarprotokoll", err)
			log.Printf("Warning: Failed to create plenarprotokoll %s: %v", plenarprotokoll.Id, err)
			return
		}
	}

	// Store vorgangsbezug
	if plenarprotokoll.Vorgangsbezug != nil {
		for idx, bezug := range *plenarprotokoll.Vorgangsbezug {
			if err := q.CreatePlenarprotokollVorgangsbezug(ctx, db.CreatePlenarprotokollVorgangsbezugParams{
				PlenarprotokollID: plenarprotokoll.Id,
				VorgangID:         bezug.Id,
				Titel:             bezug.Titel,
				Vorgangstyp:       bezug.Vorgangstyp,
				DisplayOrder:      int64(idx),
			}); err != nil {
				failedTracker.RecordIfDBLocked(plenarprotokoll.Id, "CreatePlenarprotokollVorgangsbezug", err)
				log.Printf("Warning: Failed to store vorgangsbezug for plenarprotokoll %s: %v", plenarprotokoll.Id, err)
			}
		}
	}
}
