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
		limit         = flag.Int("limit", 0, "Maximum number of plenarprotokoll-texte to fetch (0 = all)")
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
	limiter := utility.NewRateLimiter(23, time.Minute)
	progress := utility.NewProgressTracker(*limit)
	failedTracker := utility.NewFailedRecordsTracker(*failedDir, "plenarprotokoll-texte")

	// Checkpoint and signal handling
	var datumEnd *openapi_types.Date
	var lastProcessedDate time.Time
	interrupted := false

	if *resume {
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "plenarprotokoll-texte")
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
				if err := utility.SaveCheckpoint(*checkpointDir, "plenarprotokoll-texte", lastProcessedDate); err != nil {
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

	log.Printf("Starting to fetch plenarprotokoll-texte from API...")

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println()
			log.Printf("Interrupted after processing %d plenarprotokoll-texte", progress.Total)
			return
		}

		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetPlenarprotokollTextListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		resp, err := dipClient.GetPlenarprotokollTextList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch plenarprotokoll-texte: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, plenarprotokollText := range resp.Documents {
			storePlenarprotokollText(ctx, queries, plenarprotokollText, failedTracker)

			// Track the last processed date for checkpoint
			if plenarprotokollText.Aktualisiert.After(lastProcessedDate) {
				lastProcessedDate = plenarprotokollText.Aktualisiert
			}

			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println()
				log.Printf("Reached limit of %d plenarprotokoll-texte", *limit)
				goto done
			}
		}

		if resp.Cursor == "" {
			break
		}
		cursor = &resp.Cursor
	}

done:
	fmt.Println()
	elapsed, rate := progress.GetStats()
	log.Printf("Successfully stored %d plenarprotokoll-texte in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))

	// Save failed records if any
	if failedTracker.Count() > 0 {
		if err := failedTracker.Save(); err != nil {
			log.Printf("Warning: Failed to save failed records: %v", err)
		} else {
			log.Printf("⚠️  %d records failed due to DB locks, saved to %s/plenarprotokoll-texte.failed.json", failedTracker.Count(), *failedDir)
		}
	}

	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "plenarprotokoll-texte"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storePlenarprotokollText(ctx context.Context, q *db.Queries, plenarprotokollText client.PlenarprotokollText, failedTracker *utility.FailedRecordsTracker) {
	ptrToNullString := func(s *string) sql.NullString {
		if s == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: *s, Valid: true}
	}

	if _, err := q.CreatePlenarprotokollText(ctx, db.CreatePlenarprotokollTextParams{
		ID:   plenarprotokollText.Id,
		Text: ptrToNullString(plenarprotokollText.Text),
	}); err != nil {
		failedTracker.RecordIfDBLocked(plenarprotokollText.Id, "CreatePlenarprotokollText", err)
		log.Printf("Warning: Failed to store plenarprotokoll text %s: %v", plenarprotokollText.Id, err)
	}
}
