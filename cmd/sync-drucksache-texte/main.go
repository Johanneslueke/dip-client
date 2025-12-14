package main

import (
	"context"
	"database/sql"
	"log"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	"github.com/Johanneslueke/dip-client/internal/utility"
	_ "modernc.org/sqlite"
)

func main() {
	// Parse configuration
	config := utility.ParseSyncFlags("drucksache-texte")

	// Create sync context (handles all setup)
	syncCtx, err := utility.NewSyncContext(config, 240)
	if err != nil {
		log.Fatal(err)
	}
	defer syncCtx.Close()

	// Run sync loop
	err = syncCtx.SyncLoop(
		// Fetch batch function
		func(ctx context.Context, cursor *string) (*utility.BatchResponse, error) {
			params := &client.GetDrucksacheTextListParams{
				Cursor: cursor,
			}

			resp, err := syncCtx.Client.GetDrucksacheTextList(ctx, params)
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
		storeDrucksacheText,
		// Update checkpoint date function (not used for text resources, pass nil)
		nil,
		// Extract items function
		func(docs interface{}) []interface{} {
			texts := docs.([]client.DrucksacheText)
			items := make([]interface{}, len(texts))
			for i, t := range texts {
				items[i] = t
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

func storeDrucksacheText(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	drucksacheText := item.(client.DrucksacheText)

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
		failedTracker.RecordIfDBLocked(drucksacheText.Id, "CreateDrucksacheText", err)
		log.Printf("Warning: Failed to store drucksache text %s: %v", drucksacheText.Id, err)
	}
}
