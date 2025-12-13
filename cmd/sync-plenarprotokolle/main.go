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
	_ "modernc.org/sqlite"
)

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		dbPath  = flag.String("db", "dip.db", "SQLite database path")
		limit   = flag.Int("limit", 0, "Maximum number of plenarprotokolle to fetch (0 = all)")
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

	log.Printf("Starting to fetch plenarprotokolle from API...")

	for {
		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetPlenarprotokollListParams{
			Cursor: cursor,
		}

		resp, err := dipClient.GetPlenarprotokollList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch plenarprotokolle: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.PrintProgress(progress.Total+len(resp.Documents), int(resp.NumFound))

		for _, plenarprotokoll := range resp.Documents {
			if err := storePlenarprotokoll(ctx, queries, plenarprotokoll); err != nil {
				log.Printf("Warning: Failed to store plenarprotokoll %s: %v", plenarprotokoll.Id, err)
			}
			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d plenarprotokolle", *limit)
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
	log.Printf("Successfully stored %d plenarprotokolle in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))
}

func storePlenarprotokoll(ctx context.Context, q *db.Queries, plenarprotokoll client.Plenarprotokoll) error {
	existing, err := q.GetPlenarprotokoll(ctx, plenarprotokoll.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("failed to check if plenarprotokoll exists: %w", err)
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
			return fmt.Errorf("failed to update plenarprotokoll: %w", err)
		}
	} else {
		if _, err := q.CreatePlenarprotokoll(ctx, params); err != nil {
			return fmt.Errorf("failed to create plenarprotokoll: %w", err)
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
				log.Printf("Warning: Failed to store vorgangsbezug for plenarprotokoll %s: %v", plenarprotokoll.Id, err)
			}
		}
	}

	return nil
}
