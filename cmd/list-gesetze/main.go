package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"

	_ "github.com/mattn/go-sqlite3"
)

type GesetzEntry struct {
	VorgangID                 string  `json:"vorgang_id"`
	GesetzTitel               string  `json:"gesetz_titel"`
	Vorgangstyp               string  `json:"vorgangstyp"`
	Beratungsstand            *string `json:"beratungsstand,omitempty"`
	VorgangDatum              *string `json:"vorgang_datum,omitempty"`
	VorgangAktualisiert       string  `json:"vorgang_aktualisiert"`
	Wahlperiode               int     `json:"wahlperiode"`
	Gesta                     *string `json:"gesta,omitempty"`
	Sachgebiete               *string `json:"sachgebiete,omitempty"`
	Initiativen               *string `json:"initiativen,omitempty"`
	Deskriptoren              *string `json:"deskriptoren,omitempty"`
	Ausfertigungsdatum        *string `json:"ausfertigungsdatum,omitempty"`
	Verkuendungsdatum         *string `json:"verkuendungsdatum,omitempty"`
	VerkuendungFundstelle     *string `json:"verkuendung_fundstelle,omitempty"`
	VerkuendungPdfURL         *string `json:"verkuendung_pdf_url,omitempty"`
	InkrafttretenDatum        *string `json:"inkrafttreten_datum,omitempty"`
	InkrafttretenErlaeuterung *string `json:"inkrafttreten_erlaeuterung,omitempty"`
	AnzahlVorgangspositionen  int     `json:"anzahl_vorgangspositionen"`
	AnzahlAktivitaeten        int     `json:"anzahl_aktivitaeten"`
	AnzahlDrucksachen         int     `json:"anzahl_drucksachen"`
	AnzahlPlenarprotokolle    int     `json:"anzahl_plenarprotokolle"`
}

func main() {
	var (
		dbPath         = flag.String("db", "dip.db", "Path to SQLite database")
		limit          = flag.Int("limit", 100, "Maximum number of results")
		offset         = flag.Int("offset", 0, "Offset for pagination")
		wahlperiode    = flag.Int("wahlperiode", 0, "Filter by Wahlperiode (0 = all)")
		beratungsstand = flag.String("beratungsstand", "", "Filter by Beratungsstand (empty = all)")
		sachgebiet     = flag.String("sachgebiet", "", "Filter by Sachgebiet (empty = all)")
		verkuendet     = flag.Bool("verkuendet", false, "Show only verkündete Gesetze")
		inkraft        = flag.Bool("inkraft", false, "Show only in-kraft-getretene Gesetze")
		formatJSON     = flag.Bool("json", false, "Output as JSON")
	)
	flag.Parse()

	if *dbPath == "" {
		log.Fatal("Database path required (use -db flag)")
	}

	db, err := sql.Open("sqlite3", *dbPath)
	if err != nil {
		log.Fatalf("Failed to open database: %v", err)
	}
	defer db.Close()

	ctx := context.Background()

	// Build query with filters
	query := `
		SELECT 
			vorgang_id,
			gesetz_titel,
			vorgangstyp,
			beratungsstand,
			vorgang_datum,
			vorgang_aktualisiert,
			wahlperiode,
			gesta,
			sachgebiete,
			initiativen,
			deskriptoren,
			ausfertigungsdatum,
			verkuendungsdatum,
			verkuendung_fundstelle,
			verkuendung_pdf_url,
			inkrafttreten_datum,
			inkrafttreten_erlaeuterung,
			anzahl_vorgangspositionen,
			anzahl_aktivitaeten,
			anzahl_drucksachen,
			anzahl_plenarprotokolle
		FROM gesetz_trace
		WHERE 1=1
	`

	args := []interface{}{}

	if *wahlperiode > 0 {
		query += " AND wahlperiode = ?"
		args = append(args, *wahlperiode)
	}

	if *beratungsstand != "" {
		query += " AND beratungsstand = ?"
		args = append(args, *beratungsstand)
	}

	if *sachgebiet != "" {
		query += " AND sachgebiete LIKE ?"
		args = append(args, "%"+*sachgebiet+"%")
	}

	if *verkuendet {
		query += " AND verkuendungsdatum IS NOT NULL"
	}

	if *inkraft {
		query += " AND inkrafttreten_datum IS NOT NULL"
	}

	query += " ORDER BY vorgang_aktualisiert DESC LIMIT ? OFFSET ?"
	args = append(args, *limit, *offset)

	rows, err := db.QueryContext(ctx, query, args...)
	if err != nil {
		log.Fatalf("Failed to query database: %v", err)
	}
	defer rows.Close()

	var gesetze []GesetzEntry

	for rows.Next() {
		var g GesetzEntry
		err := rows.Scan(
			&g.VorgangID,
			&g.GesetzTitel,
			&g.Vorgangstyp,
			&g.Beratungsstand,
			&g.VorgangDatum,
			&g.VorgangAktualisiert,
			&g.Wahlperiode,
			&g.Gesta,
			&g.Sachgebiete,
			&g.Initiativen,
			&g.Deskriptoren,
			&g.Ausfertigungsdatum,
			&g.Verkuendungsdatum,
			&g.VerkuendungFundstelle,
			&g.VerkuendungPdfURL,
			&g.InkrafttretenDatum,
			&g.InkrafttretenErlaeuterung,
			&g.AnzahlVorgangspositionen,
			&g.AnzahlAktivitaeten,
			&g.AnzahlDrucksachen,
			&g.AnzahlPlenarprotokolle,
		)
		if err != nil {
			log.Fatalf("Failed to scan row: %v", err)
		}
		gesetze = append(gesetze, g)
	}

	if err := rows.Err(); err != nil {
		log.Fatalf("Row iteration error: %v", err)
	}

	if *formatJSON {
		output, err := json.MarshalIndent(gesetze, "", "  ")
		if err != nil {
			log.Fatalf("Failed to marshal JSON: %v", err)
		}
		fmt.Println(string(output))
	} else {
		// Plain text output
		fmt.Printf("Found %d Gesetze:\n\n", len(gesetze))
		for i, g := range gesetze {
			fmt.Printf("─────────────────────────────────────────────────────────────────────────\n")
			fmt.Printf("[%d] %s\n", i+1, g.GesetzTitel)
			fmt.Printf("    Vorgang-ID: %s\n", g.VorgangID)
			fmt.Printf("    Wahlperiode: %d\n", g.Wahlperiode)
			if g.Beratungsstand != nil {
				fmt.Printf("    Beratungsstand: %s\n", *g.Beratungsstand)
			}
			if g.VorgangDatum != nil {
				fmt.Printf("    Datum: %s\n", *g.VorgangDatum)
			}
			if g.Sachgebiete != nil {
				fmt.Printf("    Sachgebiete: %s\n", *g.Sachgebiete)
			}
			if g.Initiativen != nil {
				fmt.Printf("    Initiativen: %s\n", *g.Initiativen)
			}
			if g.Verkuendungsdatum != nil {
				fmt.Printf("    Verkündet am: %s\n", *g.Verkuendungsdatum)
				if g.VerkuendungFundstelle != nil {
					fmt.Printf("    Fundstelle: %s\n", *g.VerkuendungFundstelle)
				}
			}
			if g.InkrafttretenDatum != nil {
				fmt.Printf("    In Kraft seit: %s\n", *g.InkrafttretenDatum)
			}
			fmt.Printf("    Anzahl: %d Positionen, %d Aktivitäten, %d Drucksachen, %d Plenarprotokolle\n",
				g.AnzahlVorgangspositionen, g.AnzahlAktivitaeten, g.AnzahlDrucksachen, g.AnzahlPlenarprotokolle)
		}
		fmt.Printf("─────────────────────────────────────────────────────────────────────────\n")
	}
}
