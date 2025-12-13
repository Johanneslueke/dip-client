package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	"github.com/Johanneslueke/dip-client/internal/utility"
	dipclient "github.com/Johanneslueke/dip-client/pkg/dip-client"
	"github.com/oapi-codegen/runtime/types"
	_ "modernc.org/sqlite"
)

// PersonWithArrayWahlperiode handles the API response where wahlperiode is an array
type PersonWithArrayWahlperiode struct {
	Id               string                  `json:"id"`
	Nachname         string                  `json:"nachname"`
	Vorname          string                  `json:"vorname"`
	Namenszusatz     *string                 `json:"namenszusatz,omitempty"`
	Typ              string                  `json:"typ"`
	WahlperiodeArray *[]int32                `json:"wahlperiode,omitempty"`
	Basisdatum       *types.Date             `json:"basisdatum,omitempty"`
	Datum            *types.Date             `json:"datum,omitempty"`
	Aktualisiert     time.Time               `json:"aktualisiert"`
	Titel            string                  `json:"titel"`
	PersonRoles      *[]dipclient.PersonRole `json:"person_roles,omitempty"`
}

func main() {
	var (
		baseURL = flag.String("url", "https://search.dip.bundestag.de/api/v1", "API base URL")
		apiKey  = flag.String("key", "", "API key")
		dbPath  = flag.String("db", "dip.db", "SQLite database path")
		limit   = flag.Int("limit", 0, "Maximum number of persons to fetch (0 = all)")
	)
	flag.Parse()

	if *apiKey == "" {
		*apiKey = os.Getenv("DIP_API_KEY")
	}

	if *apiKey == "" {
		log.Fatal("API key required (use -key flag or DIP_API_KEY environment variable)")
	}

	// Initialize DIP API client
	client, err := dipclient.New(dipclient.Config{
		BaseURL: *baseURL,
		APIKey:  *apiKey,
	})
	if err != nil {
		log.Fatalf("Failed to create API client: %v", err)
	}

	// Open SQLite database
	sqlDB, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer sqlDB.Close()

	// Run migrations
	if err := utility.RunMigrations(sqlDB); err != nil {
		log.Fatalf("Failed to run migrations: %v", err)
	}

	queries := db.New(sqlDB)
	ctx := context.Background()

	// Initialize rate limiter: 23 requests per minute (leaving 1 request buffer)
	limiter := utility.NewRateLimiter(23, time.Minute)
	progress := utility.NewProgressTracker(*limit)

	// Fetch and store persons
	var cursor *string
	totalFetched := 0
	personCount := 0

	log.Printf("Starting to fetch persons from API...")

	for {
		// Wait for rate limiter before making request
		if err := limiter.Wait(ctx); err != nil {
			log.Fatalf("Rate limiter error: %v", err)
		}

		params := &dipclient.GetPersonListParams{
			Cursor: cursor,
		}

		// Use custom response handler to deal with wahlperiode array
		respBody, err := client.GetPersonListRaw(ctx, params)
		if err != nil {
			log.Fatalf("Failed to fetch persons: %v", err)
		}

		var result struct {
			Cursor    string                       `json:"cursor"`
			Documents []PersonWithArrayWahlperiode `json:"documents"`
			NumFound  int32                        `json:"numFound"`
		}

		if err := json.Unmarshal(respBody, &result); err != nil {
			log.Fatalf("Failed to parse response: %v", err)
		}

		log.Printf("Fetched %d persons (total so far: %d, API reports %d total)",
			len(result.Documents), totalFetched+len(result.Documents), result.NumFound)

		progress.PrintProgress(totalFetched+len(result.Documents), int(result.NumFound))


		// Store each person
		for _, person := range result.Documents {
			if err := storePerson(ctx, queries, person); err != nil {
				log.Printf("Warning: Failed to store person %s: %v", person.Id, err)
				continue
			}
			personCount++
			progress.Increment()

			if *limit > 0 && progress.Total >= *limit {
				log.Printf("Reached limit of %d persons", *limit)
				goto done
			}
		}

		totalFetched += len(result.Documents)

		// Check if we should continue
		if len(result.Documents) == 0 || result.Cursor == "" || (*limit > 0 && totalFetched >= *limit) {
			break
		}

		cursor = &result.Cursor
	}

done:
	fmt.Println() // New line after progress updates
	elapsed, rate := progress.GetStats()
	log.Printf("Successfully stored %d vorgänge in database %s (%.1f/sec, took %s)",
		progress.Total, *dbPath, rate, elapsed.Round(time.Second))
}

 

func storePerson(ctx context.Context, q *db.Queries, person PersonWithArrayWahlperiode) error {
	// Ensure wahlperioden exist (use array if available)
	if person.WahlperiodeArray != nil {
		for _, wp := range *person.WahlperiodeArray {
			if _, err := q.GetOrCreateWahlperiode(ctx, int64(wp)); err != nil {
				return fmt.Errorf("failed to create wahlperiode: %w", err)
			}
		}
	}

	// Parse timestamps
	aktualisiert := person.Aktualisiert.Format(time.RFC3339)
	var basisdatum, datum sql.NullString

	if person.Basisdatum != nil {
		basisdatum.Valid = true
		basisdatum.String = person.Basisdatum.String()
	}

	if person.Datum != nil {
		datum.Valid = true
		datum.String = person.Datum.String()
	}

	var namenszusatz sql.NullString
	if person.Namenszusatz != nil {
		namenszusatz.Valid = true
		namenszusatz.String = *person.Namenszusatz
	}

	// Create person
	_, err := q.CreatePerson(ctx, db.CreatePersonParams{
		ID:           person.Id,
		Vorname:      person.Vorname,
		Nachname:     person.Nachname,
		Namenszusatz: namenszusatz,
		Titel:        person.Titel,
		Typ:          person.Typ,
		Aktualisiert: aktualisiert,
		Basisdatum:   basisdatum,
		Datum:        datum,
	})
	if err != nil {
		// Person might already exist - try to update
		_, err = q.UpdatePerson(ctx, db.UpdatePersonParams{
			ID:           person.Id,
			Vorname:      person.Vorname,
			Nachname:     person.Nachname,
			Namenszusatz: namenszusatz,
			Titel:        person.Titel,
			Aktualisiert: aktualisiert,
			Basisdatum:   basisdatum,
			Datum:        datum,
		})
		if err != nil {
			return fmt.Errorf("failed to create or update person: %w", err)
		}
	}

	// Store wahlperiode associations
	if person.WahlperiodeArray != nil {
		for _, wp := range *person.WahlperiodeArray {
			if err := q.CreatePersonWahlperiode(ctx, db.CreatePersonWahlperiodeParams{
				PersonID:          person.Id,
				WahlperiodeNummer: int64(wp),
			}); err != nil {
				log.Printf("Warning: Failed to link person %s to wahlperiode %d: %v", person.Id, wp, err)
			}
		}
	}

	// Store person roles if available
	if person.PersonRoles != nil {
		for _, role := range *person.PersonRoles {
			if err := storePersonRole(ctx, q, person.Id, role); err != nil {
				log.Printf("Warning: Failed to store role for person %s: %v", person.Id, err)
			}
		}
	}

	return nil
}

func storePersonRole(ctx context.Context, q *db.Queries, personID string, role dipclient.PersonRole) error {
	// Ensure bundesland exists if specified
	if role.Bundesland != nil {
		if _, err := q.GetOrCreateBundesland(ctx, string(*role.Bundesland)); err != nil {
			return fmt.Errorf("failed to create bundesland: %w", err)
		}
	}

	var bundesland, fraktion, funktionszusatz, namenszusatz, ressortTitel, wahlkreiszusatz sql.NullString

	if role.Bundesland != nil {
		bundesland.Valid = true
		bundesland.String = string(*role.Bundesland)
	}
	if role.Fraktion != nil {
		fraktion.Valid = true
		fraktion.String = *role.Fraktion
	}
	if role.Funktionszusatz != nil {
		funktionszusatz.Valid = true
		funktionszusatz.String = *role.Funktionszusatz
	}
	if role.Namenszusatz != nil {
		namenszusatz.Valid = true
		namenszusatz.String = *role.Namenszusatz
	}
	if role.RessortTitel != nil {
		ressortTitel.Valid = true
		ressortTitel.String = *role.RessortTitel
	}
	if role.Wahlkreiszusatz != nil {
		wahlkreiszusatz.Valid = true
		wahlkreiszusatz.String = *role.Wahlkreiszusatz
	}

	personRole, err := q.CreatePersonRole(ctx, db.CreatePersonRoleParams{
		PersonID:        personID,
		Funktion:        role.Funktion,
		Funktionszusatz: funktionszusatz,
		Vorname:         role.Vorname,
		Nachname:        role.Nachname,
		Namenszusatz:    namenszusatz,
		Fraktion:        fraktion,
		Bundesland:      bundesland,
		RessortTitel:    ressortTitel,
		Wahlkreiszusatz: wahlkreiszusatz,
	})
	if err != nil {
		return fmt.Errorf("failed to create person role: %w", err)
	}

	// Store wahlperiode associations
	if role.WahlperiodeNummer != nil {
		for _, wp := range *role.WahlperiodeNummer {
			// Ensure wahlperiode exists
			if _, err := q.GetOrCreateWahlperiode(ctx, int64(wp)); err != nil {
				log.Printf("Warning: Failed to create wahlperiode %d: %v", wp, err)
				continue
			}

			if err := q.CreatePersonRoleWahlperiode(ctx, db.CreatePersonRoleWahlperiodeParams{
				PersonRoleID:      personRole.ID,
				WahlperiodeNummer: int64(wp),
			}); err != nil {
				log.Printf("Warning: Failed to link role to wahlperiode %d: %v", wp, err)
			}
		}
	}

	return nil
}
