package utility

import (
	"context"
	"fmt"
	"log"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
)

// BatchResponse represents a batch of fetched items
type BatchResponse struct {
	Documents    interface{} // Slice of documents
	Cursor       string      // Next cursor
	NumFound     int         // Total available
	DocumentsLen int         // Length of Documents slice
}

// FetchBatchFunc is a function that fetches a batch of items
type FetchBatchFunc func(ctx context.Context, cursor *string) (*BatchResponse, error)

// StoreItemFunc is a function that stores a single item
type StoreItemFunc func(ctx context.Context, q *db.Queries, item interface{}, failedTracker *FailedRecordsTracker)

// UpdateDateFunc is a function that extracts and updates the checkpoint date from an item
type UpdateDateFunc func(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *CheckpointManager)

// SyncLoop executes the main sync loop with batch fetching and item storage
func (sc *SyncContext) SyncLoop(
	fetchBatch FetchBatchFunc,
	storeItem StoreItemFunc,
	updateDate UpdateDateFunc,
	extractItems func(interface{}) []interface{}, // Function to extract items from Documents
) error {
	var cursor *string

	log.Printf("Starting to fetch %s from API...", sc.Config.ResourceName)

	for {
		// Check if we should stop
		if sc.ShouldStop() {
			return nil
		}

		// Rate limiting
		// if err := sc.Limiter.Wait(sc.ctx); err != nil {
		// 	return fmt.Errorf("rate limiter error: %w", err)
		// }

		// Fetch batch
		resp, err := fetchBatch(sc.ctx, cursor)
		if err != nil {
			return fmt.Errorf("failed to fetch batch: %w", err)
		}

		// Check if we're done
		if resp.DocumentsLen == 0 {
			break
		}

		// Update progress
		sc.Progress.Total += resp.DocumentsLen
		sc.Progress.PrintProgress(sc.Progress.Total, resp.NumFound)

		// Extract and process items
		items := extractItems(resp.Documents)
		for _, item := range items {
			// Store the item
			storeItem(sc.ctx, sc.Queries, item, sc.FailedTracker)

			// Update checkpoint date if function provided
			if updateDate != nil {
				updateDate(sc.ctx, sc.Queries, item, sc.CheckpointMgr)
			}

			// Increment progress
			sc.Progress.Increment()

			// Check if we should stop after each item
			if sc.ShouldStop() {
				return nil
			}
		}

		// Update cursor for next batch
		if resp.Cursor == "" {
			break
		}
		cursor = &resp.Cursor
	}

	return nil
}

// SimpleSyncLoop is a simplified version for sync operations without checkpointing
func (sc *SyncContext) SimpleSyncLoop(
	fetchBatch FetchBatchFunc,
	storeItem StoreItemFunc,
	extractItems func(interface{}) []interface{},
) error {
	return sc.SyncLoop(fetchBatch, storeItem, nil, extractItems)
}
