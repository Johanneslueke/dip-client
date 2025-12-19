package main

import (
	"context"
	"database/sql"
	"log"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen/v1.4"
	"github.com/Johanneslueke/dip-client/internal/utility"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	// Parse configuration
	config := utility.ParseSyncFlags("plenarprotokolle")

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
			params := &client.GetPlenarprotokollListParams{
				Cursor:    cursor,
				FDatumEnd: datumEnd,
			}

			resp, err := syncCtx.Client.GetPlenarprotokollList(ctx, params)
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
		storePlenarprotokoll,
		// Update checkpoint date function
		updatePlenarprotokollDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			protokolle := docs.([]client.Plenarprotokoll)
			items := make([]interface{}, len(protokolle))
			for i, p := range protokolle {
				items[i] = p
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

func updatePlenarprotokollDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	plenarprotokoll := item.(client.Plenarprotokoll)
	if !plenarprotokoll.Datum.IsZero() {
		datum, err := q.GetLatestPlenarprotokollDatum(ctx)
		if err != nil {
			log.Printf("Warning: Failed to get latest plenarprotokoll datum: %v", err)
			checkpointMgr.UpdateDate(plenarprotokoll.Aktualisiert)
		} else if t, ok := datum.(string); ok {
			if parsedDate, err := time.Parse("2006-01-02", t); err == nil {
				checkpointMgr.UpdateDate(parsedDate)
			} else {
				checkpointMgr.UpdateDate(plenarprotokoll.Aktualisiert)
			}
		} else {
			checkpointMgr.UpdateDate(plenarprotokoll.Aktualisiert)
		}
	}
}

func storePlenarprotokoll(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	plenarprotokoll := item.(client.Plenarprotokoll)
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
		FundstelleXmlUrl:          ptrToNullString(fundstelle.XmlUrl),
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
