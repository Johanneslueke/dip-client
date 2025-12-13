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
	_ "modernc.org/sqlite"
)

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		dbPath  = flag.String("db", "dip.db", "SQLite database path")
		limit   = flag.Int("limit", 0, "Maximum number of drucksache-texte to fetch (0 = all)")
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

	var cursor *string

	log.Printf("Starting to fetch drucksache-texte from API...")

	for {
		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetDrucksacheTextListParams{
			Cursor: cursor,
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
