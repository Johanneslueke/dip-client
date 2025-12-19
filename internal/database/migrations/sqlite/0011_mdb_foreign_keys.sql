-- +goose Up
-- +goose StatementBegin
-- Add foreign key relationships for MdB Stammdaten tables
-- Links MdB biographical master data with DIP API activity data

-- Create junction table to link DIP person table with MdB person table
-- This allows matching persons between the two data sources
CREATE TABLE person_mdb_link (
    person_id TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    match_confidence TEXT NOT NULL CHECK(match_confidence IN ('exact', 'high', 'medium', 'low', 'manual')),
    match_method TEXT NOT NULL, -- 'name_exact', 'name_fuzzy', 'manual_verification', etc.
    verified_by TEXT,            -- User who verified manual matches
    verified_at TEXT,            -- Timestamp of manual verification
    notes TEXT,                  -- Additional notes about the match
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (person_id, mdb_id)
);

CREATE INDEX idx_person_mdb_link_person_id ON person_mdb_link(person_id);
CREATE INDEX idx_person_mdb_link_mdb_id ON person_mdb_link(mdb_id);
CREATE INDEX idx_person_mdb_link_confidence ON person_mdb_link(match_confidence);

-- Add foreign key from mdb_wahlperiode_membership to wahlperiode reference table
-- Note: SQLite doesn't support ALTER TABLE ADD CONSTRAINT for foreign keys
-- We need to recreate the table with the foreign key

-- First, rename the existing table
ALTER TABLE mdb_wahlperiode_membership RENAME TO mdb_wahlperiode_membership_old;

-- Recreate with foreign key to wahlperiode table
CREATE TABLE mdb_wahlperiode_membership (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    wp INTEGER NOT NULL REFERENCES wahlperiode(nummer),  -- Foreign key to wahlperiode
    mdbwp_von TEXT NOT NULL,
    mdbwp_bis TEXT,
    wkr_nummer TEXT,
    wkr_name TEXT,
    wkr_land TEXT,
    liste TEXT,
    mandatsart TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (mdb_id, wp)
);

-- Copy data from old table
INSERT INTO mdb_wahlperiode_membership 
    (id, mdb_id, wp, mdbwp_von, mdbwp_bis, wkr_nummer, wkr_name, wkr_land, liste, mandatsart, created_at, updated_at)
SELECT 
    id, mdb_id, wp, mdbwp_von, mdbwp_bis, wkr_nummer, wkr_name, wkr_land, liste, mandatsart, created_at, updated_at
FROM mdb_wahlperiode_membership_old;

-- Drop old table
DROP TABLE mdb_wahlperiode_membership_old;

-- Recreate indexes
CREATE INDEX idx_mdb_wahlperiode_membership_mdb_id ON mdb_wahlperiode_membership(mdb_id);
CREATE INDEX idx_mdb_wahlperiode_membership_wp ON mdb_wahlperiode_membership(wp);
CREATE INDEX idx_mdb_wahlperiode_membership_mandatsart ON mdb_wahlperiode_membership(mandatsart);
CREATE INDEX idx_mdb_wahlperiode_membership_wkr_land ON mdb_wahlperiode_membership(wkr_land);
CREATE INDEX idx_mdb_wahlperiode_membership_mdbwp_von ON mdb_wahlperiode_membership(mdbwp_von);

-- Ensure wahlperiode reference data exists for all periods in mdb_wahlperiode_membership
-- Insert missing wahlperiode numbers (1-21 covers all historical periods)
INSERT OR IGNORE INTO wahlperiode (nummer) 
SELECT DISTINCT wp FROM mdb_wahlperiode_membership WHERE wp NOT IN (SELECT nummer FROM wahlperiode);

-- Create view combining DIP person data with MdB biographical data
CREATE VIEW person_with_mdb_bio AS
SELECT 
    p.id as person_id,
    p.vorname as dip_vorname,
    p.nachname as dip_nachname,
    p.typ,
    p.aktualisiert,
    pml.mdb_id,
    pml.match_confidence,
    mn.nachname as mdb_nachname,
    mn.vorname as mdb_vorname,
    mn.anrede_titel,
    mn.akad_titel,
    mb.geburtsdatum,
    mb.geburtsort,
    mb.geschlecht,
    mb.partei_kurz,
    mb.beruf,
    mb.vita_kurz,
    (SELECT COUNT(DISTINCT wp) FROM mdb_wahlperiode_membership WHERE mdb_id = pml.mdb_id) as anzahl_wahlperioden,
    (SELECT MIN(mdbwp_von) FROM mdb_wahlperiode_membership WHERE mdb_id = pml.mdb_id) as erste_mitgliedschaft,
    (SELECT MAX(mdbwp_bis) FROM mdb_wahlperiode_membership WHERE mdb_id = pml.mdb_id) as letzte_mitgliedschaft
FROM person p
LEFT JOIN person_mdb_link pml ON p.id = pml.person_id
LEFT JOIN mdb_person mp ON pml.mdb_id = mp.id
LEFT JOIN mdb_name mn ON mp.id = mn.mdb_id AND (mn.historie_von IS NULL OR mn.historie_von = '')
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id;

-- Create view showing persons active in specific wahlperiode with biographical data
CREATE VIEW person_wahlperiode_with_bio AS
SELECT 
    p.id as person_id,
    p.nachname as dip_nachname,
    p.vorname as dip_vorname,
    pw.wahlperiode_nummer,
    pml.mdb_id,
    mn.nachname as mdb_nachname,
    mn.vorname as mdb_vorname,
    mb.partei_kurz,
    mb.geschlecht,
    mb.geburtsdatum,
    mwm.mandatsart,
    mwm.wkr_name,
    mwm.wkr_land,
    mwm.mdbwp_von,
    mwm.mdbwp_bis
FROM person p
JOIN person_wahlperiode pw ON p.id = pw.person_id
LEFT JOIN person_mdb_link pml ON p.id = pml.person_id
LEFT JOIN mdb_person mp ON pml.mdb_id = mp.id
LEFT JOIN mdb_name mn ON mp.id = mn.mdb_id AND (mn.historie_von IS NULL OR mn.historie_von = '')
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
LEFT JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id AND pw.wahlperiode_nummer = mwm.wp;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop views
DROP VIEW IF EXISTS person_wahlperiode_with_bio;
DROP VIEW IF EXISTS person_with_mdb_bio;

-- Restore mdb_wahlperiode_membership without foreign key
ALTER TABLE mdb_wahlperiode_membership RENAME TO mdb_wahlperiode_membership_new;

CREATE TABLE mdb_wahlperiode_membership (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    wp INTEGER NOT NULL,
    mdbwp_von TEXT NOT NULL,
    mdbwp_bis TEXT,
    wkr_nummer TEXT,
    wkr_name TEXT,
    wkr_land TEXT,
    liste TEXT,
    mandatsart TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (mdb_id, wp)
);

INSERT INTO mdb_wahlperiode_membership 
SELECT * FROM mdb_wahlperiode_membership_new;

DROP TABLE mdb_wahlperiode_membership_new;

CREATE INDEX idx_mdb_wahlperiode_membership_mdb_id ON mdb_wahlperiode_membership(mdb_id);
CREATE INDEX idx_mdb_wahlperiode_membership_wp ON mdb_wahlperiode_membership(wp);
CREATE INDEX idx_mdb_wahlperiode_membership_mandatsart ON mdb_wahlperiode_membership(mandatsart);
CREATE INDEX idx_mdb_wahlperiode_membership_wkr_land ON mdb_wahlperiode_membership(wkr_land);
CREATE INDEX idx_mdb_wahlperiode_membership_mdbwp_von ON mdb_wahlperiode_membership(mdbwp_von);

-- Drop junction table
DROP TABLE IF EXISTS person_mdb_link;

-- +goose StatementEnd
