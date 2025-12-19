-- +goose Up
-- +goose StatementBegin
-- Add xml_url field to fundstelle in all relevant tables
-- This field was added in DIP API v1.4 for structured XML versions of documents
-- (currently only available for BT-Plenarprotokolle from WP 18 onwards)

-- Add xml_url to aktivitaet table
ALTER TABLE aktivitaet ADD COLUMN fundstelle_xml_url TEXT;

-- Add xml_url to drucksache table  
ALTER TABLE drucksache ADD COLUMN fundstelle_xml_url TEXT;

-- Add xml_url to plenarprotokoll table
ALTER TABLE plenarprotokoll ADD COLUMN fundstelle_xml_url TEXT;

-- Add xml_url to vorgangsposition table
ALTER TABLE vorgangsposition ADD COLUMN fundstelle_xml_url TEXT;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
-- SQLite doesn't support DROP COLUMN in older versions
-- So we would need to recreate tables to remove the column
-- For now, we'll leave the column in place on downgrade
-- (it will simply be NULL/ignored)
-- +goose StatementEnd
