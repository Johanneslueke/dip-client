-- +goose Up
-- +goose StatementBegin

-- NOTE: Only adding FK constraints where 100% of references exist
-- Skipping vorgangsposition_mitberaten (2.68% missing) and 
-- plenarprotokoll_vorgangsbezug (4.69% missing) until older WPs are synced

-- 1. Add FK to vorgang_verlinkung.target_vorgang_id
CREATE TABLE vorgang_verlinkung_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    target_vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    verweisung TEXT NOT NULL,
    gesta TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (source_vorgang_id, target_vorgang_id)
);

INSERT INTO vorgang_verlinkung_new
SELECT * FROM vorgang_verlinkung;

DROP TABLE vorgang_verlinkung;
ALTER TABLE vorgang_verlinkung_new RENAME TO vorgang_verlinkung;

-- 2. Add FK to fundstelle_urheber.plenarprotokoll_id
CREATE TABLE fundstelle_urheber_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    urheber TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO fundstelle_urheber_new
SELECT * FROM fundstelle_urheber;

DROP TABLE fundstelle_urheber;
ALTER TABLE fundstelle_urheber_new RENAME TO fundstelle_urheber;

-- 3. Add FK to drucksache_vorgangsbezug.vorgang_id (100% valid references)
CREATE TABLE drucksache_vorgangsbezug_new (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (drucksache_id, vorgang_id, display_order)
);

INSERT INTO drucksache_vorgangsbezug_new
SELECT * FROM drucksache_vorgangsbezug;

DROP TABLE drucksache_vorgangsbezug;
ALTER TABLE drucksache_vorgangsbezug_new RENAME TO drucksache_vorgangsbezug;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Revert 3. drucksache_vorgangsbezug
CREATE TABLE drucksache_vorgangsbezug_old (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (drucksache_id, vorgang_id, display_order)
);

INSERT INTO drucksache_vorgangsbezug_old
SELECT * FROM drucksache_vorgangsbezug;

DROP TABLE drucksache_vorgangsbezug;
ALTER TABLE drucksache_vorgangsbezug_old RENAME TO drucksache_vorgangsbezug;

-- Revert 2. fundstelle_urheber
CREATE TABLE fundstelle_urheber_old (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT,
    urheber TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

INSERT INTO fundstelle_urheber_old
SELECT * FROM fundstelle_urheber;

DROP TABLE fundstelle_urheber;
ALTER TABLE fundstelle_urheber_old RENAME TO fundstelle_urheber;

-- Revert 1. vorgang_verlinkung
CREATE TABLE vorgang_verlinkung_old (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    target_vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    verweisung TEXT NOT NULL,
    gesta TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (source_vorgang_id, target_vorgang_id)
);

INSERT INTO vorgang_verlinkung_old
SELECT * FROM vorgang_verlinkung;

DROP TABLE vorgang_verlinkung;
ALTER TABLE vorgang_verlinkung_old RENAME TO vorgang_verlinkung;

-- +goose StatementEnd
