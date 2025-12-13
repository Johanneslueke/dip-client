package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	"github.com/Johanneslueke/dip-client/internal/utility"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	openapi_types "github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		dbPath  = flag.String("db", "dip.db", "SQLite database path")
		limit   = flag.Int("limit", 0, "Maximum number of aktivitäten to fetch (0 = all)")
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
	limiter := utility.NewRateLimiter(23, time.Minute)
	progress := utility.NewProgressTracker(*limit)

	var cursor *string

	log.Printf("Starting to fetch aktivitäten from API...")

	for {
		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetAktivitaetListParams{
			Cursor: cursor,
		}

		resp, err := dipClient.GetAktivitaetList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch aktivitäten: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, aktivitaet := range resp.Documents {
			if err := storeAktivitaet(ctx, queries, aktivitaet); err != nil {
				log.Printf("Warning: Failed to store aktivitaet %s: %v", aktivitaet.Id, err)
			}
			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d aktivitäten", *limit)
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
	log.Printf("Successfully stored %d aktivitäten in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))
}

func storeAktivitaet(ctx context.Context, q *db.Queries, aktivitaet client.Aktivitaet) error {
	existing, err := q.GetAktivitaet(ctx, aktivitaet.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("failed to check if aktivitaet exists: %w", err)
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

	if existing.ID != "" {
		updateParams := db.UpdateAktivitaetParams{
			ID:                  aktivitaet.Id,
			Titel:               params.Titel,
			Aktivitaetsart:      params.Aktivitaetsart,
			Aktualisiert:        params.Aktualisiert,
			Abstract:            params.Abstract,
			VorgangsbezugAnzahl: params.VorgangsbezugAnzahl,
		}
		if _, err := q.UpdateAktivitaet(ctx, updateParams); err != nil {
			return fmt.Errorf("failed to update aktivitaet: %w", err)
		}
	} else {
		if _, err := q.CreateAktivitaet(ctx, params); err != nil {
			return fmt.Errorf("failed to create aktivitaet: %w", err)
		}
	}

	// Store deskriptors
	if aktivitaet.Deskriptor != nil {
		for _, desk := range *aktivitaet.Deskriptor {
			if _, err := q.CreateAktivitaetDeskriptor(ctx, db.CreateAktivitaetDeskriptorParams{
				AktivitaetID: aktivitaet.Id,
				Name:         desk.Name,
				Typ:          string(desk.Typ),
			}); err != nil {
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
				log.Printf("Warning: Failed to store vorgangsbezug for aktivitaet %s: %v", aktivitaet.Id, err)
			}
		}
	}

	return nil
}
