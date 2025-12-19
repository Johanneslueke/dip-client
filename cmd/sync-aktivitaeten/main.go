package main

import (
	"context"
	"database/sql"
	"log"
	"strconv"
	"strings"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	"github.com/Johanneslueke/dip-client/internal/utility"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	// Parse configuration
	config := utility.ParseSyncFlags("aktivitaeten")

	// Create sync context (handles all setup)
	syncCtx, err := utility.NewSyncContext(config, 480)
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
			params := &client.GetAktivitaetListParams{
				Cursor:    cursor,
				FDatumEnd: datumEnd,
			}

			// Add optional filters
			if config.Wahlperiode != "" {
				//split and convert to []WahlperiodeFilter if slice only contains one element use FWahlperiode if it contains multiple use FWahlperiodes
				wpStrings := strings.Split(config.Wahlperiode, ",")
				if len(wpStrings) == 1 {
					// parse single int
					wpInt, err := strconv.Atoi(wpStrings[0])
					if err != nil {
						log.Fatalf("Invalid wahlperiode value: %v", err)
					}
					wpFilter := dipclient.WahlperiodeFilter(wpInt)
					params.FWahlperiode = &wpFilter
				} else {
					var wpFilters []dipclient.WahlperiodeFilter
					for _, wpStr := range wpStrings {
						wpInt, err := strconv.Atoi(wpStr)
						if err != nil {
							log.Fatalf("Invalid wahlperiode value: %v", err)
						}
						wpFilters = append(wpFilters, dipclient.WahlperiodeFilter(wpInt))
					}
					params.FWahlperiodes = &wpFilters
				}
			}
			if config.VorgangID > 0 {
				params.FId = &config.VorgangID
			}

			resp, err := syncCtx.Client.GetAktivitaetList(ctx, params)
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
		storeAktivitaet,
		// Update checkpoint date function
		updateAktivitaetDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			aktivitaeten := docs.([]client.Aktivitaet)
			items := make([]interface{}, len(aktivitaeten))
			for i, a := range aktivitaeten {
				items[i] = a
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

func updateAktivitaetDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	aktivitaet := item.(client.Aktivitaet)
	if !aktivitaet.Aktualisiert.IsZero() {
		datum, err := q.GetLatestAktivitaetDatum(ctx)
		if err != nil {
			log.Printf("Warning: Failed to get latest aktivitaet datum: %v", err)
			checkpointMgr.UpdateDate(aktivitaet.Aktualisiert)
		} else if t, ok := datum.(string); ok {
			if lastProcessedDate, err := time.Parse("2006-01-02", t); err == nil {
				checkpointMgr.UpdateDate(lastProcessedDate)
			} else {
				checkpointMgr.UpdateDate(aktivitaet.Aktualisiert)
			}
		} else {
			checkpointMgr.UpdateDate(aktivitaet.Aktualisiert)
		}
	}
}

func storeAktivitaet(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	aktivitaet := item.(client.Aktivitaet)
	existing, err := q.GetAktivitaet(ctx, aktivitaet.Id)
	if err != nil && err != sql.ErrNoRows {
		failedTracker.RecordIfDBLocked(aktivitaet.Id, "GetAktivitaet", err)
		log.Printf("Warning: Failed to check if aktivitaet %s exists: %v", aktivitaet.Id, err)
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

	var aktivitaetDb db.Aktivitaet
	
	
	if existing.ID != "" {
		updateParams := db.UpdateAktivitaetParams{
			ID:                  aktivitaet.Id,
			Titel:               params.Titel,
			Aktivitaetsart:      params.Aktivitaetsart,
			Aktualisiert:        params.Aktualisiert,
			Abstract:            params.Abstract,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
		}
		aktivitaetDb, err = q.UpdateAktivitaet(ctx, updateParams)
		if err != nil {
			failedTracker.RecordIfDBLocked(aktivitaet.Id, "UpdateAktivitaet", err)
			log.Printf("Warning: Failed to update aktivitaet %s: %v", aktivitaet.Id, err)
			return
		}
	} else {
		aktivitaetDb, err = q.CreateAktivitaet(ctx, params)
		if err != nil {
			failedTracker.RecordIfDBLocked(aktivitaet.Id, "CreateAktivitaet", err)
			log.Printf("Warning: Failed to create aktivitaet %s: %v", aktivitaet.Id, err)
			return
		}
	}

	// Store deskriptors
	if aktivitaet.Deskriptor != nil {
		for _, desk := range *aktivitaet.Deskriptor {
			if _, err := q.CreateAktivitaetDeskriptor(ctx, db.CreateAktivitaetDeskriptorParams{
				AktivitaetID: aktivitaetDb.ID,
				Name:         desk.Name,
				Typ:          string(desk.Typ),
			}); err != nil && err != sql.ErrNoRows {
				failedTracker.RecordIfDBLocked(aktivitaet.Id, "CreateAktivitaetDeskriptor", err)
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
				failedTracker.RecordIfDBLocked(aktivitaet.Id, "CreateAktivitaetVorgangsbezug", err)
				log.Printf("Warning: Failed to store vorgangsbezug for aktivitaet %s: %v", aktivitaet.Id, err)
			}
		}
	}
}
