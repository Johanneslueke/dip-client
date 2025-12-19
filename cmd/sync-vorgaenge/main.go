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

func updateVorgangDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	vorgang := item.(client.Vorgang)
	if vorgang.Datum != nil && !vorgang.Datum.Time.IsZero() {
		datum, err := q.GetLatestVorgangDatum(ctx)
		if err != nil {
			log.Printf("Warning: Failed to get latest vorgang datum: %v", err)
			checkpointMgr.UpdateDate(vorgang.Datum.Time)
		} else if t, ok := datum.(string); ok {
			if lastProcessedDate, err := time.Parse("2006-01-02", t); err == nil {
				checkpointMgr.UpdateDate(lastProcessedDate)
			}
		} else {
			checkpointMgr.UpdateDate(vorgang.Datum.Time)
		}
	}
}



func storeVorgang(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	vorgang := item.(client.Vorgang)
	existing, err := q.GetVorgang(ctx, vorgang.Id)
	if err != nil && err != sql.ErrNoRows {
		failedTracker.RecordIfDBLocked(vorgang.Id, "GetVorgang", err)
		log.Printf("Warning: Failed to check if vorgang %s exists: %v", vorgang.Id, err)
		return
	}

	ptrToNullString := func(s *string) sql.NullString {
		if s == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: *s, Valid: true}
	}

	dateToNullString := func(d *openapi_types.Date) sql.NullString {
		if d == nil {
			return sql.NullString{Valid: false}
		}
		return sql.NullString{String: d.String(), Valid: true}
	}

	params := db.CreateVorgangParams{
		ID:             vorgang.Id,
		Titel:          vorgang.Titel,
		Vorgangstyp:    vorgang.Vorgangstyp,
		Typ:            string(vorgang.Typ),
		Abstract:       ptrToNullString(vorgang.Abstract),
		Aktualisiert:   vorgang.Aktualisiert.Format(time.RFC3339),
		Archiv:         ptrToNullString(vorgang.Archiv),
		Beratungsstand: ptrToNullString(vorgang.Beratungsstand),
		Datum:          dateToNullString(vorgang.Datum),
		Gesta:          ptrToNullString(vorgang.Gesta),
		Kom:            ptrToNullString(vorgang.Kom),
		Mitteilung:     ptrToNullString(vorgang.Mitteilung),
		Ratsdok:        ptrToNullString(vorgang.Ratsdok),
		Sek:            ptrToNullString(vorgang.Sek),
		Wahlperiode:    int64(vorgang.Wahlperiode),
	}

	if existing.ID != "" {
		updateParams := db.UpdateVorgangParams{
			ID:             vorgang.Id,
			Titel:          params.Titel,
			Abstract:       params.Abstract,
			Aktualisiert:   params.Aktualisiert,
			Beratungsstand: params.Beratungsstand,
			Datum:          params.Datum,
			Mitteilung:     params.Mitteilung,
		}
		if _, err := q.UpdateVorgang(ctx, updateParams); err != nil {
			failedTracker.RecordIfDBLocked(vorgang.Id, "UpdateVorgang", err)
			log.Printf("Warning: Failed to update vorgang %s: %v", vorgang.Id, err)
			return
		}
	} else {
		if _, err := q.CreateVorgang(ctx, params); err != nil {
			failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgang", err)
			log.Printf("Warning: Failed to create vorgang %s: %v", vorgang.Id, err)
			return
		}
	}

	if vorgang.Initiative != nil {
		for _, init := range *vorgang.Initiative {
			if err := q.CreateVorgangInitiative(ctx, db.CreateVorgangInitiativeParams{
				VorgangID:  vorgang.Id,
				Initiative: init,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangInitiative", err)
				log.Printf("Warning: Failed to store initiative for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Sachgebiet != nil {
		for _, sach := range *vorgang.Sachgebiet {
			if err := q.CreateVorgangSachgebiet(ctx, db.CreateVorgangSachgebietParams{
				VorgangID:  vorgang.Id,
				Sachgebiet: sach,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangSachgebiet", err)
				log.Printf("Warning: Failed to store sachgebiet for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Deskriptor != nil {
		for _, desk := range *vorgang.Deskriptor {
			fundstelleInt := int64(0)
			if desk.Fundstelle {
				fundstelleInt = 1
			}
			if _, err := q.CreateVorgangDeskriptor(ctx, db.CreateVorgangDeskriptorParams{
				VorgangID:  vorgang.Id,
				Name:       desk.Name,
				Typ:        string(desk.Typ),
				Fundstelle: fundstelleInt,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangDeskriptor", err)
				log.Printf("Warning: Failed to store deskriptor for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Verkuendung != nil {
		for _, verk := range *vorgang.Verkuendung {
			if _, err := q.CreateVerkuendung(ctx, db.CreateVerkuendungParams{
				VorgangID: vorgang.Id,
				Ausfertigungsdatum: verk.Ausfertigungsdatum.UTC().String(),
				Verkuendungsdatum:  verk.Verkuendungsdatum.UTC().String(),
				Fundstelle:        verk.Fundstelle,
				Einleitungstext: verk.Einleitungstext,
				Jahrgang: verk.Jahrgang,
				Seite: verk.Seite,
				Heftnummer: ptrToNullString(verk.Heftnummer),
				PdfUrl: ptrToNullString(verk.PdfUrl),
				RubrikNr: ptrToNullString(verk.RubrikNr),
				Titel: ptrToNullString(verk.Titel),
				VerkuendungsblattBezeichnung: ptrToNullString(verk.VerkuendungsblattBezeichnung),
				VerkuendungsblattKuerzel: ptrToNullString(verk.VerkuendungsblattKuerzel),
				
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangVerkuendung", err)
				log.Printf("Warning: Failed to store verkuendung for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Inkrafttreten != nil {
		for _, ink := range *vorgang.Inkrafttreten {
			if _, err := q.CreateInkrafttreten(ctx, db.CreateInkrafttretenParams{
				VorgangID: vorgang.Id,
				Datum: ink.Datum.UTC().String(),
				Erlaeuterung: ptrToNullString(ink.Erlaeuterung),
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangInkrafttreten", err)
				log.Printf("Warning: Failed to store inkrafttreten for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Zustimmungsbeduerftigkeit != nil {
		for _, zust := range *vorgang.Zustimmungsbeduerftigkeit {
			if  err := q.CreateVorgangZustimmungsbeduerftigkeit(ctx, db.CreateVorgangZustimmungsbeduerftigkeitParams{
				VorgangID: vorgang.Id,
				Zustimmungsbeduerftigkeit: zust,
				
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangZustimmungsbeduerftigkeit", err)
				log.Printf("Warning: Failed to store zustimmungsbeduerftigkeit for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.VorgangVerlinkung != nil {
		for _, verlinkung := range *vorgang.VorgangVerlinkung {
			if _, err := q.CreateVorgangVerlinkung(ctx, db.CreateVorgangVerlinkungParams{
				SourceVorgangID:        vorgang.Id,
				TargetVorgangID:        verlinkung.Verweisung, 
				Gesta: ptrToNullString(vorgang.Gesta), 
				Wahlperiode: int64(vorgang.Wahlperiode),
				Titel: "",

				
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgang.Id, "CreateVorgangVerlinkung", err)
				log.Printf("Warning: Failed to store vorgang verlinkung for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}
  
}
