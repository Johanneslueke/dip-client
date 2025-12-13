package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"os"
	"sync"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	client "github.com/Johanneslueke/dip-client/internal/gen"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	openapi_types "github.com/oapi-codegen/runtime/types"
	"github.com/pressly/goose/v3"
	_ "modernc.org/sqlite"
)

type rateLimiter struct {
	tokens     int
	maxTokens  int
	interval   time.Duration
	lastRefill time.Time
	mu         sync.Mutex
}

func newRateLimiter(maxRequests int, interval time.Duration) *rateLimiter {
	return &rateLimiter{
		tokens:     maxRequests,
		maxTokens:  maxRequests,
		interval:   interval,
		lastRefill: time.Now(),
	}
}

func (rl *rateLimiter) Wait(ctx context.Context) error {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	for {
		now := time.Now()
		elapsed := now.Sub(rl.lastRefill)

		if elapsed >= rl.interval {
			rl.tokens = rl.maxTokens
			rl.lastRefill = now
		}

		if rl.tokens > 0 {
			rl.tokens--
			return nil
		}

		waitTime := rl.interval - elapsed
		rl.mu.Unlock()

		select {
		case <-ctx.Done():
			rl.mu.Lock()
			return ctx.Err()
		case <-time.After(waitTime):
			rl.mu.Lock()
		}
	}
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
	limiter := newRateLimiter(23, time.Minute)

	var cursor *string
	totalElements := 0
	startTime := time.Now()

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

		// Print progress on same line using carriage return
		elapsed := time.Since(startTime)
		rate := float64(totalElements) / elapsed.Seconds()
		currentTotal := totalElements + len(resp.Documents)

		// Format elapsed time
		var timeStr string
		if elapsed.Hours() >= 1 {
			hours := int(elapsed.Hours())
			minutes := int(elapsed.Minutes()) % 60
			seconds := int(elapsed.Seconds()) % 60
			timeStr = fmt.Sprintf("%dh%dm%ds", hours, minutes, seconds)
		} else if elapsed.Minutes() >= 1 {
			hours := int(elapsed.Hours())
			minutes := int(elapsed.Minutes()) % 60
			seconds := int(elapsed.Seconds()) % 60
			timeStr = fmt.Sprintf("%dh%dm%ds", hours, minutes, seconds)
		} else {
			timeStr = fmt.Sprintf("%.0fm", elapsed.Minutes())
		}

		// Calculate estimated remaining time
		var etaStr string
		if rate > 0 && currentTotal > 0 {
			remaining := resp.NumFound - int32(currentTotal)
			if *limit > 0 && *limit < int(resp.NumFound) {
				remaining = int32(*limit) - int32(currentTotal)
			}
			if remaining > 0 {
				etaSeconds := float64(remaining) / rate
				etaDuration := time.Duration(etaSeconds) * time.Second
				hours := int(etaDuration.Hours())
				minutes := int(etaDuration.Minutes()) % 60
				seconds := int(etaDuration.Seconds()) % 60
				if etaDuration.Hours() >= 1 {

					etaStr = fmt.Sprintf(", ETA %dh%dm%ds", hours, minutes, seconds)
				} else if etaDuration.Minutes() >= 1 {
					etaStr = fmt.Sprintf(", ETA %dh%dm%ds", hours, minutes, seconds)
				} else {
					etaStr = fmt.Sprintf(", ETA %.0fm", etaDuration.Minutes())
				}
			}
		}

		fmt.Printf("\rFetched %d vorgänge (%.1f/sec, %.1f%% of %d total, %s %s)    ",
			currentTotal,
			rate,
			float64(currentTotal)/float64(resp.NumFound)*100,
			resp.NumFound,
			timeStr,
			etaStr)

		for _, vorgang := range resp.Documents {
			if err := storeVorgang(ctx, queries, vorgang); err != nil {
				log.Printf("Warning: Failed to store vorgang %s: %v", vorgang.Id, err)
			}
			totalElements++

			if *limit > 0 && totalElements >= *limit {
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
	elapsed := time.Since(startTime)
	rate := float64(totalElements) / elapsed.Seconds()
	log.Printf("Successfully stored %d vorgänge in database %s (%.1f/sec, took %s)",
		totalElements, *dbPath, rate, elapsed.Round(time.Second))

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
