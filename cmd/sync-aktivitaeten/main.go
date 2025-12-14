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
		limit         = flag.Int("limit", 0, "Maximum number of aktivitäten to fetch (0 = all)")
		checkpointDir = flag.String("checkpoint-dir", ".checkpoints", "Directory to store checkpoints")
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
	limiter := utility.NewRateLimiter(23, time.Minute)
	progress := utility.NewProgressTracker(*limit)

	// Checkpoint and signal handling
	var datumEnd *openapi_types.Date
	var lastProcessedDate time.Time
	interrupted := false

	if *resume {
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "aktivitaeten")
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
				if err := utility.SaveCheckpoint(*checkpointDir, "aktivitaeten", lastProcessedDate); err != nil {
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

	log.Printf("Starting to fetch aktivitäten from API...")

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println() // New line after progress updates
			log.Printf("Interrupted after processing %d aktivitäten", progress.Total)
			return
		}

		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetAktivitaetListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		resp, err := dipClient.GetAktivitaetList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch aktivitäten: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, aktivitaet := range resp.Documents {
			if err := storeAktivitaet(ctx, queries, aktivitaet); err != nil {
				log.Printf("Warning: Failed to store aktivitaet %s: %v", aktivitaet.Id, err)
			}

			// Track the last processed date for checkpoint
			if aktivitaet.Aktualisiert.After(lastProcessedDate) {
				lastProcessedDate = aktivitaet.Aktualisiert
			}

			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d aktivitäten", *limit)
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
	log.Printf("Successfully stored %d aktivitäten in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))

	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "aktivitaeten"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storeAktivitaet(ctx context.Context, q *db.Queries, aktivitaet client.Aktivitaet) error {
	existing, err := q.GetAktivitaet(ctx, aktivitaet.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("failed to check if aktivitaet exists: %w", err)
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

	dateToNullString := func(d *openapi_types.Date) sql.NullString {
		if d == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: d.String(), Valid: true}
	}

	// Extract Fundstelle fields
	fundstelle := aktivitaet.Fundstelle
	params := db.CreateAktivitaetParams{
		ID:                        aktivitaet.Id,
		Titel:                     aktivitaet.Titel,
		Aktivitaetsart:            aktivitaet.Aktivitaetsart,
		Typ:                       string(aktivitaet.Typ),
		Dokumentart:               string(aktivitaet.Dokumentart),
		Datum:                     aktivitaet.Datum.String(),
		Aktualisiert:              aktivitaet.Aktualisiert.Format(time.RFC3339),
		Abstract:                  ptrToNullString(aktivitaet.Abstract),
		VorgangsbezugAnzahl:       int64(aktivitaet.VorgangsbezugAnzahl),
		Wahlperiode:               int64(aktivitaet.Wahlperiode),
		FundstelleDokumentnummer:  fundstelle.Dokumentnummer,
		FundstelleDatum:           fundstelle.Datum.String(),
		FundstelleDokumentart:     string(fundstelle.Dokumentart),
		FundstelleHerausgeber:     string(fundstelle.Herausgeber),
		FundstelleID:              fundstelle.Id,
		FundstelleDrucksachetyp:   ptrToNullString(fundstelle.Drucksachetyp),
		FundstelleAnlagen:         ptrToNullString(fundstelle.Anlagen),
		FundstelleAnfangsseite:    ptrIntToNullInt64(fundstelle.Anfangsseite),
		FundstelleEndseite:        ptrIntToNullInt64(fundstelle.Endseite),
		FundstelleAnfangsquadrant: quadrantToNullString(fundstelle.Anfangsquadrant),
		FundstelleEndquadrant:     quadrantToNullString(fundstelle.Endquadrant),
		FundstelleSeite:           ptrToNullString(fundstelle.Seite),
		FundstellePdfUrl:          ptrToNullString(fundstelle.PdfUrl),
		FundstelleTop:             ptrInt32ToNullInt64(fundstelle.Top),
		FundstelleTopZusatz:       ptrToNullString(fundstelle.TopZusatz),
		FundstelleFrageNummer:     ptrToNullString(fundstelle.FrageNummer),
		FundstelleVerteildatum:    dateToNullString(fundstelle.Verteildatum),
	}

	if existing.ID != "" {
		updateParams := db.UpdateAktivitaetParams{
			ID:                  aktivitaet.Id,
			Titel:               params.Titel,
			Aktivitaetsart:      params.Aktivitaetsart,
			Aktualisiert:        params.Aktualisiert,
			Abstract:            params.Abstract,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
		}
		if _, err := q.UpdateAktivitaet(ctx, updateParams); err != nil {
			return fmt.Errorf("failed to update aktivitaet: %w", err)
		}
	} else {
		if _, err := q.CreateAktivitaet(ctx, params); err != nil {
			return fmt.Errorf("failed to create aktivitaet: %w", err)
		}
	}

	// Store deskriptors
	if aktivitaet.Deskriptor != nil {
		for _, desk := range *aktivitaet.Deskriptor {
			if _, err := q.CreateAktivitaetDeskriptor(ctx, db.CreateAktivitaetDeskriptorParams{
				AktivitaetID: aktivitaet.Id,
				Name:         desk.Name,
				Typ:          string(desk.Typ),
			}); err != nil {
				log.Printf("Warning: Failed to store deskriptor for aktivitaet %s: %v", aktivitaet.Id, err)
			}
		}
	}

	// Store vorgangsbezug
	if aktivitaet.Vorgangsbezug != nil {
		for idx, bezug := range *aktivitaet.Vorgangsbezug {
			if err := q.CreateAktivitaetVorgangsbezug(ctx, db.CreateAktivitaetVorgangsbezugParams{
				AktivitaetID:     aktivitaet.Id,
				VorgangID:        bezug.Id,
				Titel:            bezug.Titel,
				Vorgangsposition: bezug.Vorgangsposition,
				Vorgangstyp:      bezug.Vorgangstyp,
				DisplayOrder:     int64(idx),
			}); err != nil {
				log.Printf("Warning: Failed to store vorgangsbezug for aktivitaet %s: %v", aktivitaet.Id, err)
			}
		}
	}

	return nil
}
