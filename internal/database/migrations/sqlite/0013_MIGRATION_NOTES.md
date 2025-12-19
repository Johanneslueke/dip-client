# Migration 0013: Add Fundstelle XML URL Support

## Overview

Added support for `xml_url` field in `Fundstelle` objects, introduced in DIP API v1.4.

## Changes

### Database Schema

Added `fundstelle_xml_url TEXT` column to tables with Fundstelle data:

- `aktivitaet`
- `drucksache`
- `plenarprotokoll`
- `vorgangsposition`

### SQLC Queries Updated

Updated `CREATE` queries in:

- `internal/database/queries/sqlite/aktivitaet.sql`
- `internal/database/queries/sqlite/drucksache.sql`
- `internal/database/queries/sqlite/plenarprotokoll.sql`
- `internal/database/queries/sqlite/vorgangsposition.sql`

### Sync Commands Updated

Updated sync commands to store `xml_url` field:

- `cmd/sync-aktivitaeten/main.go`
- `cmd/sync-drucksachen/main.go`
- `cmd/sync-plenarprotokolle/main.go`
- `cmd/sync-vorgangspositionen/main.go`

## API v1.4 Context

The `xml_url` field provides structured XML versions of documents. According to the API documentation:

> "Strukturierte XML-Version des Dokuments (aktuell nur für BT-Plenarprotokolle ab WP 18 verfügbar)"

This means XML URLs are currently only available for Bundestag Plenarprotokolle from Wahlperiode 18 onwards.

## Migration Application

```bash
# Apply migration
goose -dir internal/database/migrations/sqlite sqlite3 dip.clean.db up

# Regenerate sqlc bindings
cd internal/database && sqlc generate

# Rebuild sync commands
go build ./cmd/sync-aktivitaeten
go build ./cmd/sync-drucksachen
go build ./cmd/sync-plenarprotokolle
go build ./cmd/sync-vorgangspositionen
```

## Usage Example

Query plenarprotokolle with XML URLs:

```sql
SELECT
    id,
    dokumentnummer,
    wahlperiode,
    fundstelle_pdf_url,
    fundstelle_xml_url
FROM plenarprotokoll
WHERE fundstelle_xml_url IS NOT NULL
    AND wahlperiode >= 18
ORDER BY wahlperiode DESC, dokumentnummer DESC
LIMIT 10;
```

## Backward Compatibility

- The new column is nullable, so existing data remains valid
- Sync commands will populate the field going forward
- Historical records will have NULL for `fundstelle_xml_url`
- No data migration needed for existing records

## Testing

All tests pass after migration:

```bash
go test ./...
```

All sync commands compile successfully:

```bash
go build ./cmd/sync-*
```
