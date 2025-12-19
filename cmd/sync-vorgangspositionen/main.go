package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen/v1.4"
	"github.com/Johanneslueke/dip-client/internal/utility"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	var (
		baseURL       = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey        = flag.String("key", "", "API key")
		dbPath        = flag.String("db", "dip.db", "SQLite database path")
		limit         = flag.Int("limit", 0, "Maximum number of vorgangspositionen to fetch (0 = all)")
		checkpointDir = flag.String("checkpoint-dir", ".checkpoints", "Directory to store checkpoints")
		failedDir     = flag.String("failed-dir", ".failed", "Directory to store failed record IDs")
		resume        = flag.Bool("resume", false, "Resume from last checkpoint")
		end           = flag.String("end", "", "End date for sync (YYYY-MM-DD)")
		wahlperiode   = flag.String("wahlperiode", "", "Filter by Wahlperiode numbers (comma-separated, e.g. '19,20' or empty = no filter)")
		vorgangID     = flag.Int("vorgang-id", 0, "Filter by specific Vorgang ID (0 = no filter)")
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
	//limiter := utility.NewRateLimiter(1, time.Minute)
	progress := utility.NewProgressTracker(*limit)
	failedTracker := utility.NewFailedRecordsTracker(*failedDir, "vorgangspositionen")

	// Checkpoint and signal handling
	var datumEnd *openapi_types.Date
	var lastProcessedDate time.Time
	interrupted := false

	if *resume {
		checkpoint, err := utility.LoadCheckpoint(*checkpointDir, "vorgangspositionen")
		if err != nil {
			log.Printf("Warning: Failed to load checkpoint: %v", err)
		} else if checkpoint != nil {
			lastProcessedDate = checkpoint.LastSyncDate
			date := openapi_types.Date{Time: lastProcessedDate}
			datumEnd = &date
			log.Printf("Resuming from checkpoint: %s", lastProcessedDate.Format("2006-01-02"))
		}
	}

	if *end != "" {
		endTime, err := time.Parse("2006-01-02", *end)
		if err != nil {
			log.Fatalf("Invalid end date format: %v", err)
		}
		date := openapi_types.Date{Time: endTime}
		datumEnd = &date
	}

	signalHandler := utility.NewSignalHandler(
		func() {
			interrupted = true
			if !lastProcessedDate.IsZero() {
				if err := utility.SaveCheckpoint(*checkpointDir, "vorgangspositionen", lastProcessedDate); err != nil {
					log.Printf("Error saving checkpoint: %v", err)
				} else {
					log.Printf("Checkpoint saved at %s", lastProcessedDate.Format("2006-01-02"))
				}
			}
		},
		nil,
	)
	defer signalHandler.Stop()

	var cursor *string

	// Log active filters
	filters := []string{}
	if datumEnd != nil {
		filters = append(filters, fmt.Sprintf("datum-end=%s", datumEnd.Time.Format("2006-01-02")))
	}
	if *wahlperiode != "" {
		filters = append(filters, fmt.Sprintf("wahlperiode=%s", *wahlperiode))
	}
	if *vorgangID > 0 {
		filters = append(filters, fmt.Sprintf("vorgang-id=%d", *vorgangID))
	}
	if len(filters) > 0 {
		log.Printf("Starting to fetch vorgangspositionen from API with filters: %s", strings.Join(filters, ", "))
	} else {
		log.Printf("Starting to fetch vorgangspositionen from API (no filters)...")
	}

	for {
		// Check if interrupted
		if signalHandler.IsInterrupted() || interrupted {
			fmt.Println() // New line after progress updates
			log.Printf("Interrupted after processing %d vorgangspositionen", progress.Total)
			return
		}

		// if err := limiter.Wait(ctx); err != nil {
		// 	log.Fatalf("Rate limiter error: %v", err)
		// }

		params := &client.GetVorgangspositionListParams{
			Cursor:    cursor,
			FDatumEnd: datumEnd,
		}

		// Add optional filters
			if *wahlperiode != "" {
				//split and convert to []WahlperiodeFilter if slice only contains one element use FWahlperiode if it contains multiple use FWahlperiodes
				wpStrings := strings.Split(*wahlperiode, ",")

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

			if *vorgangID > 0 {
				vorgangIds := make(client.IdFilter, 1)
				vorgangIds[0] = *vorgangID
				params.FId = &vorgangIds	
			}

		resp, err := dipClient.GetVorgangspositionList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch vorgangspositionen: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.Total += len(resp.Documents)
		progress.PrintProgress(progress.Total, int(resp.NumFound))

		for _, vorgangsposition := range resp.Documents {
			storeVorgangsposition(ctx, queries, vorgangsposition, failedTracker)

			// Track the last processed date for checkpoint
			if vorgangsposition.Datum.After(lastProcessedDate) {
				datum, err := queries.GetLatestVorgangspositionDatum(ctx)
				if err != nil {
					log.Printf("Warning: Failed to get latest vorgangsposition datum: %v", err)
					lastProcessedDate = vorgangsposition.Aktualisiert
				} else if t, ok := datum.(string); ok {
					if parsedDate, err := time.Parse("2006-01-02", t); err == nil {
						lastProcessedDate = parsedDate
					} else {
						lastProcessedDate = vorgangsposition.Aktualisiert
					}
				} else {
					lastProcessedDate = vorgangsposition.Aktualisiert
				}
			}  

			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d vorgangspositionen", *limit)
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
	log.Printf("Successfully stored %d vorgangspositionen in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))

	// Save failed records if any
	if failedTracker.Count() > 0 {
		if err := failedTracker.Save(); err != nil {
			log.Printf("Warning: Failed to save failed records: %v", err)
		} else {
			log.Printf("⚠️  %d records failed due to DB locks, saved to %s/vorgangspositionen.failed.json", failedTracker.Count(), *failedDir)
		}
	}

	// Delete checkpoint on successful completion
	if !interrupted && *resume {
		if err := utility.DeleteCheckpoint(*checkpointDir, "vorgangspositionen"); err != nil {
			log.Printf("Warning: Failed to delete checkpoint: %v", err)
		}
	}
}

func storeVorgangsposition(ctx context.Context, q *db.Queries, vorgangsposition client.Vorgangsposition, failedTracker *utility.FailedRecordsTracker) {
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
