-- +goose Up
-- Add foreign key constraint to link fundstelle_urheber.plenarprotokoll_id to plenarprotokoll table
-- SQLite doesn't support ALTER TABLE ADD CONSTRAINT, so we need to recreate the table

-- Create new table with the foreign key constraint
CREATE TABLE fundstelle_urheber_new (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    urheber TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Copy data from old table
INSERT INTO fundstelle_urheber_new (id, drucksache_id, plenarprotokoll_id, urheber, created_at)
SELECT id, drucksache_id, plenarprotokoll_id, urheber, created_at
FROM fundstelle_urheber;

-- Drop old table
DROP TABLE fundstelle_urheber;

-- Rename new table to original name
ALTER TABLE fundstelle_urheber_new RENAME TO fundstelle_urheber;

-- +goose Down
-- Remove foreign key constraint from fundstelle_urheber.plenarprotokoll_id
-- SQLite doesn't support ALTER TABLE DROP CONSTRAINT, so we need to recreate the table

-- Create table without the foreign key constraint on plenarprotokoll_id
CREATE TABLE fundstelle_urheber_old (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT,
    urheber TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Copy data from current table
INSERT INTO fundstelle_urheber_old (id, drucksache_id, plenarprotokoll_id, urheber, created_at)
SELECT id, drucksache_id, plenarprotokoll_id, urheber, created_at
FROM fundstelle_urheber;

-- Drop current table
DROP TABLE fundstelle_urheber;

-- Rename old table to original name
ALTER TABLE fundstelle_urheber_old RENAME TO fundstelle_urheber;
