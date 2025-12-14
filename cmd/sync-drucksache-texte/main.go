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
		limit         = flag.Int("limit", 0, "Maximum number of drucksache-texte to fetch (0 = all)")
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
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "drucksache-texte")
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
				if err := utility.SaveCheckpoint(*checkpointDir, "drucksache-texte", lastProcessedDate); err != nil {
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

	log.Printf("Starting to fetch drucksache-texte from API...")

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println() // New line after progress updates
			log.Printf("Interrupted after processing %d drucksache-texte", progress.Total)
			return
		}

		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetDrucksacheTextListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		resp, err := dipClient.GetDrucksacheTextList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch drucksache-texte: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, drucksacheText := range resp.Documents {
			if err := storeDrucksacheText(ctx, queries, drucksacheText); err != nil {
				log.Printf("Warning: Failed to store drucksache text %s: %v", drucksacheText.Id, err)
			}

			// Track the last processed date for checkpoint
			if drucksacheText.Aktualisiert.After(lastProcessedDate) {
				lastProcessedDate = drucksacheText.Aktualisiert
			}

			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d drucksache-texte", *limit)
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
	log.Printf("Successfully stored %d drucksache-texte in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))

	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "drucksache-texte"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storeDrucksacheText(ctx context.Context, q *db.Queries, drucksacheText client.DrucksacheText) error {
	ptrToNullString := func(s *string) sql.NullString {
		if s == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: *s, Valid: true}
	}

	// Store or update the text (this also handles the drucksache metadata via ON CONFLICT)
	if _, err := q.CreateDrucksacheText(ctx, db.CreateDrucksacheTextParams{
		ID:   drucksacheText.Id,
		Text: ptrToNullString(drucksacheText.Text),
	}); err != nil {
		return fmt.Errorf("failed to store drucksache text: %w", err)
	}

	return nil
}
