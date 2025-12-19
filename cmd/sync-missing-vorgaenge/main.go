package main

import (
	"bufio"
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	// Command-line flags
	var (
		dbPath  = flag.String("db", "dip.clean.db", "Path to the SQLite database")
		apiKey  = flag.String("key", "", "API key for DIP API")
		idsFile = flag.String("ids", "/tmp/missing_vorgang_ids.txt", "File containing vorgang IDs to sync (one per line)")
		batch   = flag.Int("batch", 50, "Progress report interval")
	)
	flag.Parse()

	if *apiKey == "" {
		log.Fatal("API key is required (use -key flag)")
	}

	// Open database
	database, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer database.Close()

	queries := db.New(database)

	// Create API client
	apiClient, err := client.NewClientWithResponses(
		"https://search.dip.bundestag.de/api/v1",
		client.WithRequestEditorFn(func(ctx context.Context, req *http.Request) error {
			req.Header.Set("Authorization", fmt.Sprintf("ApiKey %s", *apiKey))
			return nil
		}),
	)
	if err != nil {
		log.Fatalf("Failed to create API client: %v", err)
	}

	// Read vorgang IDs from file
	ids, err := readVorgangIDs(*idsFile)
	if err != nil {
		log.Fatalf("Failed to read vorgang IDs: %v", err)
	}

	log.Printf("Starting sync of %d missing vorgänge", len(ids))
	log.Printf("Rate limit: 10 requests/second (100ms between requests)")
	log.Printf("Estimated time: ~%.1f minutes", float64(len(ids))*0.1/60)

	ctx := context.Background()
	successCount := 0
	notFoundCount := 0
	failCount := 0
	startTime := time.Now()

	for i, idStr := range ids {
		// Rate limiting: 100ms between requests (10 req/s)
		if i > 0 {
			time.Sleep(100 * time.Millisecond)
		}

		// Progress reporting
		if (i+1)%*batch == 0 {
			elapsed := time.Since(startTime)
			rate := float64(i+1) / elapsed.Seconds()
			remaining := time.Duration(float64(len(ids)-i-1)/rate) * time.Second
			log.Printf("Progress: %d/%d (%.1f%%) | Success: %d | Not Found: %d | Failed: %d | ETA: %v",
				i+1, len(ids), float64(i+1)/float64(len(ids))*100,
				successCount, notFoundCount, failCount, remaining.Round(time.Second))
		}

		// Convert ID string to int
		id, err := strconv.Atoi(idStr)
		if err != nil {
			log.Printf("ERROR: Invalid vorgang ID %s: %v", idStr, err)
			failCount++
			continue
		}

		// Fetch vorgang
		httpResp, err := apiClient.GetVorgang(ctx, client.Id(id), nil)
		if err != nil {
			log.Printf("ERROR: Failed to fetch vorgang %s: %v", idStr, err)
			failCount++
			continue
		}

		// Parse response
		resp, err := client.ParseGetVorgangResponse(httpResp)
		if err != nil {
			log.Printf("ERROR: Failed to parse response for vorgang %s: %v", idStr, err)
			failCount++
			continue
		}

		if resp.StatusCode() == 404 {
			log.Printf("WARNING: Vorgang %s not found (404) - may have been deleted", idStr)
			notFoundCount++
			continue
		}

		if resp.StatusCode() != 200 {
			log.Printf("ERROR: Unexpected status %d for vorgang %s", resp.StatusCode(), idStr)
			failCount++
			continue
		}

		vorgang := resp.JSON200
		if vorgang == nil {
			log.Printf("ERROR: Empty response for vorgang %s", idStr)
			failCount++
			continue
		}

		// Store vorgang
		if err := storeVorgang(ctx, queries, vorgang); err != nil {
			log.Printf("ERROR: Failed to store vorgang %s: %v", idStr, err)
			failCount++
			continue
		}

		successCount++
	}

	elapsed := time.Since(startTime)
	log.Printf("\n=== Sync Complete ===")
	log.Printf("Total processed: %d", len(ids))
	log.Printf("Successful: %d", successCount)
	log.Printf("Not found (404): %d", notFoundCount)
	log.Printf("Failed: %d", failCount)
	log.Printf("Time elapsed: %v", elapsed.Round(time.Second))
	log.Printf("Average rate: %.2f req/s", float64(len(ids))/elapsed.Seconds())
}

func readVorgangIDs(filename string) ([]string, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("open file: %w", err)
	}
	defer file.Close()

	var ids []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line != "" {
			ids = append(ids, line)
		}
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("scan file: %w", err)
	}

	return ids, nil
}

func storeVorgang(ctx context.Context, q *db.Queries, vorgang *client.Vorgang) error {
	// Check if exists
	existing, err := q.GetVorgang(ctx, vorgang.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("check existence: %w", err)
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
			return fmt.Errorf("update vorgang: %w", err)
		}
	} else {
		if _, err := q.CreateVorgang(ctx, params); err != nil {
			return fmt.Errorf("create vorgang: %w", err)
		}
	}

	// Store relations
	if vorgang.Initiative != nil {
		for _, init := range *vorgang.Initiative {
			if err := q.CreateVorgangInitiative(ctx, db.CreateVorgangInitiativeParams{
				VorgangID:  vorgang.Id,
				Initiative: init,
			}); err != nil {
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
				log.Printf("Warning: Failed to store deskriptor for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Verkuendung != nil {
		for _, verk := range *vorgang.Verkuendung {
			if _, err := q.CreateVerkuendung(ctx, db.CreateVerkuendungParams{
				VorgangID:                    vorgang.Id,
				Ausfertigungsdatum:           verk.Ausfertigungsdatum.UTC().String(),
				Verkuendungsdatum:            verk.Verkuendungsdatum.UTC().String(),
				Fundstelle:                   verk.Fundstelle,
				Einleitungstext:              verk.Einleitungstext,
				Jahrgang:                     verk.Jahrgang,
				Seite:                        verk.Seite,
				Heftnummer:                   ptrToNullString(verk.Heftnummer),
				PdfUrl:                       ptrToNullString(verk.PdfUrl),
				RubrikNr:                     ptrToNullString(verk.RubrikNr),
				Titel:                        ptrToNullString(verk.Titel),
				VerkuendungsblattBezeichnung: ptrToNullString(verk.VerkuendungsblattBezeichnung),
				VerkuendungsblattKuerzel:     ptrToNullString(verk.VerkuendungsblattKuerzel),
			}); err != nil {
				log.Printf("Warning: Failed to store verkuendung for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Inkrafttreten != nil {
		for _, ink := range *vorgang.Inkrafttreten {
			if _, err := q.CreateInkrafttreten(ctx, db.CreateInkrafttretenParams{
				VorgangID:    vorgang.Id,
				Datum:        ink.Datum.UTC().String(),
				Erlaeuterung: ptrToNullString(ink.Erlaeuterung),
			}); err != nil {
				log.Printf("Warning: Failed to store inkrafttreten for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.Zustimmungsbeduerftigkeit != nil {
		for _, zust := range *vorgang.Zustimmungsbeduerftigkeit {
			if err := q.CreateVorgangZustimmungsbeduerftigkeit(ctx, db.CreateVorgangZustimmungsbeduerftigkeitParams{
				VorgangID:                 vorgang.Id,
				Zustimmungsbeduerftigkeit: zust,
			}); err != nil {
				log.Printf("Warning: Failed to store zustimmungsbeduerftigkeit for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	if vorgang.VorgangVerlinkung != nil {
		for _, verlinkung := range *vorgang.VorgangVerlinkung {
			if _, err := q.CreateVorgangVerlinkung(ctx, db.CreateVorgangVerlinkungParams{
				SourceVorgangID: vorgang.Id,
				TargetVorgangID: verlinkung.Verweisung,
				Gesta:           ptrToNullString(vorgang.Gesta),
				Wahlperiode:     int64(vorgang.Wahlperiode),
				Titel:           "",
			}); err != nil {
				log.Printf("Warning: Failed to store vorgang verlinkung for vorgang %s: %v", vorgang.Id, err)
			}
		}
	}

	return nil
}
