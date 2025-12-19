# Sync Framework Refactoring Example

This document shows how to use the new sync framework to simplify sync commands.

## Before (Old Pattern) - ~200 lines

```go
package main

import (
	"context"
	"database/sql"
	"flag"
	"log"
	// ... many imports
)

func main() {
	// 40+ lines of flag parsing and setup
	var (
		baseURL       = flag.String("url", "https://...", "...")
		apiKey        = flag.String("key", "", "...")
		dbPath        = flag.String("db", "dip.db", "...")
		limit         = flag.Int("limit", 0, "...")
		checkpointDir = flag.String("checkpoint-dir", ".checkpoints", "...")
		failedDir     = flag.String("failed-dir", ".failed", "...")
		resume        = flag.Bool("resume", false, "...")
		end           = flag.String("end", "", "...")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}
	if *apiKey == "" {
		log.Fatal("API key required...")
	}

	// 30+ lines of initialization
	dipClient, err := dipclient.New(...)
	sqlDB, err := sql.Open("sqlite", *dbPath)
	sqlDB.SetMaxOpenConns(24)
	sqlDB.SetMaxIdleConns(24)
	sqlDB.SetConnMaxLifetime(time.Hour)

	if err := utility.RunMigrations(sqlDB); err != nil { ... }

	queries := db.New(sqlDB)
	ctx := context.Background()
	limiter := utility.NewRateLimiter(240, time.Minute)
	progress := utility.NewProgressTracker(*limit)
	failedTracker := utility.NewFailedRecordsTracker(*failedDir, "vorgaenge")

	// 30+ lines of checkpoint and signal handling
	var datumEnd *openapi_types.Date
	var lastProcessedDate time.Time
	interrupted := false

	if *resume {
		checkpoint, err := utility.LoadCheckpoint(...)
		// ... more checkpoint logic
	}

	signalHandler := utility.NewSignalHandler(...)
	defer signalHandler.Stop()

	// 80+ lines of main sync loop
	var cursor *string
	for {
		if signalHandler.IsInterrupted() || interrupted {
			// ... cleanup
			return
		}

		if err := limiter.Wait(ctx); err != nil { ... }

		resp, err := dipClient.GetVorgangList(ctx, params)
		if err != nil { ... }
		if len(resp.Documents) == 0 { break }

		progress.Total += len(resp.Documents)
		progress.PrintProgress(...)

		for _, vorgang := range resp.Documents {
			storeVorgang(...)

			// Complex checkpoint date tracking
			if vorgang.Datum.Time.After(lastProcessedDate) {
				// ... 15 lines of date handling
			}

			progress.Increment()
			if *limit > 0 && progress.Total >= *limit {
				goto done
			}
		}

		cursor = &resp.Cursor
	}

done:
	// 20+ lines of finalization
	fmt.Println()
	elapsed, rate := progress.GetStats()
	log.Printf("Successfully stored...")

	if failedTracker.Count() > 0 {
		// ... save failed records
	}

	if !interrupted && *resume {
		// ... delete checkpoint
	}
}

func storeVorgang(...) {
	// 100+ lines of store logic
}
```

## After (New Pattern) - ~50 lines

```go
package main

import (
	"context"
	"log"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	"github.com/Johanneslueke/dip-client/internal/utility"
	openapi_types "github.com/oapi-codegen/runtime/types"
)

func main() {
	// Parse configuration
	config := utility.ParseSyncFlags("vorgaenge")

	// Create sync context (handles all setup)
	syncCtx, err := utility.NewSyncContext(config, 240)
	if err != nil {
		log.Fatal(err)
	}
	defer syncCtx.Close()

	// Load checkpoint if resuming
	datumEnd, _ := syncCtx.CheckpointMgr.LoadIfResume()

	// Parse end date if provided
	if config.End != "" {
		endTime, err := time.Parse("2006-01-02", config.End)
		if err != nil {
			log.Fatalf("Invalid end date format: %v", err)
		}
		date := openapi_types.Date{Time: endTime}
		datumEnd = &date
	}

	// Run sync loop
	err = syncCtx.SyncLoop(
		// Fetch batch function
		func(ctx context.Context, cursor *string) (*utility.BatchResponse, error) {
			params := &client.GetVorgangListParams{
				Cursor:    cursor,
				FDatumEnd: datumEnd,
			}
			resp, err := syncCtx.Client.GetVorgangList(ctx, params)
			if err != nil {
				return nil, err
			}
			return &utility.BatchResponse{
				Documents:    resp.Documents,
				Cursor:       resp.Cursor,
				NumFound:     int(resp.NumFound),
				DocumentsLen: len(resp.Documents),
			}, nil
		},
		// Store item function
		storeVorgang,
		// Update checkpoint date function
		updateVorgangDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			vorgaenge := docs.([]client.Vorgang)
			items := make([]interface{}, len(vorgaenge))
			for i, v := range vorgaenge {
				items[i] = v
			}
			return items
		},
	)

	if err != nil {
		log.Fatal(err)
	}

	// Finalize (handles all cleanup and logging)
	syncCtx.Finalize()
}

func storeVorgang(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	vorgang := item.(client.Vorgang)
	// ... existing store logic (unchanged)
}

func updateVorgangDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	vorgang := item.(client.Vorgang)
	if !vorgang.Datum.Time.IsZero() {
		datum, err := q.GetLatestVorgangDatum(ctx)
		if err == nil {
			if t, ok := datum.(string); ok {
				if parsedTime, err := time.Parse("2006-01-02", t); err == nil {
					checkpointMgr.UpdateDate(parsedTime)
					return
				}
			}
		}
		checkpointMgr.UpdateDate(vorgang.Datum.Time)
	}
}
```

## Even Simpler for Commands Without Checkpointing

For commands like `sync-drucksache-texte` that don't need checkpointing:

```go
func main() {
	config := utility.ParseSyncFlags("drucksache-texte")

	syncCtx, err := utility.NewSyncContext(config, 240)
	if err != nil {
		log.Fatal(err)
	}
	defer syncCtx.Close()

	err = syncCtx.SimpleSyncLoop(
		fetchDrucksacheTexte,
		storeDrucksacheText,
		extractDrucksacheTexte,
	)

	if err != nil {
		log.Fatal(err)
	}

	syncCtx.Finalize()
}
```

## Benefits

1. **Reduced Code**: From ~200 lines to ~50 lines per sync command
2. **Consistency**: All sync commands use the same patterns
3. **Testability**: Framework components can be tested independently
4. **Maintainability**: Bug fixes in one place benefit all commands
5. **Clarity**: Business logic (fetch/store) is separated from boilerplate

## Migration Strategy

1. Create the new framework files (already done)
2. Test framework with one command (e.g., sync-vorgaenge)
3. Once stable, migrate other commands one by one
4. Keep old implementations until all are migrated
5. Remove old code after verification
