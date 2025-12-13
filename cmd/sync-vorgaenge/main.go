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
	"github.com/pressly/goose/v3"
	_ "modernc.org/sqlite"
)



type progressTracker struct {
	startTime time.Time
	total     int
	limit     int
}

func newProgressTracker(limit int) *progressTracker {
	return &progressTracker{
		startTime: time.Now(),
		limit:     limit,
	}
}

func (pt *progressTracker) formatDuration(d time.Duration) string {
	if d.Hours() >= 1 {
		hours := int(d.Hours())
		minutes := int(d.Minutes()) % 60
		return fmt.Sprintf("%dh%dm", hours, minutes)
	}
	return fmt.Sprintf("%.0fm", d.Minutes())
}

func (pt *progressTracker) printProgress(current, totalAvailable int) {
	elapsed := time.Since(pt.startTime)
	rate := float64(pt.total) / elapsed.Seconds()
	
	timeStr := pt.formatDuration(elapsed)
	
	// Calculate estimated remaining time
	var etaStr string
	if rate > 0 && current > 0 {
		remaining := totalAvailable - current
		if pt.limit > 0 && pt.limit < totalAvailable {
			remaining = pt.limit - current
		}
		if remaining > 0 {
			etaSeconds := float64(remaining) / rate
			etaDuration := time.Duration(etaSeconds) * time.Second
			etaStr = fmt.Sprintf(", ETA %s", pt.formatDuration(etaDuration))
		}
	}
	
	fmt.Printf("\rFetched %d vorgänge (%.1f/sec, %.1f%% of %d total, %s%s)    ",
		current,
		rate,
		float64(current)/float64(totalAvailable)*100,
		totalAvailable,
		timeStr,
		etaStr)
}

func (pt *progressTracker) increment() {
	pt.total++
}

func (pt *progressTracker) getStats() (elapsed time.Duration, rate float64) {
	elapsed = time.Since(pt.startTime)
	rate = float64(pt.total) / elapsed.Seconds()
	return
}

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		dbPath  = flag.String("db", "dip.db", "SQLite database path")
		limit   = flag.Int("limit", 0, "Maximum number of vorgänge to fetch (0 = all)")
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

	if err := runMigrations(sqlDB); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	queries := db.New(sqlDB)
	ctx := context.Background()
	limiter := utility.NewRateLimiter(23, time.Minute)
	progress := newProgressTracker(*limit)

	var cursor *string

	log.Printf("Starting to fetch vorgänge from API...")

	for {
		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &client.GetVorgangListParams{
			Cursor: cursor,
		}

		resp, err := dipClient.GetVorgangList(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch vorgänge: %v", err)
		}

		if len(resp.Documents) == 0 {
			break
		}

		progress.printProgress(progress.total+len(resp.Documents), int(resp.NumFound))

		for _, vorgang := range resp.Documents {
			if err := storeVorgang(ctx, queries, vorgang); err != nil {
				log.Printf("Warning: Failed to store vorgang %s: %v", vorgang.Id, err)
			}
			progress.increment()

			if *limit > 0 && progress.total >= *limit {
				fmt.Println() // New line before final message
				log.Printf("Reached limit of %d vorgänge", *limit)
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
	elapsed, rate := progress.getStats()
	log.Printf("Successfully stored %d vorgänge in database %s (%.1f/sec, took %s)",
		progress.total, *dbPath, rate, elapsed.Round(time.Second))

}

func runMigrations(sqlDB *sql.DB) error {
	if err := goose.SetDialect("sqlite3"); err != nil {
		return fmt.Errorf("failed to set goose dialect: %w", err)
	}

	migrationsDir := "internal/database/migrations/sqlite"
	if err := goose.Up(sqlDB, migrationsDir); err != nil {
		return fmt.Errorf("failed to run migrations: %w", err)
	}

	log.Printf("Successfully ran all database migrations")
	return nil
}

func storeVorgang(ctx context.Context, q *db.Queries, vorgang client.Vorgang) error {
	existing, err := q.GetVorgang(ctx, vorgang.Id)
	if err != nil && err != sql.ErrNoRows {
		return fmt.Errorf("failed to check if vorgang exists: %w", err)
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
			return fmt.Errorf("failed to update vorgang: %w", err)
		}
	} else {
		if _, err := q.CreateVorgang(ctx, params); err != nil {
			return fmt.Errorf("failed to create vorgang: %w", err)
		}
	}

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

	return nil
}
