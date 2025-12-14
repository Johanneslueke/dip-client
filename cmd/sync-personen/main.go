package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
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
	// Parse configuration
	config := utility.ParseSyncFlags("personen")

	// Create sync context (handles all setup)
	syncCtx, err := utility.NewSyncContext(config, 240)
	if err != nil {
		log.Fatal(err)
	}
	defer syncCtx.Close()

	// Load checkpoint if resuming
	datumEnd, _ := syncCtx.CheckpointMgr.LoadIfResume()

	// Parse end date if provided
	if config.End != "" {
		endTime, err := time.Parse("2006-01-02", config.End)
		if err != nil {
			log.Fatalf("Invalid end date format: %v", err)
		}
		date := types.Date{Time: endTime}
		datumEnd = &date
	}

	// Run sync loop
	err = syncCtx.SyncLoop(
		// Fetch batch function
		func(ctx context.Context, cursor *string) (*utility.BatchResponse, error) {
			params := &dipclient.GetPersonListParams{
				Cursor:    cursor,
				FDatumEnd: datumEnd,
			}

			// Use custom response handler to deal with wahlperiode array
			respBody, err := syncCtx.Client.GetPersonListRaw(ctx, params)
			if err != nil {
				return nil, err
			}

			var result struct {
				Cursor    string                       `json:"cursor"`
				Documents []PersonWithArrayWahlperiode `json:"documents"`
				NumFound  int32                        `json:"numFound"`
			}

			if err := json.Unmarshal(respBody, &result); err != nil {
				return nil, err
			}

			return &utility.BatchResponse{
				Documents:    result.Documents,
				Cursor:       result.Cursor,
				NumFound:     int(result.NumFound),
				DocumentsLen: len(result.Documents),
			}, nil
		},
		// Store item function
		storePerson,
		// Update checkpoint date function
		updatePersonDate,
		// Extract items function
		func(docs interface{}) []interface{} {
			persons := docs.([]PersonWithArrayWahlperiode)
			items := make([]interface{}, len(persons))
			for i, p := range persons {
				items[i] = p
			}
			return items
		},
	)

	if err != nil {
		log.Fatal(err)
	}

	// Finalize (handles all cleanup and logging)
	syncCtx.Finalize()
}

func updatePersonDate(ctx context.Context, q *db.Queries, item interface{}, checkpointMgr *utility.CheckpointManager) {
	person := item.(PersonWithArrayWahlperiode)
	if !person.Aktualisiert.IsZero() {
		checkpointMgr.UpdateDate(person.Aktualisiert)
	}
}

func storePerson(ctx context.Context, q *db.Queries, item interface{}, failedTracker *utility.FailedRecordsTracker) {
	person := item.(PersonWithArrayWahlperiode)

	// Ensure wahlperioden exist (use array if available)
	if person.WahlperiodeArray != nil {
		for _, wp := range *person.WahlperiodeArray {
			if _, err := q.GetOrCreateWahlperiode(ctx, int64(wp)); err != nil {
				failedTracker.RecordIfDBLocked(person.Id, "GetOrCreateWahlperiode", err)
				log.Printf("Warning: Failed to create wahlperiode for person %s: %v", person.Id, err)
				return
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
		failedTracker.RecordIfDBLocked(person.Id, "CreatePerson", err)
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
			failedTracker.RecordIfDBLocked(person.Id, "UpdatePerson", err)
			log.Printf("Warning: Failed to update person %s: %v", person.Id, err)
			return
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
			storePersonRole(ctx, q, person.Id, role, failedTracker)
		}
	}
}

func storePersonRole(ctx context.Context, q *db.Queries, personID string, role dipclient.PersonRole, failedTracker *utility.FailedRecordsTracker) {
	// Ensure bundesland exists if specified
	if role.Bundesland != nil {
		if _, err := q.GetOrCreateBundesland(ctx, string(*role.Bundesland)); err != nil {
			failedTracker.RecordIfDBLocked(personID, "GetOrCreateBundesland", err)
			log.Printf("Warning: Failed to create bundesland for person %s: %v", personID, err)
			return
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
		failedTracker.RecordIfDBLocked(personID, "CreatePersonRole", err)
		log.Printf("Warning: Failed to create person role for %s: %v", personID, err)
		return
	}

	// Store role wahlperioden if available
	if role.WahlperiodeNummer != nil {
		for _, wp := range *role.WahlperiodeNummer {
			if err := q.CreatePersonRoleWahlperiode(ctx, db.CreatePersonRoleWahlperiodeParams{
				PersonRoleID:      personRole.ID,
				WahlperiodeNummer: int64(wp),
			}); err != nil {
				failedTracker.RecordIfDBLocked(personID, "CreatePersonRoleWahlperiode", err)
				log.Printf("Warning: Failed to link role to wahlperiode %d: %v", wp, err)
			}
		}
	}
}
