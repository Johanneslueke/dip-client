# MdB Stammdaten Import Tool

Imports biographical master data from `MDB_STAMMDATEN.XML` into the database.

## Overview

This tool parses the official Bundestag MdB Stammdaten XML file and imports it into the database tables created by migration `0010_mdb_stammdaten.sql`.

**Data Source**: MdB-Stammdaten/MDB_STAMMDATEN.XML  
**Database Tables**:

- `mdb_person` - Person master records
- `mdb_name` - Name records with history
- `mdb_biographical` - Biographical information
- `mdb_wahlperiode_membership` - Electoral period memberships
- `mdb_institution_membership` - Institution (fraktion/committee) memberships
- `mdb_stammdaten_version` - Import version tracking

## Prerequisites

1. **Migration Applied**: Run migration `0010_mdb_stammdaten.sql` first:

   ```bash
   sqlite3 dip.clean.db < internal/database/migrations/sqlite/0010_mdb_stammdaten.sql
   ```

2. **XML File Available**: Ensure `MDB_STAMMDATEN.XML` exists in `MdB-Stammdaten/` directory

3. **XML Validated** (recommended): Validate XML structure before import:
   ```bash
   bin/validate-xml-dtd MdB-Stammdaten/MDB_STAMMDATEN.XML
   ```

## Usage

### Basic Import

```bash
bin/import-mdb-stammdaten
```

### Custom Database Path

```bash
bin/import-mdb-stammdaten -db path/to/database.db
```

### Custom XML Path

```bash
bin/import-mdb-stammdaten -xml path/to/MDB_STAMMDATEN.XML
```

### Dry Run (Parse Only, No Database Changes)

```bash
bin/import-mdb-stammdaten -dry-run
```

### Verbose Mode (Show Progress)

```bash
bin/import-mdb-stammdaten -verbose
```

## Command-Line Options

| Option     | Default                             | Description                                          |
| ---------- | ----------------------------------- | ---------------------------------------------------- |
| `-db`      | `dip.clean.db`                      | Path to SQLite database file                         |
| `-xml`     | `MdB-Stammdaten/MDB_STAMMDATEN.XML` | Path to XML input file                               |
| `-dry-run` | `false`                             | Parse XML without database import (shows statistics) |
| `-verbose` | `false`                             | Display detailed progress (every 100 records)        |

## Import Process

The tool performs the following steps:

1. **Parse XML** - Loads and validates XML structure
2. **Begin Transaction** - All inserts in single transaction (atomic)
3. **Record Version** - Stores XML version in `mdb_stammdaten_version`
4. **Import Data** - Inserts records in correct order:
   - Person records (`mdb_person`)
   - Name records (`mdb_name`) - multiple per person
   - Biographical data (`mdb_biographical`) - one per person
   - Wahlperiode memberships (`mdb_wahlperiode_membership`) - multiple per person
   - Institution memberships (`mdb_institution_membership`) - nested under wahlperiode
5. **Commit Transaction** - Saves all changes atomically
6. **Display Statistics** - Shows summary of imported records

## Expected Results

For the current MDB_STAMMDATEN.XML (as of documentation date):

```
Total MdB records:          4,613
Persons inserted:           4,613
Names inserted:            ~4,900  (includes name changes)
Biographical inserted:      4,613
Wahlperioden inserted:    ~13,045  (multiple periods per person)
Institutions inserted:    ~16,653  (fraktion/committee memberships)
```

## Output Examples

### Successful Import

```
2024/01/15 10:30:00 Opening XML file: MdB-Stammdaten/MDB_STAMMDATEN.XML
2024/01/15 10:30:02 Parsing XML...
2024/01/15 10:30:05 Successfully parsed XML version 2024-01-01 with 4613 MdB records
2024/01/15 10:30:05 Opening database: dip.clean.db
2024/01/15 10:30:05 Starting import...
2024/01/15 10:30:45
=== Import Complete ===
  Total MdB records:          4613
  Persons inserted:           4613
  Names inserted:             4887
  Biographical inserted:      4613
  Wahlperioden inserted:     13045
  Institutions inserted:     16653
```

### Verbose Mode

```
2024/01/15 10:30:10 Progress: 100/4613 MdBs (95.2 records/sec)
2024/01/15 10:30:11 Progress: 200/4613 MdBs (97.8 records/sec)
2024/01/15 10:30:12 Progress: 300/4613 MdBs (98.4 records/sec)
...
```

### Dry Run Mode

```
2024/01/15 10:35:00 Successfully parsed XML version 2024-01-01 with 4613 MdB records
2024/01/15 10:35:00 Dry run mode - showing statistics only:
  Total MdB records:          4613
  Persons inserted:           4613
  Names inserted:             4887
  Biographical inserted:      4613
  Wahlperioden inserted:     13045
  Institutions inserted:     16653
```

## Error Handling

### Common Errors

**1. XML File Not Found**

```
Failed to open XML file: open MdB-Stammdaten/MDB_STAMMDATEN.XML: no such file or directory
```

**Solution**: Check file path, ensure XML file exists

**2. Database Not Found**

```
Failed to open database: unable to open database file
```

**Solution**: Check database path, ensure database exists

**3. Migration Not Applied**

```
ERROR importing MdB 11000001: insert person: no such table: mdb_person
```

**Solution**: Run migration first:

```bash
sqlite3 dip.clean.db < internal/database/migrations/sqlite/0010_mdb_stammdaten.sql
```

**4. Duplicate Import**

```
ERROR importing MdB 11000001: insert person: UNIQUE constraint failed: mdb_person.id
```

**Solution**: Data already imported. Either:

- Delete existing data: `DELETE FROM mdb_person;` (cascades to all tables)
- Use a fresh database
- Skip if data is already correct

**5. XML Parse Error**

```
Failed to parse XML: XML syntax error on line 123: unexpected EOF
```

**Solution**: Validate XML file first with `bin/validate-xml-dtd`

## Verification Queries

After import, verify data integrity:

### Check Record Counts

```sql
SELECT
    (SELECT COUNT(*) FROM mdb_person) as persons,
    (SELECT COUNT(*) FROM mdb_name) as names,
    (SELECT COUNT(*) FROM mdb_biographical) as biographical,
    (SELECT COUNT(*) FROM mdb_wahlperiode_membership) as wahlperioden,
    (SELECT COUNT(*) FROM mdb_institution_membership) as institutions;
```

### Check Import Version

```sql
SELECT * FROM mdb_stammdaten_version ORDER BY import_date DESC LIMIT 1;
```

### View Sample Records

```sql
SELECT
    mp.id,
    mn.nachname,
    mn.vorname,
    mb.partei_kurz,
    COUNT(DISTINCT mwm.wp) as anzahl_wahlperioden
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
LEFT JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
WHERE mn.historie_von IS NULL OR mn.historie_von = ''
GROUP BY mp.id, mn.nachname, mn.vorname, mb.partei_kurz
LIMIT 10;
```

### Check for Data Issues

```sql
-- Persons without names
SELECT COUNT(*) FROM mdb_person mp
WHERE NOT EXISTS (SELECT 1 FROM mdb_name WHERE mdb_id = mp.id);

-- Persons without biographical data
SELECT COUNT(*) FROM mdb_person mp
WHERE NOT EXISTS (SELECT 1 FROM mdb_biographical WHERE mdb_id = mp.id);

-- Persons without wahlperioden
SELECT COUNT(*) FROM mdb_person mp
WHERE NOT EXISTS (SELECT 1 FROM mdb_wahlperiode_membership WHERE mdb_id = mp.id);
```

## Performance

- **Import Time**: ~40-60 seconds for 4,613 MdBs (depends on hardware)
- **Records/Second**: ~90-120 MdBs/second
- **Transaction**: Single atomic transaction (all-or-nothing)
- **Memory**: ~100-200 MB peak during XML parsing

## Integration with Existing Data

After import, you can link MdB biographical data with existing activity data:

```sql
-- Find matching persons by name
SELECT
    p.id as dip_person_id,
    p.nachname as dip_nachname,
    p.vorname as dip_vorname,
    mp.id as mdb_id,
    mn.nachname as mdb_nachname,
    mn.vorname as mdb_vorname,
    mb.partei_kurz
FROM person p
JOIN mdb_name mn ON
    LOWER(p.nachname) = LOWER(mn.nachname) AND
    LOWER(p.vorname) = LOWER(mn.vorname)
JOIN mdb_person mp ON mn.mdb_id = mp.id
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
WHERE mn.historie_von IS NULL OR mn.historie_von = ''
LIMIT 10;
```

See migration documentation (`0010_mdb_stammdaten.md`) for more integration examples.

## Re-importing Data

To re-import (e.g., after XML update):

1. **Delete existing data**:

   ```sql
   DELETE FROM mdb_stammdaten_version;
   DELETE FROM mdb_person;  -- Cascades to all child tables
   ```

2. **Re-run import**:
   ```bash
   bin/import-mdb-stammdaten
   ```

Alternatively, use a transaction:

```sql
BEGIN TRANSACTION;
DELETE FROM mdb_stammdaten_version;
DELETE FROM mdb_person;
-- Then run import tool
-- If successful: COMMIT;
-- If failed: ROLLBACK;
```

## Troubleshooting

### Import Hangs

- Check available disk space
- Check database not locked by another process
- Use verbose mode to see progress

### Partial Import

- Tool uses single transaction - either all data imports or none
- Check error messages for specific failures
- Verify migration schema matches XML structure

### Slow Performance

- Ensure database on SSD (not networked drive)
- Close other applications accessing database
- Consider using WAL mode: `PRAGMA journal_mode=WAL;`

## Files

- **Source**: `cmd/import-mdb-stammdaten/main.go`
- **Binary**: `bin/import-mdb-stammdaten`
- **Input**: `MdB-Stammdaten/MDB_STAMMDATEN.XML`
- **Schema**: `internal/database/migrations/sqlite/0010_mdb_stammdaten.sql`
- **Documentation**: `internal/database/migrations/sqlite/0010_mdb_stammdaten.md`

## See Also

- XML Validator: `cmd/validate-xml-dtd/README.md`
- Migration Documentation: `internal/database/migrations/sqlite/0010_mdb_stammdaten.md`
- Quick Summary: `internal/database/migrations/sqlite/0010_MIGRATION_SUMMARY.md`
- Schema Diagram: `internal/database/migrations/sqlite/0010_SCHEMA_DIAGRAM.txt`
