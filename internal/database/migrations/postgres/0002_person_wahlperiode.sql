-- +goose Up
-- Create junction table for person-wahlperiode many-to-many relationship
CREATE TABLE person_wahlperiode (
    person_id TEXT NOT NULL,
    wahlperiode_nummer INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
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

-- Remove the single wahlperiode column and foreign key
ALTER TABLE person DROP CONSTRAINT person_wahlperiode_fkey;
ALTER TABLE person DROP COLUMN wahlperiode;

-- +goose Down
-- Add wahlperiode column back
ALTER TABLE person ADD COLUMN wahlperiode INTEGER;
ALTER TABLE person ADD CONSTRAINT person_wahlperiode_fkey 
    FOREIGN KEY (wahlperiode) REFERENCES wahlperiode(nummer);

-- Migrate data back from junction table (take first wahlperiode)
UPDATE person p
SET wahlperiode = (
    SELECT pw.wahlperiode_nummer 
    FROM person_wahlperiode pw 
    WHERE pw.person_id = p.id 
    LIMIT 1
);

CREATE INDEX idx_person_wahlperiode ON person(wahlperiode);

-- Drop junction table
DROP TABLE person_wahlperiode;
