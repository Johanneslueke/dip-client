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
		limit         = flag.Int("limit", 0, "Maximum number of drucksachen to fetch (0 = all)")
		end           = flag.String("end", "", "Fetch drucksachen up to this date (YYYY-MM-DD)")
		checkpointDir = flag.String("checkpoint-dir", ".checkpoints", "Directory to store checkpoint files")
		resume        = flag.Bool("resume", false, "Resume from last checkpoint")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	var datumEnd *openapi_types.Date
	
	// Check for checkpoint if resume flag is set
	if *resume {
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "drucksachen")
		if err != nil {
			log.Printf("Warning: Failed to load checkpoint: %v", err)
		} else if checkpoint != nil {
			datumEnd = &openapi_types.Date{Time: checkpoint.LastSyncDate}
			log.Printf("Resuming from checkpoint: %s", checkpoint.LastSyncDate.Format("2006-01-02"))
		}
	}
	
	// Command line --end flag overrides checkpoint
	if *end != "" {
		val, err := time.Parse("2006-01-02", *end)
		if err != nil {
			log.Fatalf("Invalid end date: %v", err)
		}
		datumEnd = &openapi_types.Date{Time: val}
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

	var cursor *string
	var lastProcessedDate time.Time
	interrupted := false

	// Setup signal handler to save checkpoint on interrupt
	signalHandler := utility.NewSignalHandler(
		func() {
			// First signal: save checkpoint
			interrupted = true
			if !lastProcessedDate.IsZero() {
				if err := utility.SaveCheckpoint(*checkpointDir, "drucksachen", lastProcessedDate); err != nil {
					log.Printf("Error saving checkpoint: %v", err)
				} else {
					log.Printf("Checkpoint saved: %s", lastProcessedDate.Format("2006-01-02"))
				}
			}
		},
		nil, // No second signal callback
	)
	defer signalHandler.Stop()

	log.Printf("Starting to fetch drucksachen from API...")

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println() // New line after progress updates
			log.Printf("Interrupted after processing %d drucksachen", progress.Total)
			return
		}

		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetDrucksacheListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		resp, err := dipClient.GetDrucksacheList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch drucksachen: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, drucksache := range resp.Documents {
			if err := storeDrucksache(ctx, queries, drucksache); err != nil {
				log.Printf("Warning: Failed to store drucksache %s: %v", drucksache.Id, err)
			}
			
			// Track the last processed date for checkpoint
			if drucksache.Datum.Time.After(lastProcessedDate) {
				lastProcessedDate = drucksache.Datum.Time
			}
			
			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d drucksachen", *limit)
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
	log.Printf("Successfully stored %d drucksachen in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))
	
	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "drucksachen"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storeDrucksache(ctx context.Context, q *db.Queries, drucksache client.Drucksache) error {
	existing, err := q.GetDrucksache(ctx, drucksache.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("failed to check if drucksache exists: %w", err)
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
	fundstelle := drucksache.Fundstelle
	params := db.CreateDrucksacheParams{
		ID:                        drucksache.Id,
		Titel:                     drucksache.Titel,
		Dokumentnummer:            drucksache.Dokumentnummer,
		Dokumentart:               string(drucksache.Dokumentart),
		Typ:                       string(drucksache.Typ),
		Drucksachetyp:             drucksache.Drucksachetyp,
		Herausgeber:               string(drucksache.Herausgeber),
		Datum:                     drucksache.Datum.String(),
		Aktualisiert:              drucksache.Aktualisiert.Format(time.RFC3339),
		Anlagen:                   ptrToNullString(drucksache.Anlagen),
		AutorenAnzahl:             int64(drucksache.AutorenAnzahl),
		VorgangsbezugAnzahl:       int64(drucksache.VorgangsbezugAnzahl),
		PdfHash:                   ptrToNullString(drucksache.PdfHash),
		Wahlperiode:               ptrInt32ToNullInt64(drucksache.Wahlperiode),
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
		updateParams := db.UpdateDrucksacheParams{
			ID:                  drucksache.Id,
			Titel:               params.Titel,
			Aktualisiert:        params.Aktualisiert,
			Anlagen:             params.Anlagen,
			AutorenAnzahl:       params.AutorenAnzahl,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
			PdfHash:             params.PdfHash,
		}
		if _, err := q.UpdateDrucksache(ctx, updateParams); err != nil {
			return fmt.Errorf("failed to update drucksache: %w", err)
		}
	} else {
		if _, err := q.CreateDrucksache(ctx, params); err != nil {
			return fmt.Errorf("failed to create drucksache: %w", err)
		}
	}

	// Store autoren_anzeige
	if drucksache.AutorenAnzeige != nil {
		for idx, autor := range *drucksache.AutorenAnzeige {
			if _, err := q.CreateDrucksacheAutorAnzeige(ctx, db.CreateDrucksacheAutorAnzeigeParams{
				DrucksacheID: drucksache.Id,
				PersonID:     autor.Id,
				AutorTitel:   autor.AutorTitel,
				Title:        autor.Title,
				DisplayOrder: int64(idx),
			}); err != nil {
				log.Printf("Warning: Failed to store autor anzeige for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	// Store ressort
	if drucksache.Ressort != nil {
		for _, ressort := range *drucksache.Ressort {
			ressortRecord, err := q.GetOrCreateRessort(ctx, ressort.Titel)
			if err != nil {
				log.Printf("Warning: Failed to get or create ressort for drucksache %s: %v", drucksache.Id, err)
				continue
			}

			federfuehrend := int64(0)
			if ressort.Federfuehrend {
				federfuehrend = 1
			}

			if err := q.CreateDrucksacheRessort(ctx, db.CreateDrucksacheRessortParams{
				DrucksacheID:  drucksache.Id,
				RessortID:     ressortRecord.ID,
				Federfuehrend: federfuehrend,
			}); err != nil {
				log.Printf("Warning: Failed to store ressort for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	// Store urheber
	if drucksache.Urheber != nil {
		for _, urheber := range *drucksache.Urheber {
			urheberRecord, err := q.GetOrCreateUrheber(ctx, db.GetOrCreateUrheberParams{
				Bezeichnung: urheber.Bezeichnung,
				Titel:       urheber.Titel,
			})
			if err != nil {
				log.Printf("Warning: Failed to get or create urheber for drucksache %s: %v", drucksache.Id, err)
				continue
			}

			var rolle sql.NullString
			if urheber.Rolle != nil {
				rolle = sql.NullString{String: string(*urheber.Rolle), Valid: true}
			}

			var einbringer sql.NullInt64
			if urheber.Einbringer != nil && *urheber.Einbringer {
				einbringer = sql.NullInt64{Int64: 1, Valid: true}
			}

			if err := q.CreateDrucksacheUrheber(ctx, db.CreateDrucksacheUrheberParams{
				DrucksacheID: drucksache.Id,
				UrheberID:    urheberRecord.ID,
				Rolle:        rolle,
				Einbringer:   einbringer,
			}); err != nil {
				log.Printf("Warning: Failed to store urheber for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	// Store vorgangsbezug
	if drucksache.Vorgangsbezug != nil {
		for idx, bezug := range *drucksache.Vorgangsbezug {
			if err := q.CreateDrucksacheVorgangsbezug(ctx, db.CreateDrucksacheVorgangsbezugParams{
				DrucksacheID: drucksache.Id,
				VorgangID:    bezug.Id,
				Titel:        bezug.Titel,
				Vorgangstyp:  bezug.Vorgangstyp,
				DisplayOrder: int64(idx),
			}); err != nil {
				log.Printf("Warning: Failed to store vorgangsbezug for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	return nil
}
