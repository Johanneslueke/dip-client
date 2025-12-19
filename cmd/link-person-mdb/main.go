package main

import (
	"context"
	"database/sql"
	"flag"
	"fmt"
	"log"
	"strings"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	_ "modernc.org/sqlite"
)

// MatchStats tracks matching statistics
type MatchStats struct {
	TotalDIPPersons  int
	TotalMDBPersons  int
	ExactMatches     int
	HighConfidence   int
	MediumConfidence int
	Skipped          int
	AlreadyLinked    int
	MultipleMatches  int
	NoMatches        int
}

type MdBPerson struct {
	ID       string
	Vorname  string
	Nachname string
	Adel     sql.NullString
	Praefix  sql.NullString
}

func main() {
	// Parse command-line flags
	dbPath := flag.String("db", "dip.clean.db", "Path to SQLite database")
	dryRun := flag.Bool("dry-run", false, "Show matches without creating links")
	minConfidence := flag.String("min-confidence", "high", "Minimum confidence level to create links (exact, high, medium)")
	verbose := flag.Bool("verbose", false, "Show detailed matching information")
	flag.Parse()

	log.Printf("Opening database: %s", *dbPath)
	sqlDB, err := sql.Open("sqlite", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer sqlDB.Close()

	// Enable foreign keys
	if _, err := sqlDB.Exec("PRAGMA foreign_keys = ON"); err != nil {
		log.Fatalf("Failed to enable foreign keys: %v", err)
	}

	queries := db.New(sqlDB)
	ctx := context.Background()

	// Get all persons from both tables
	log.Println("Loading DIP persons...")
	dipPersons, err := sqlDB.Query("SELECT id, vorname, nachname FROM person ORDER BY id")
	if err != nil {
		log.Fatalf("Failed to query DIP persons: %v", err)
	}
	defer dipPersons.Close()

	log.Println("Loading MdB persons with names...")
	mdbPersons, err := sqlDB.Query(`
		SELECT 
			mp.id,
			mn.vorname,
			mn.nachname,
			mn.adel,
			mn.praefix,
			mn.historie_von
		FROM mdb_person mp
		JOIN mdb_name mn ON mp.id = mn.mdb_id
		WHERE mn.historie_bis IS NULL OR mn.historie_bis = ''
		ORDER BY mp.id
	`)
	if err != nil {
		log.Fatalf("Failed to query MdB persons: %v", err)
	}
	defer mdbPersons.Close()

	// Build MdB lookup map
	mdbMap := make(map[string][]MdBPerson) // key: normalized "nachname vorname"
	for mdbPersons.Next() {
		var p MdBPerson
		var historieVon sql.NullString
		if err := mdbPersons.Scan(&p.ID, &p.Vorname, &p.Nachname, &p.Adel, &p.Praefix, &historieVon); err != nil {
			log.Printf("Error scanning MdB person: %v", err)
			continue
		}
		key := normalizeNameKey(p.Vorname, p.Nachname)
		mdbMap[key] = append(mdbMap[key], p)
	}
	log.Printf("Loaded %d MdB persons (unique name keys: %d)", len(mdbMap), len(mdbMap))

	// Begin transaction for creating links
	tx, err := sqlDB.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}
	defer tx.Rollback()
	qtx := queries.WithTx(tx)

	stats := MatchStats{TotalMDBPersons: len(mdbMap)}

	// Process each DIP person
	nowStr := time.Now().Format(time.RFC3339)
	for dipPersons.Next() {
		var dipID, dipVorname, dipNachname string
		if err := dipPersons.Scan(&dipID, &dipVorname, &dipNachname); err != nil {
			log.Printf("Error scanning DIP person: %v", err)
			continue
		}
		stats.TotalDIPPersons++

		// Check if already linked
		existingLinks, err := qtx.GetPersonMdbLinks(ctx, dipID)
		if err == nil && len(existingLinks) > 0 {
			stats.AlreadyLinked++
			if *verbose {
				log.Printf("Person %s (%s %s) already linked to %d MdB(s)", dipID, dipVorname, dipNachname, len(existingLinks))
			}
			continue
		}

		// Try exact match
		key := normalizeNameKey(dipVorname, dipNachname)
		matches := mdbMap[key]

		// Try fuzzy matching
		if len(matches) == 0 {
			matches = findFuzzyMatches(dipVorname, dipNachname, mdbMap)
			if len(matches) == 0 {
				stats.NoMatches++
				if *verbose {
					log.Printf("No match: %s (%s %s)", dipID, dipVorname, dipNachname)
				}
				continue
			}
		}

		// Determine confidence and create links
		if len(matches) == 1 {
			// Single match
			match := matches[0]
			confidence, method := determineConfidence(dipVorname, dipNachname, match)
			if shouldCreateLink(confidence, *minConfidence) {
				if !*dryRun {
					err := qtx.CreatePersonMdbLink(ctx, db.CreatePersonMdbLinkParams{
						PersonID:        dipID,
						MdbID:           match.ID,
						MatchConfidence: confidence,
						MatchMethod:     method,
						VerifiedBy:      sql.NullString{Valid: false},
						VerifiedAt:      sql.NullString{Valid: false},
						Notes:           sql.NullString{Valid: false},
						CreatedAt:       nowStr,
						UpdatedAt:       nowStr,
					})
					if err != nil {
						log.Printf("Error creating link for %s: %v", dipID, err)
						continue
					}
				}
				switch confidence {
				case "exact":
					stats.ExactMatches++
				case "high":
					stats.HighConfidence++
				case "medium":
					stats.MediumConfidence++
				}
				if *verbose || *dryRun {
					log.Printf("[%s] %s: %s %s → MdB %s: %s %s (method: %s)",
						confidence, dipID, dipVorname, dipNachname,
						match.ID, match.Vorname, match.Nachname, method)
				}
			} else {
				stats.Skipped++
			}
		} else {
			// Multiple matches - requires manual verification
			stats.MultipleMatches++
			if *verbose {
				log.Printf("Multiple matches (%d) for %s (%s %s):", len(matches), dipID, dipVorname, dipNachname)
				for _, m := range matches {
					log.Printf("  - MdB %s: %s %s", m.ID, m.Vorname, m.Nachname)
				}
			}
		}
	}

	if !*dryRun {
		if err := tx.Commit(); err != nil {
			log.Fatalf("Failed to commit transaction: %v", err)
		}
		log.Println("Transaction committed successfully")
	} else {
		log.Println("Dry run mode - no changes made")
	}

	// Print statistics
	printStats(stats)
}

func normalizeNameKey(vorname, nachname string) string {
	v := strings.ToLower(strings.TrimSpace(vorname))
	n := strings.ToLower(strings.TrimSpace(nachname))
	// Remove common prefixes/suffixes
	n = strings.TrimPrefix(n, "von ")
	n = strings.TrimPrefix(n, "zu ")
	n = strings.TrimPrefix(n, "van ")
	n = strings.TrimSuffix(n, " jr.")
	n = strings.TrimSuffix(n, " sr.")
	return n + " " + v
}

func findFuzzyMatches(vorname, nachname string, mdbMap map[string][]MdBPerson) []MdBPerson {
	// Try common variations
	variations := []string{
		normalizeNameKey(vorname, nachname),
		normalizeNameKey(strings.Split(vorname, " ")[0], nachname), // First name only
		normalizeNameKey(vorname, strings.Split(nachname, "-")[0]), // First part of hyphenated name
	}

	// Try with umlauts normalized
	umlauts := map[string]string{
		"ä": "ae", "ö": "oe", "ü": "ue", "ß": "ss",
	}
	for old, new := range umlauts {
		v := strings.ReplaceAll(strings.ToLower(vorname), old, new)
		n := strings.ReplaceAll(strings.ToLower(nachname), old, new)
		variations = append(variations, normalizeNameKey(v, n))
	}

	seen := make(map[string]bool)
	var matches []MdBPerson
	for _, key := range variations {
		if persons, ok := mdbMap[key]; ok {
			for _, p := range persons {
				if !seen[p.ID] {
					matches = append(matches, p)
					seen[p.ID] = true
				}
			}
		}
	}
	return matches
}

func determineConfidence(dipVorname, dipNachname string, mdbPerson MdBPerson) (confidence, method string) {
	dipV := strings.ToLower(strings.TrimSpace(dipVorname))
	dipN := strings.ToLower(strings.TrimSpace(dipNachname))
	mdbV := strings.ToLower(strings.TrimSpace(mdbPerson.Vorname))
	mdbN := strings.ToLower(strings.TrimSpace(mdbPerson.Nachname))

	// Exact match
	if dipV == mdbV && dipN == mdbN {
		return "exact", "name_exact_match"
	}

	// High confidence: First name matches, last name matches with prefix
	if dipV == mdbV {
		if strings.Contains(mdbN, dipN) || strings.Contains(dipN, mdbN) {
			return "high", "name_with_prefix"
		}
	}

	// High confidence: Umlaut variations
	if normalizeUmlauts(dipV) == normalizeUmlauts(mdbV) &&
		normalizeUmlauts(dipN) == normalizeUmlauts(mdbN) {
		return "high", "name_umlaut_variation"
	}

	// Medium confidence: First name initial matches
	if len(dipV) > 0 && len(mdbV) > 0 && dipV[0] == mdbV[0] && dipN == mdbN {
		return "medium", "name_initial_match"
	}

	return "medium", "name_fuzzy_match"
}

func normalizeUmlauts(s string) string {
	s = strings.ReplaceAll(s, "ä", "ae")
	s = strings.ReplaceAll(s, "ö", "oe")
	s = strings.ReplaceAll(s, "ü", "ue")
	s = strings.ReplaceAll(s, "ß", "ss")
	return s
}

func shouldCreateLink(confidence, minConfidence string) bool {
	levels := map[string]int{
		"exact":  3,
		"high":   2,
		"medium": 1,
	}
	return levels[confidence] >= levels[minConfidence]
}

func printStats(stats MatchStats) {
	fmt.Println("\n=== Matching Statistics ===")
	fmt.Printf("  Total DIP persons:       %6d\n", stats.TotalDIPPersons)
	fmt.Printf("  Total MdB persons:       %6d\n", stats.TotalMDBPersons)
	fmt.Println()
	fmt.Printf("  Exact matches:           %6d\n", stats.ExactMatches)
	fmt.Printf("  High confidence:         %6d\n", stats.HighConfidence)
	fmt.Printf("  Medium confidence:       %6d\n", stats.MediumConfidence)
	fmt.Printf("  Already linked:          %6d\n", stats.AlreadyLinked)
	fmt.Printf("  Multiple matches:        %6d (require manual review)\n", stats.MultipleMatches)
	fmt.Printf("  No matches:              %6d\n", stats.NoMatches)
	fmt.Printf("  Skipped (below min):     %6d\n", stats.Skipped)
	fmt.Println()

	total := stats.ExactMatches + stats.HighConfidence + stats.MediumConfidence + stats.AlreadyLinked
	coverage := float64(total) / float64(stats.TotalDIPPersons) * 100
	fmt.Printf("  Total linked:            %6d (%.1f%% coverage)\n", total, coverage)
}
