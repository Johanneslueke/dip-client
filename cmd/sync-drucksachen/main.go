package main

import (
	"context"
	"database/sql"
	"log"
	"strconv"
	"strings"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen/v1.4"
	"github.com/Johanneslueke/dip-client/internal/utility"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	// Parse configuration
	config := utility.ParseSyncFlags("drucksachen")

	// Create sync context (handles all setup)
	syncCtx, err := utility.NewSyncContext(config, 720)
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
			params := &client.GetDrucksacheListParams{
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
						
					wpFilter := make([]int, 1)
					wpFilter[0] = wpInt
					params.FWahlperiode = &wpFilter
				} else {
					wpFilters := make(client.WahlperiodeFilter, 0, len(wpStrings))
					for _, wpStr := range wpStrings {
						wpInt, err := strconv.Atoi(wpStr)
						if err != nil {
							log.Fatalf("Invalid wahlperiode value: %v", err)
						}
						wpFilters = append(wpFilters, wpInt)
					}
					params.FWahlperiode = &wpFilters
				}
			}

			if config.VorgangID > 0 {
				vorgangIds := make(client.IdFilter, 1)
				vorgangIds[0] = config.VorgangID
				params.FId = &vorgangIds	
			}

			resp, err := syncCtx.Client.GetDrucksacheList(ctx, params)
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
		storeDrucksache,
		// Update checkpoint date function
		updateDrucksacheDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			drucksachen := docs.([]client.Drucksache)
			items := make([]interface{}, len(drucksachen))
			for i, d := range drucksachen {
				items[i] = d
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

func updateDrucksacheDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	drucksache := item.(client.Drucksache)
	if !drucksache.Datum.Time.IsZero() {
		datum, err := q.GetLatestDrucksacheDatum(ctx)
		if err != nil {
			log.Printf("Warning: Failed to get latest drucksache datum: %v", err)
			checkpointMgr.UpdateDate(drucksache.Datum.Time)
			return
		} else if t, ok := datum.(string); ok {
			if parsedDate, err := time.Parse("2006-01-02", t); err == nil {
				checkpointMgr.UpdateDate(parsedDate)
			} else {
				log.Printf("Warning: Failed to parse latest drucksache datum: %v", err)
				checkpointMgr.UpdateDate(drucksache.Datum.Time)
			}
		} else {
			checkpointMgr.UpdateDate(drucksache.Datum.Time)
		}
	}
}

func storeDrucksache(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	drucksache := item.(client.Drucksache)
	existing, err := q.GetDrucksache(ctx, drucksache.Id)
	if err != nil && err != sql.ErrNoRows {
		failedTracker.RecordIfDBLocked(drucksache.Id, "GetDrucksache", err)
		log.Printf("Warning: Failed to check if drucksache %s exists: %v", drucksache.Id, err)
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
		FundstelleXmlUrl:          ptrToNullString(fundstelle.XmlUrl),
		FundstelleTop:             ptrInt32ToNullInt64(fundstelle.Top),
		FundstelleTopZusatz:       ptrToNullString(fundstelle.TopZusatz),
		FundstelleFrageNummer:     ptrToNullString(fundstelle.FrageNummer),
		FundstelleVerteildatum:    dateToNullString(fundstelle.Verteildatum),
	}

	var druck db.Drucksache
	if existing.ID != "" {
		updateParams := db.UpdateDrucksacheParams{
			ID:                  existing.ID,
			Titel:               params.Titel,
			Aktualisiert:        params.Aktualisiert,
			Anlagen:             params.Anlagen,
			AutorenAnzahl:       params.AutorenAnzahl,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
			PdfHash:             params.PdfHash,
		}
		if druck, err = q.UpdateDrucksache(ctx, updateParams); err != nil {
			failedTracker.RecordIfDBLocked(drucksache.Id, "UpdateDrucksache", err)
			log.Printf("Warning: Failed to update drucksache %s: %v", drucksache.Id, err)
			return
		}
	} else {
		if druck, err = q.CreateDrucksache(ctx, params); err != nil {
			failedTracker.RecordIfDBLocked(drucksache.Id, "CreateDrucksache", err)
			log.Printf("Warning: Failed to create drucksache %s: %v", drucksache.Id, err)
			return
		}
	}

	// Store autoren_anzeige
	if drucksache.AutorenAnzeige != nil {
		for idx, autor := range *drucksache.AutorenAnzeige {
			if _, err := q.CreateDrucksacheAutorAnzeige(ctx, db.CreateDrucksacheAutorAnzeigeParams{
				DrucksacheID: druck.ID,
				PersonID:     autor.Id,
				AutorTitel:   autor.AutorTitel,
				Title:        autor.Title,
				DisplayOrder: int64(idx),
			}); err != nil {
				failedTracker.RecordIfDBLocked(drucksache.Id, "CreateDrucksacheAutorAnzeige", err)
				log.Printf("Warning: Failed to store autor anzeige for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	// Store ressort
	if drucksache.Ressort != nil {
		for _, ressort := range *drucksache.Ressort {
			ressortRecord, err := q.GetOrCreateRessort(ctx, ressort.Titel)
			if err != nil {
				failedTracker.RecordIfDBLocked(drucksache.Id, "GetOrCreateRessort", err)
				log.Printf("Warning: Failed to get or create ressort for drucksache %s: %v", drucksache.Id, err)
				continue
			}

			federfuehrend := int64(0)
			if ressort.Federfuehrend {
				federfuehrend = 1
			}

			if err := q.CreateDrucksacheRessort(ctx, db.CreateDrucksacheRessortParams{
				DrucksacheID:  druck.ID,
				RessortID:     ressortRecord.ID,
				Federfuehrend: federfuehrend,
			}); err != nil {
				failedTracker.RecordIfDBLocked(drucksache.Id, "CreateDrucksacheRessort", err)
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
				failedTracker.RecordIfDBLocked(drucksache.Id, "GetOrCreateUrheber", err)
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
				DrucksacheID: druck.ID,
				UrheberID:    urheberRecord.ID,
				Rolle:        rolle,
				Einbringer:   einbringer,
			}); err != nil {
				failedTracker.RecordIfDBLocked(drucksache.Id, "CreateDrucksacheUrheber", err)
				log.Printf("Warning: Failed to store urheber for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}

	// Store vorgangsbezug
	if drucksache.Vorgangsbezug != nil {
		for idx, bezug := range *drucksache.Vorgangsbezug {
			if err := q.CreateDrucksacheVorgangsbezug(ctx, db.CreateDrucksacheVorgangsbezugParams{
				DrucksacheID: druck.ID,
				VorgangID:    bezug.Id,
				Titel:        bezug.Titel,
				Vorgangstyp:  bezug.Vorgangstyp,
				DisplayOrder: int64(idx),
			}); err != nil {
				failedTracker.RecordIfDBLocked(drucksache.Id, "CreateDrucksacheVorgangsbezug", err)
				log.Printf("Warning: Failed to store vorgangsbezug for drucksache %s: %v", drucksache.Id, err)
			}
		}
	}
}
