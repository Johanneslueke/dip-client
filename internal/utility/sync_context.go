package utility

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	_ "modernc.org/sqlite"
)

// SyncContext holds all the components needed for a sync operation
type SyncContext struct {
	Config        *SyncConfig
	DB            *sql.DB
	Queries       *db.Queries
	Client        *dipclient.Client
	Limiter       *RateLimiter
	Progress      *ProgressTracker
	FailedTracker *FailedRecordsTracker
	CheckpointMgr *CheckpointManager
	SignalHandler *SignalHandler
	ctx           context.Context
	interrupted   bool
}

// NewSyncContext creates and initializes a complete sync context
func NewSyncContext(config *SyncConfig, requestsPerMinute int) (*SyncContext, error) {
	if err := config.Validate(); err != nil {
		return nil, err
	}

	sc := &SyncContext{
		Config:      config,
		ctx:         context.Background(),
		interrupted: false,
	}

	// Setup database
	sqlDB, err := sql.Open("sqlite", config.DBPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	sqlDB.SetMaxOpenConns(24)
	sqlDB.SetMaxIdleConns(24)
	sqlDB.SetConnMaxLifetime(time.Hour) 

	if err := RunMigrations(sqlDB); err != nil {
		sqlDB.Close()
		return nil, fmt.Errorf("failed to run migrations: %w", err)
	}

	sc.DB = sqlDB
	sc.Queries = db.New(sqlDB)

	// Setup API client
	dipClient, err := dipclient.New(dipclient.Config{
		BaseURL: config.BaseURL,
		APIKey:  config.APIKey,
	})
	if err != nil {
		sqlDB.Close()
		return nil, fmt.Errorf("failed to create API client: %w", err)
	}
	sc.Client = dipClient

	// Setup rate limiter
	sc.Limiter = NewRateLimiter(requestsPerMinute, time.Minute)

	// Setup progress tracker
	sc.Progress = NewProgressTracker(config.Limit)

	// Setup failed records tracker
	sc.FailedTracker = NewFailedRecordsTracker(config.FailedDir, config.ResourceName)

	// Setup checkpoint manager
	sc.CheckpointMgr = NewCheckpointManager(config.CheckpointDir, config.ResourceName, config.Resume)

	// Setup signal handler
	sc.SignalHandler = NewSignalHandler(
		func() {
			sc.interrupted = true
			sc.CheckpointMgr.SaveCheckpoint()
		},
		nil,
	)

	return sc, nil
}

// Context returns the context for this sync operation
func (sc *SyncContext) Context() context.Context {
	return sc.ctx
}

// IsInterrupted checks if the sync has been interrupted
func (sc *SyncContext) IsInterrupted() bool {
	return sc.SignalHandler.IsInterrupted() || sc.interrupted
}

// ShouldStop checks if sync should stop (interrupted or limit reached)
func (sc *SyncContext) ShouldStop() bool {
	if sc.IsInterrupted() {
		return true
	}
	if sc.Config.Limit > 0 && sc.Progress.Total >= sc.Config.Limit {
		return true
	}
	return false
}

// Finalize performs cleanup and final logging
func (sc *SyncContext) Finalize() {
	fmt.Println() // New line after progress updates

	if sc.IsInterrupted() {
		log.Printf("Interrupted after processing %d items", sc.Progress.Total)
	} else if sc.Config.Limit > 0 && sc.Progress.Total >= sc.Config.Limit {
		log.Printf("Reached limit of %d items", sc.Config.Limit)
	} else {
		elapsed, rate := sc.Progress.GetStats()
		log.Printf("Successfully stored %d items in database %s (%.1f/sec, took %s)",
			sc.Progress.Total, sc.Config.DBPath, rate, elapsed.Round(time.Second))
	}

	// Save failed records if any
	if sc.FailedTracker.Count() > 0 {
		if err := sc.FailedTracker.Save(); err != nil {
			log.Printf("Warning: Failed to save failed records: %v", err)
		} else {
			log.Printf("⚠️  %d records failed due to DB locks, saved to %s/%s.failed.json",
				sc.FailedTracker.Count(), sc.Config.FailedDir, sc.Config.ResourceName)
		}
	}

	// Delete checkpoint on successful completion
	sc.CheckpointMgr.DeleteOnSuccess(sc.interrupted)
}

// Close closes the database connection and stops the signal handler
func (sc *SyncContext) Close() error {
	if sc.SignalHandler != nil {
		sc.SignalHandler.Stop()
	}
	if sc.DB != nil {
		return sc.DB.Close()
	}
	return nil
}
