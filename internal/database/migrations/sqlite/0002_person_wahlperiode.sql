-- +goose Up
-- Create junction table for person-wahlperiode many-to-many relationship
CREATE TABLE person_wahlperiode (
    person_id TEXT NOT NULL,
    wahlperiode_nummer INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (person_id, wahlperiode_nummer),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (wahlperiode_nummer) REFERENCES wahlperiode(nummer) ON DELETE CASCADE
);

CREATE INDEX idx_person_wahlperiode_person ON person_wahlperiode(person_id);
CREATE INDEX idx_person_wahlperiode_wahlperiode ON person_wahlperiode(wahlperiode_nummer);

-- Migrate existing data from person.wahlperiode to person_wahlperiode table
INSERT INTO person_wahlperiode (person_id, wahlperiode_nummer)
SELECT id, wahlperiode
FROM person
WHERE wahlperiode IS NOT NULL;

-- Remove the single wahlperiode column from person table
-- SQLite doesn't support DROP COLUMN directly, so we need to recreate the table
CREATE TABLE person_new (
    id TEXT PRIMARY KEY,
    vorname TEXT NOT NULL,
    nachname TEXT NOT NULL,
    namenszusatz TEXT,
    titel TEXT NOT NULL,
    typ TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    basisdatum TEXT,
    datum TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Copy data from old table
INSERT INTO person_new (id, vorname, nachname, namenszusatz, titel, typ, aktualisiert, basisdatum, datum, created_at, updated_at)
SELECT id, vorname, nachname, namenszusatz, titel, typ, aktualisiert, basisdatum, datum, created_at, updated_at
FROM person;

-- Drop old table and rename new one
DROP TABLE person;
ALTER TABLE person_new RENAME TO person;

-- Recreate indexes
CREATE INDEX idx_person_nachname ON person(nachname);
CREATE INDEX idx_person_aktualisiert ON person(aktualisiert);

-- +goose Down
-- Recreate person table with wahlperiode column
CREATE TABLE person_old (
    id TEXT PRIMARY KEY,
    vorname TEXT NOT NULL,
    nachname TEXT NOT NULL,
    namenszusatz TEXT,
    titel TEXT NOT NULL,
    typ TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    basisdatum TEXT,
    datum TEXT,
    wahlperiode INTEGER,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (wahlperiode) REFERENCES wahlperiode(nummer)
);

-- Copy data back, taking first wahlperiode from junction table
INSERT INTO person_old (id, vorname, nachname, namenszusatz, titel, typ, aktualisiert, basisdatum, datum, wahlperiode, created_at, updated_at)
SELECT 
    p.id, 
    p.vorname, 
    p.nachname, 
    p.namenszusatz, 
    p.titel, 
    p.typ, 
    p.aktualisiert, 
    p.basisdatum, 
    p.datum,
    (SELECT pw.wahlperiode_nummer FROM person_wahlperiode pw WHERE pw.person_id = p.id LIMIT 1),
    p.created_at,
    p.updated_at
FROM person p;

DROP TABLE person;
ALTER TABLE person_old RENAME TO person;

-- Recreate indexes
CREATE INDEX idx_person_nachname ON person(nachname);
CREATE INDEX idx_person_aktualisiert ON person(aktualisiert);
CREATE INDEX idx_person_wahlperiode ON person(wahlperiode);

-- Drop junction table
DROP TABLE person_wahlperiode;
