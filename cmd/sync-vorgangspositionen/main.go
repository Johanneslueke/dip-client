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
	config := utility.ParseSyncFlags("vorgangspositionen")

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
			params := &client.GetVorgangspositionListParams{
				Cursor:    cursor,
				FDatumEnd: datumEnd,
			}

			// Add optional filters
			if config.Wahlperiode != "" {
				wpStrings := strings.Split(config.Wahlperiode, ",")

				if len(wpStrings) == 1 {
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

			resp, err := syncCtx.Client.GetVorgangspositionList(ctx, params)
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
		storeVorgangsposition,
		// Update checkpoint date function
		updateVorgangspositionDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			vorgangspositionen := docs.([]client.Vorgangsposition)
			items := make([]interface{}, len(vorgangspositionen))
			for i, v := range vorgangspositionen {
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

func updateVorgangspositionDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	vorgangsposition := item.(client.Vorgangsposition)
	if !vorgangsposition.Datum.Time.IsZero() {
		datum, err := q.GetLatestVorgangspositionDatum(ctx)
		if err != nil {
			log.Printf("Warning: Failed to get latest vorgangsposition datum: %v", err)
			checkpointMgr.UpdateDate(vorgangsposition.Datum.Time)
		} else if t, ok := datum.(string); ok {
			if parsedDate, err := time.Parse("2006-01-02", t); err == nil {
				checkpointMgr.UpdateDate(parsedDate)
			} else {
				checkpointMgr.UpdateDate(vorgangsposition.Datum.Time)
			}
		} else {
			checkpointMgr.UpdateDate(vorgangsposition.Datum.Time)
		}
	}
}

func storeVorgangsposition(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	vorgangsposition := item.(client.Vorgangsposition)
	existing, err := q.GetVorgangsposition(ctx, vorgangsposition.Id)
	if err != nil && err != sql.ErrNoRows {
		failedTracker.RecordIfDBLocked(vorgangsposition.Id, "GetVorgangsposition", err)
		log.Printf("Warning: Failed to check if vorgangsposition %s exists: %v", vorgangsposition.Id, err)
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

	boolToInt64 := func(b bool) int64 {
		if b {
			return 1
		}
		return 0
	}

	// Extract Fundstelle fields
	fundstelle := vorgangsposition.Fundstelle
	params := db.CreateVorgangspositionParams{
		ID:                        vorgangsposition.Id,
		VorgangID:                 vorgangsposition.VorgangId,
		Titel:                     vorgangsposition.Titel,
		Vorgangsposition:          vorgangsposition.Vorgangsposition,
		Vorgangstyp:               vorgangsposition.Vorgangstyp,
		Typ:                       string(vorgangsposition.Typ),
		Dokumentart:               string(vorgangsposition.Dokumentart),
		Datum:                     vorgangsposition.Datum.String(),
		Aktualisiert:              vorgangsposition.Aktualisiert.Format(time.RFC3339),
		Abstract:                  ptrToNullString(vorgangsposition.Abstract),
		Fortsetzung:               boolToInt64(vorgangsposition.Fortsetzung),
		Gang:                      boolToInt64(vorgangsposition.Gang),
		Nachtrag:                  boolToInt64(vorgangsposition.Nachtrag),
		AktivitaetAnzahl:          int64(vorgangsposition.AktivitaetAnzahl),
		Kom:                       ptrToNullString(vorgangsposition.Kom),
		Ratsdok:                   ptrToNullString(vorgangsposition.Ratsdok),
		Sek:                       ptrToNullString(vorgangsposition.Sek),
		Zuordnung:                 string(vorgangsposition.Zuordnung),
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

	if existing.ID != "" {
		updateParams := db.UpdateVorgangspositionParams{
			ID:               vorgangsposition.Id,
			Titel:            params.Titel,
			Aktualisiert:     params.Aktualisiert,
			Abstract:         params.Abstract,
			AktivitaetAnzahl: params.AktivitaetAnzahl,
		}
		if _, err := q.UpdateVorgangsposition(ctx, updateParams); err != nil {
			failedTracker.RecordIfDBLocked(vorgangsposition.Id, "UpdateVorgangsposition", err)
			log.Printf("Warning: Failed to update vorgangsposition %s: %v", vorgangsposition.Id, err)
			return
		}
	} else {
		if _, err := q.CreateVorgangsposition(ctx, params); err != nil {
			failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateVorgangsposition", err)
			log.Printf("Warning: Failed to create vorgangsposition %s: %v", vorgangsposition.Id, err)
			return
		}
	}

	// Store aktivitaet_anzeige
	if vorgangsposition.AktivitaetAnzeige != nil {
		for idx, aktivitaet := range *vorgangsposition.AktivitaetAnzeige {
			if _, err := q.CreateAktivitaetAnzeige(ctx, db.CreateAktivitaetAnzeigeParams{
				VorgangspositionID: vorgangsposition.Id,
				Aktivitaetsart:     aktivitaet.Aktivitaetsart,
				Titel:              aktivitaet.Titel,
				Seite:              ptrToNullString(aktivitaet.Seite),
				PdfUrl:             ptrToNullString(aktivitaet.PdfUrl),
				DisplayOrder:       int64(idx),
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateAktivitaetAnzeige", err)
				log.Printf("Warning: Failed to store aktivitaet anzeige for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}

	// Store beschlussfassung
	if vorgangsposition.Beschlussfassung != nil {
		for _, beschluss := range *vorgangsposition.Beschlussfassung {
			var abstimmungsart sql.NullString
			if beschluss.Abstimmungsart != nil {
				abstimmungsart = sql.NullString{String: string(*beschluss.Abstimmungsart), Valid: true}
			}

			var mehrheit sql.NullString
			if beschluss.Mehrheit != nil {
				mehrheit = sql.NullString{String: string(*beschluss.Mehrheit), Valid: true}
			}

			if _, err := q.CreateBeschlussfassung(ctx, db.CreateBeschlussfassungParams{
				VorgangspositionID:       vorgangsposition.Id,
				Beschlusstenor:           beschluss.Beschlusstenor,
				Abstimmungsart:           abstimmungsart,
				Mehrheit:                 mehrheit,
				AbstimmErgebnisBemerkung: ptrToNullString(beschluss.AbstimmErgebnisBemerkung),
				Dokumentnummer:           ptrToNullString(beschluss.Dokumentnummer),
				Grundlage:                ptrToNullString(beschluss.Grundlage),
				Seite:                    ptrToNullString(beschluss.Seite),
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateBeschlussfassung", err)
				log.Printf("Warning: Failed to store beschlussfassung for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}

	// Store ressort
	if vorgangsposition.Ressort != nil {
		for _, ressort := range *vorgangsposition.Ressort {
			ressortRecord, err := q.GetOrCreateRessort(ctx, ressort.Titel)
			if err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "GetOrCreateRessort", err)
				log.Printf("Warning: Failed to get or create ressort for vorgangsposition %s: %v", vorgangsposition.Id, err)
				continue
			}

			federfuehrend := int64(0)
			if ressort.Federfuehrend {
				federfuehrend = 1
			}

			if err := q.CreateVorgangspositionRessort(ctx, db.CreateVorgangspositionRessortParams{
				VorgangspositionID: vorgangsposition.Id,
				RessortID:          ressortRecord.ID,
				Federfuehrend:      federfuehrend,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateVorgangspositionRessort", err)
				log.Printf("Warning: Failed to store ressort for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}

	// Store urheber
	if vorgangsposition.Urheber != nil {
		for _, urheber := range *vorgangsposition.Urheber {
			urheberRecord, err := q.GetOrCreateUrheber(ctx, db.GetOrCreateUrheberParams{
				Bezeichnung: urheber.Bezeichnung,
				Titel:       urheber.Titel,
			})
			if err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "GetOrCreateUrheber", err)
				log.Printf("Warning: Failed to get or create urheber for vorgangsposition %s: %v", vorgangsposition.Id, err)
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

			if err := q.CreateVorgangspositionUrheber(ctx, db.CreateVorgangspositionUrheberParams{
				VorgangspositionID: vorgangsposition.Id,
				UrheberID:          urheberRecord.ID,
				Rolle:              rolle,
				Einbringer:         einbringer,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateVorgangspositionUrheber", err)
				log.Printf("Warning: Failed to store urheber for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}

	// Store ueberweisung
	if vorgangsposition.Ueberweisung != nil {
		for _, ueberweisung := range *vorgangsposition.Ueberweisung {
			if _, err := q.CreateUeberweisung(ctx, db.CreateUeberweisungParams{
				VorgangspositionID: vorgangsposition.Id,
				Ausschuss:          ueberweisung.Ausschuss,
				AusschussKuerzel:   ueberweisung.AusschussKuerzel,
				Federfuehrung:      boolToInt64(ueberweisung.Federfuehrung),
				Ueberweisungsart:   ptrToNullString(ueberweisung.Ueberweisungsart),
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateUeberweisung", err)
				log.Printf("Warning: Failed to store ueberweisung for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}

	// Store mitberaten
	if vorgangsposition.Mitberaten != nil {
		for _, mitberaten := range *vorgangsposition.Mitberaten {
			if err := q.CreateVorgangspositionMitberaten(ctx, db.CreateVorgangspositionMitberatenParams{
				VorgangspositionID:         vorgangsposition.Id,
				MitberatenVorgangID:        mitberaten.Id,
				MitberatenTitel:            mitberaten.Titel,
				MitberatenVorgangsposition: mitberaten.Vorgangsposition,
				MitberatenVorgangstyp:      mitberaten.Vorgangstyp,
			}); err != nil {
				failedTracker.RecordIfDBLocked(vorgangsposition.Id, "CreateVorgangspositionMitberaten", err)
				log.Printf("Warning: Failed to store mitberaten for vorgangsposition %s: %v", vorgangsposition.Id, err)
			}
		}
	}
}
