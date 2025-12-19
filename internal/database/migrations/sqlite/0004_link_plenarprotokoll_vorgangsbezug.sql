-- +goose Up
-- Add foreign key constraint to link plenarprotokoll_vorgangsbezug.vorgang_id to vorgang table
-- SQLite doesn't support ALTER TABLE ADD CONSTRAINT, so we need to recreate the table

-- Create new table with the foreign key constraint
CREATE TABLE plenarprotokoll_vorgangsbezug_new (
    plenarprotokoll_id TEXT NOT NULL REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (plenarprotokoll_id, vorgang_id, display_order)
);

-- Copy data from old table
INSERT INTO plenarprotokoll_vorgangsbezug_new (plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order)
SELECT plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order
FROM plenarprotokoll_vorgangsbezug;

-- Drop old table
DROP TABLE plenarprotokoll_vorgangsbezug;

-- Rename new table to original name
ALTER TABLE plenarprotokoll_vorgangsbezug_new RENAME TO plenarprotokoll_vorgangsbezug;

-- +goose Down
-- Remove foreign key constraint from plenarprotokoll_vorgangsbezug.vorgang_id
-- SQLite doesn't support ALTER TABLE DROP CONSTRAINT, so we need to recreate the table

-- Create table without the foreign key constraint on vorgang_id
CREATE TABLE plenarprotokoll_vorgangsbezug_old (
    plenarprotokoll_id TEXT NOT NULL REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (plenarprotokoll_id, vorgang_id, display_order)
);

-- Copy data from current table
INSERT INTO plenarprotokoll_vorgangsbezug_old (plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order)
SELECT plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order
FROM plenarprotokoll_vorgangsbezug;

-- Drop current table
DROP TABLE plenarprotokoll_vorgangsbezug;

-- Rename old table to original name
ALTER TABLE plenarprotokoll_vorgangsbezug_old RENAME TO plenarprotokoll_vorgangsbezug;
