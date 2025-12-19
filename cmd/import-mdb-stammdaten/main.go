package main

import (
	"context"
	"database/sql"
	"encoding/xml"
	"flag"
	"fmt"
	"log"
	"os"
	"time"

	db "github.com/Johanneslueke/dip-client/internal/database/gen/sqlite"
	_ "modernc.org/sqlite"
)

// XML structure matching MDB_STAMMDATEN.DTD
type Document struct {
	XMLName xml.Name `xml:"DOCUMENT"`
	Version string   `xml:"VERSION,attr"`
	MDBs    []MDB    `xml:"MDB"`
}

type MDB struct {
	ID                   string               `xml:"ID"`
	Namen                []Name               `xml:"NAMEN>NAME"`
	BiographischeAngaben BiographischeAngaben `xml:"BIOGRAFISCHE_ANGABEN"`
	Wahlperioden         []Wahlperiode        `xml:"WAHLPERIODEN>WAHLPERIODE"`
}

type Name struct {
	Nachname    string `xml:"NACHNAME"`
	Vorname     string `xml:"VORNAME"`
	Ortszusatz  string `xml:"ORTSZUSATZ"`
	Adel        string `xml:"ADEL"`
	Praefix     string `xml:"PRAEFIX"`
	AnredeTitel string `xml:"ANREDE_TITEL"`
	AkadTitel   string `xml:"AKAD_TITEL"`
	HistorieVon string `xml:"HISTORIE_VON"`
	HistorieBis string `xml:"HISTORIE_BIS"`
}

type BiographischeAngaben struct {
	Geburtsdatum                  string `xml:"GEBURTSDATUM"`
	Geburtsort                    string `xml:"GEBURTSORT"`
	Geburtsland                   string `xml:"GEBURTSLAND"`
	Sterbedatum                   string `xml:"STERBEDATUM"`
	Geschlecht                    string `xml:"GESCHLECHT"`
	Familienstand                 string `xml:"FAMILIENSTAND"`
	Religion                      string `xml:"RELIGION"`
	Beruf                         string `xml:"BERUF"`
	Vita                          string `xml:"VITA_KURZ"`
	VeroeffentlichungspflichtGem1 string `xml:"VEROEFFENTLICHUNGSPFLICHTIGES"`
	ParteiKurz                    string `xml:"PARTEI_KURZ"`
}

type Wahlperiode struct {
	WP            int32         `xml:"WP"`
	MdbWpVon      string        `xml:"MDBWP_VON"`
	MdbWpBis      string        `xml:"MDBWP_BIS"`
	WkrNummer     string        `xml:"WKR_NUMMER"`
	WkrName       string        `xml:"WKR_NAME"`
	WkrLand       string        `xml:"WKR_LAND"`
	Liste         string        `xml:"LISTE"`
	Mandatsart    string        `xml:"MANDATSART"`
	Institutionen []Institution `xml:"INSTITUTIONEN>INSTITUTION"`
}

type Institution struct {
	InsartLang string `xml:"INSART_LANG"`
	InsLang    string `xml:"INS_LANG"`
	MdbinsVon  string `xml:"MDBINS_VON"`
	MdbinsBis  string `xml:"MDBINS_BIS"`
	FktLang    string `xml:"FKT_LANG"`
	FktinsVon  string `xml:"FKTINS_VON"`
	FktinsBis  string `xml:"FKTINS_BIS"`
}

// Statistics for tracking import progress
type ImportStats struct {
	TotalMDBs            int
	PersonsInserted      int
	NamesInserted        int
	BiographicalInserted int
	WahlperiodenInserted int
	InstitutionsInserted int
	Errors               int
}

func main() {
	// Parse command-line flags
	dbPath := flag.String("db", "dip.clean.db", "Path to SQLite database")
	xmlPath := flag.String("xml", "MdB-Stammdaten/MDB_STAMMDATEN.XML", "Path to MDB_STAMMDATEN.XML file")
	dryRun := flag.Bool("dry-run", false, "Parse XML without importing to database")
	verbose := flag.Bool("verbose", false, "Show detailed progress information")
	flag.Parse()

	// Open and parse XML file
	log.Printf("Opening XML file: %s", *xmlPath)
	xmlFile, err := os.Open(*xmlPath)
	if err != nil {
		log.Fatalf("Failed to open XML file: %v", err)
	}
	defer xmlFile.Close()

	// Parse XML
	log.Println("Parsing XML...")
	decoder := xml.NewDecoder(xmlFile)
	var doc Document
	if err := decoder.Decode(&doc); err != nil {
		log.Fatalf("Failed to parse XML: %v", err)
	}

	log.Printf("Successfully parsed XML version %s with %d MdB records", doc.Version, len(doc.MDBs))

	if *dryRun {
		log.Println("Dry run mode - showing statistics only:")
		stats := analyzeDocument(doc)
		printStats(stats)
		return
	}

	// Open database connection
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

	// Create queries instance
	queries := db.New(sqlDB)

	// Import data
	log.Println("Starting import...")
	stats := importDocument(sqlDB, queries, doc, *xmlPath, *verbose)

	log.Println("\n=== Import Complete ===")
	printStats(stats)

	if stats.Errors > 0 {
		log.Printf("WARNING: %d errors occurred during import", stats.Errors)
		os.Exit(1)
	}
}

func analyzeDocument(doc Document) ImportStats {
	stats := ImportStats{
		TotalMDBs: len(doc.MDBs),
	}

	for _, mdb := range doc.MDBs {
		stats.PersonsInserted++
		stats.NamesInserted += len(mdb.Namen)
		if hasNonEmptyBio(mdb.BiographischeAngaben) {
			stats.BiographicalInserted++
		}
		stats.WahlperiodenInserted += len(mdb.Wahlperioden)
		for _, wp := range mdb.Wahlperioden {
			stats.InstitutionsInserted += len(wp.Institutionen)
		}
	}

	return stats
}

func hasNonEmptyBio(bio BiographischeAngaben) bool {
	return bio.Geburtsdatum != "" || bio.Geburtsort != "" || bio.Geburtsland != "" ||
		bio.Sterbedatum != "" || bio.Geschlecht != "" || bio.Familienstand != "" ||
		bio.Religion != "" || bio.Beruf != "" || bio.Vita != "" ||
		bio.VeroeffentlichungspflichtGem1 != "" || bio.ParteiKurz != ""
}

func importDocument(sqlDB *sql.DB, queries *db.Queries, doc Document, xmlPath string, verbose bool) ImportStats {
	ctx := context.Background()
	stats := ImportStats{
		TotalMDBs: len(doc.MDBs),
	}

	// Begin transaction
	tx, err := sqlDB.BeginTx(ctx, nil)
	if err != nil {
		log.Fatalf("Failed to begin transaction: %v", err)
	}
	defer tx.Rollback()

	// Create queries with transaction
	qtx := queries.WithTx(tx)

	// Record version
	if _, err := qtx.CreateMdbStammdatenVersion(ctx, db.CreateMdbStammdatenVersionParams{
		Version:    doc.Version,
		ImportDate: time.Now().Format(time.RFC3339),
		SourceFile: xmlPath,
	}); err != nil {
		log.Fatalf("Failed to record version: %v", err)
	}

	// Import each MdB
	startTime := time.Now()
	for i, mdb := range doc.MDBs {
		if verbose && (i+1)%100 == 0 {
			elapsed := time.Since(startTime)
			rate := float64(i+1) / elapsed.Seconds()
			log.Printf("Progress: %d/%d MdBs (%.1f records/sec)", i+1, len(doc.MDBs), rate)
		}

		if err := importMDB(ctx, qtx, mdb, &stats); err != nil {
			log.Printf("ERROR importing MdB %s: %v", mdb.ID, err)
			stats.Errors++
			continue
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		log.Fatalf("Failed to commit transaction: %v", err)
	}

	return stats
}

func importMDB(ctx context.Context, qtx *db.Queries, mdb MDB, stats *ImportStats) error {
	nowStr := time.Now().Format(time.RFC3339)

	// Insert person
	err := qtx.CreateMdbPerson(ctx, db.CreateMdbPersonParams{
		ID:        mdb.ID,
		CreatedAt: nowStr,
		UpdatedAt: nowStr,
	})
	if err != nil {
		return fmt.Errorf("insert person: %w", err)
	}
	stats.PersonsInserted++

	// Insert names
	for _, name := range mdb.Namen {
		err := qtx.CreateMdbName(ctx, db.CreateMdbNameParams{
			MdbID:       mdb.ID,
			Nachname:    name.Nachname,
			Vorname:     name.Vorname,
			Ortszusatz:  nullString(name.Ortszusatz),
			Adel:        nullString(name.Adel),
			Praefix:     nullString(name.Praefix),
			AnredeTitel: nullString(name.AnredeTitel),
			AkadTitel:   nullString(name.AkadTitel),
			HistorieVon: nullString(name.HistorieVon),
			HistorieBis: nullString(name.HistorieBis),
			CreatedAt:   nowStr,
			UpdatedAt:   nowStr,
		})
		if err != nil {
			return fmt.Errorf("insert name: %w", err)
		}
		stats.NamesInserted++
	}

	// Insert biographical data (always insert, even if all fields are empty)
	bio := mdb.BiographischeAngaben
	err = qtx.CreateMdbBiographical(ctx, db.CreateMdbBiographicalParams{
		MdbID:                         mdb.ID,
		Geburtsdatum:                  nullString(bio.Geburtsdatum),
		Geburtsort:                    nullString(bio.Geburtsort),
		Geburtsland:                   nullString(bio.Geburtsland),
		Sterbedatum:                   nullString(bio.Sterbedatum),
		Geschlecht:                    nullString(bio.Geschlecht),
		Familienstand:                 nullString(bio.Familienstand),
		Religion:                      nullString(bio.Religion),
		Beruf:                         nullString(bio.Beruf),
		VitaKurz:                      nullString(bio.Vita),
		Veroeffentlichungspflichtiges: nullString(bio.VeroeffentlichungspflichtGem1),
		ParteiKurz:                    nullString(bio.ParteiKurz),
		CreatedAt:                     nowStr,
		UpdatedAt:                     nowStr,
	})
	if err != nil {
		return fmt.Errorf("insert biographical: %w", err)
	}
	stats.BiographicalInserted++

	// Insert wahlperioden
	for _, wp := range mdb.Wahlperioden {
		wpMembershipID, err := qtx.CreateMdbWahlperiodeMembership(ctx, db.CreateMdbWahlperiodeMembershipParams{
			MdbID:      mdb.ID,
			Wp:         int64(wp.WP),
			MdbwpVon:   wp.MdbWpVon,
			MdbwpBis:   nullString(wp.MdbWpBis),
			WkrNummer:  nullString(wp.WkrNummer),
			WkrName:    nullString(wp.WkrName),
			WkrLand:    nullString(wp.WkrLand),
			Liste:      nullString(wp.Liste),
			Mandatsart: nullString(wp.Mandatsart),
			CreatedAt:  nowStr,
			UpdatedAt:  nowStr,
		})
		if err != nil {
			return fmt.Errorf("insert wahlperiode %d: %w", wp.WP, err)
		}
		stats.WahlperiodenInserted++

		// Insert institutions for this wahlperiode
		for _, inst := range wp.Institutionen {
			err := qtx.CreateMdbInstitutionMembership(ctx, db.CreateMdbInstitutionMembershipParams{
				MdbWahlperiodeMembershipID: wpMembershipID,
				InsartLang:                 inst.InsartLang,
				InsLang:                    inst.InsLang,
				MdbinsVon:                  nullString(inst.MdbinsVon),
				MdbinsBis:                  nullString(inst.MdbinsBis),
				FktLang:                    nullString(inst.FktLang),
				FktinsVon:                  nullString(inst.FktinsVon),
				FktinsBis:                  nullString(inst.FktinsBis),
				CreatedAt:                  nowStr,
				UpdatedAt:                  nowStr,
			})
			if err != nil {
				return fmt.Errorf("insert institution: %w", err)
			}
			stats.InstitutionsInserted++
		}
	}

	return nil
}

func nullString(s string) sql.NullString {
	if s == "" {
		return sql.NullString{Valid: false}
	}
	return sql.NullString{String: s, Valid: true}
}

func printStats(stats ImportStats) {
	fmt.Printf("  Total MdB records:       %6d\n", stats.TotalMDBs)
	fmt.Printf("  Persons inserted:        %6d\n", stats.PersonsInserted)
	fmt.Printf("  Names inserted:          %6d\n", stats.NamesInserted)
	fmt.Printf("  Biographical inserted:   %6d\n", stats.BiographicalInserted)
	fmt.Printf("  Wahlperioden inserted:   %6d\n", stats.WahlperiodenInserted)
	fmt.Printf("  Institutions inserted:   %6d\n", stats.InstitutionsInserted)
	if stats.Errors > 0 {
		fmt.Printf("  Errors:                  %6d\n", stats.Errors)
	}
}
