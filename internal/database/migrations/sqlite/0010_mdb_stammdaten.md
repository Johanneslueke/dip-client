# MdB Stammdaten Database Schema

## Overview

This migration creates a normalized database schema for storing **MdB Stammdaten** (Member of Bundestag Master Data) from the official `MDB_STAMMDATEN.XML` file provided by the German Bundestag.

The schema is based on the `MDB_STAMMDATEN.DTD` structure and preserves all data elements while providing efficient querying capabilities.

## Data Source

- **File**: `MdB-Stammdaten/MDB_STAMMDATEN.XML`
- **Schema**: `MdB-Stammdaten/MDB_STAMMDATEN.DTD`
- **Source**: Deutscher Bundestag official data
- **Coverage**: All Bundestag members from Wahlperiode 1 (1949) to present
- **Update frequency**: Regular updates from Bundestag

## Table Structure

### 1. `mdb_stammdaten_version`

Tracks import versions and source files.

| Column        | Type    | Description                         |
| ------------- | ------- | ----------------------------------- |
| `id`          | INTEGER | Auto-increment primary key          |
| `version`     | TEXT    | Version number from XML `<VERSION>` |
| `import_date` | TEXT    | Timestamp of import                 |
| `source_file` | TEXT    | Path to source XML file             |
| `created_at`  | TEXT    | Record creation timestamp           |

**Purpose**: Track data lineage and enable version comparison.

---

### 2. `mdb_person`

Main entity table for Bundestag members (MdB = Mitglied des Bundestages).

| Column       | Type | Description                      |
| ------------ | ---- | -------------------------------- |
| `id`         | TEXT | 8-digit identifier (PRIMARY KEY) |
| `created_at` | TEXT | Record creation timestamp        |
| `updated_at` | TEXT | Last update timestamp            |

**XML Mapping**: `<MDB><ID>`

**Cardinality**: One record per unique parliamentarian across all wahlperioden.

**Example**: `11000001` → Manfred Abelein

---

### 3. `mdb_name`

Name components with history tracking. Supports multiple names per person (e.g., name changes through marriage).

| Column         | Type    | Description                                           |
| -------------- | ------- | ----------------------------------------------------- |
| `id`           | INTEGER | Auto-increment primary key                            |
| `mdb_id`       | TEXT    | Foreign key to `mdb_person.id`                        |
| `nachname`     | TEXT    | Last name (NOT NULL)                                  |
| `vorname`      | TEXT    | First name (NOT NULL)                                 |
| `ortszusatz`   | TEXT    | Location suffix for disambiguation, e.g., "(Berlin)"  |
| `adel`         | TEXT    | Nobility title (Freiherr, Baron, Graf, etc.)          |
| `praefix`      | TEXT    | Name prefix (von, van, de, etc.)                      |
| `anrede_titel` | TEXT    | Salutation title (Dr., Prof., etc.)                   |
| `akad_titel`   | TEXT    | Full academic title (Dr.-Ing., Prof. Dr. h. c., etc.) |
| `historie_von` | TEXT    | Valid from date (DD.MM.YYYY)                          |
| `historie_bis` | TEXT    | Valid until date (DD.MM.YYYY), NULL if current        |

**XML Mapping**: `<MDB><NAMEN><NAME>` (can occur multiple times)

**Cardinality**: One or more records per person (1:N relationship).

**History Tracking**:

- `historie_von`: Entry into Bundestag OR name change date
- `historie_bis`: NULL for current name, date for historical names

**Indexes**:

- `idx_mdb_name_mdb_id` - Person lookup
- `idx_mdb_name_nachname` - Surname search
- `idx_mdb_name_vorname` - First name search
- `idx_mdb_name_historie_von` - Temporal queries

**Example**:

```
MdB marries and changes name:
Record 1: nachname="Schmidt", historie_von="01.10.2005", historie_bis="15.06.2010"
Record 2: nachname="Müller", historie_von="15.06.2010", historie_bis=NULL
```

---

### 4. `mdb_biographical`

Biographical and personal data. All fields optional according to DTD.

| Column                          | Type    | Description                             |
| ------------------------------- | ------- | --------------------------------------- |
| `id`                            | INTEGER | Auto-increment primary key              |
| `mdb_id`                        | TEXT    | Foreign key to `mdb_person.id` (UNIQUE) |
| `geburtsdatum`                  | TEXT    | Birth date                              |
| `geburtsort`                    | TEXT    | Place of birth                          |
| `geburtsland`                   | TEXT    | Country of birth                        |
| `sterbedatum`                   | TEXT    | Death date                              |
| `geschlecht`                    | TEXT    | Gender (männlich, weiblich, etc.)       |
| `familienstand`                 | TEXT    | Marital status                          |
| `religion`                      | TEXT    | Religion                                |
| `beruf`                         | TEXT    | Profession                              |
| `partei_kurz`                   | TEXT    | Party affiliation (short form)          |
| `vita_kurz`                     | TEXT    | Short biography (only current WP)       |
| `veroeffentlichungspflichtiges` | TEXT    | Mandatory disclosures per §1 VR         |

**XML Mapping**: `<MDB><BIOGRAFISCHE_ANGABEN>`

**Cardinality**: Zero or one record per person (1:1 relationship).

**Mandatory Disclosures** (`veroeffentlichungspflichtiges`):
According to Verhaltensregeln (VR) §1:

1. Professional activity before Bundestag membership
2. Paid activities alongside mandate
3. Functions in companies
4. Functions in public law corporations
5. Functions in associations/foundations
6. Agreements on future activities/financial benefits
7. Shareholdings in companies
8. Donations

**Indexes**:

- `idx_mdb_biographical_mdb_id` - Person lookup
- `idx_mdb_biographical_partei_kurz` - Party filtering
- `idx_mdb_biographical_geschlecht` - Gender statistics
- `idx_mdb_biographical_geburtsdatum` - Age calculations

---

### 5. `mdb_wahlperiode_membership`

Records MdB membership in specific electoral periods (wahlperioden).

| Column       | Type    | Description                                          |
| ------------ | ------- | ---------------------------------------------------- |
| `id`         | INTEGER | Auto-increment primary key                           |
| `mdb_id`     | TEXT    | Foreign key to `mdb_person.id`                       |
| `wp`         | INTEGER | Wahlperiode number (1-21)                            |
| `mdbwp_von`  | TEXT    | Membership start date (DD.MM.YYYY)                   |
| `mdbwp_bis`  | TEXT    | Membership end date (DD.MM.YYYY), NULL if ongoing    |
| `wkr_nummer` | TEXT    | Electoral district number (1-3 digits)               |
| `wkr_name`   | TEXT    | Electoral district name                              |
| `wkr_land`   | TEXT    | Federal state abbreviation                           |
| `liste`      | TEXT    | List affiliation (normally: Bundesland abbreviation) |
| `mandatsart` | TEXT    | Type of mandate                                      |

**XML Mapping**: `<MDB><WAHLPERIODEN><WAHLPERIODE>` (can occur multiple times)

**Cardinality**: Multiple records per person (1:N relationship). One record per wahlperiode.

**Unique Constraint**: `(mdb_id, wp)` - One membership per person per wahlperiode.

**Mandatsart Values**:

- `Direktmandat` - Directly elected in electoral district
- `Landesliste` - Elected via federal state list
- `Volkskammer` - Elected by Volkskammer (GDR, historical)

**Liste Special Cases**:

- `*` - Saarland integration (historical)
- `**` - Berlin West amendment law (historical)
- `***` - Elected by Volkskammer (1990)

**Indexes**:

- `idx_mdb_wahlperiode_membership_mdb_id` - Person lookup
- `idx_mdb_wahlperiode_membership_wp` - Wahlperiode queries
- `idx_mdb_wahlperiode_membership_mandatsart` - Mandate type analysis
- `idx_mdb_wahlperiode_membership_wkr_land` - Federal state queries
- `idx_mdb_wahlperiode_membership_mdbwp_von` - Temporal queries

**Example**:

```
Angela Merkel:
WP14: wp=14, mdbwp_von="26.10.1998", mdbwp_bis="17.10.2002", wkr_name="Stralsund - Rügen - Grimmen"
WP15: wp=15, mdbwp_von="18.10.2002", mdbwp_bis="17.10.2005", wkr_name="Stralsund - Nordvorpommern - Rügen"
...
```

---

### 6. `mdb_institution_membership`

Records MdB membership in institutions (primarily fraktionen/parliamentary groups).

| Column                          | Type    | Description                                |
| ------------------------------- | ------- | ------------------------------------------ |
| `id`                            | INTEGER | Auto-increment primary key                 |
| `mdb_wahlperiode_membership_id` | INTEGER | FK to `mdb_wahlperiode_membership.id`      |
| `insart_lang`                   | TEXT    | Institution type (e.g., "Fraktion/Gruppe") |
| `ins_lang`                      | TEXT    | Institution name (e.g., "CDU/CSU")         |
| `mdbins_von`                    | TEXT    | Institution membership start (DD.MM.YYYY)  |
| `mdbins_bis`                    | TEXT    | Institution membership end (DD.MM.YYYY)    |
| `fkt_lang`                      | TEXT    | Function/role in institution               |
| `fktins_von`                    | TEXT    | Function start date (DD.MM.YYYY)           |
| `fktins_bis`                    | TEXT    | Function end date (DD.MM.YYYY)             |

**XML Mapping**: `<MDB><WAHLPERIODEN><WAHLPERIODE><INSTITUTIONEN><INSTITUTION>` (0 or more per wahlperiode)

**Cardinality**: Zero or more per wahlperiode membership (nested 1:N relationship).

**Data Completeness**:

- Historical wahlperioden: **Only fraktion data**
- Current wahlperiode: Full data (fraktionen, ausschüsse, etc.)

**Institution Types** (`insart_lang`):

- `Fraktion/Gruppe` - Parliamentary group/faction (most common)
- `Ausschuss` - Committee (only current WP)
- Other institutional affiliations

**Functions** (`fkt_lang`):

- `Ordentliches Mitglied` - Regular member
- `Vorsitzender` - Chairman/Chairwoman
- `Stellvertretender Vorsitzender` - Deputy chairman
- `Sprecher` - Spokesperson
- etc.

**Indexes**:

- `idx_mdb_institution_membership_wahlperiode_id` - Wahlperiode lookup
- `idx_mdb_institution_membership_insart_lang` - Institution type filtering
- `idx_mdb_institution_membership_ins_lang` - Institution name search
- `idx_mdb_institution_membership_mdbins_von` - Temporal queries

**Example**:

```
MdB switches fraktion mid-wahlperiode:
Record 1: ins_lang="SPD", mdbins_von="26.10.1998", mdbins_bis="15.03.2001"
Record 2: ins_lang="Fraktionslos", mdbins_von="16.03.2001", mdbins_bis="17.10.2002"
```

---

## Relationships

```
mdb_person (1)
    ├── mdb_name (1:N) - Name history
    ├── mdb_biographical (1:1) - Personal data
    └── mdb_wahlperiode_membership (1:N) - Electoral period memberships
            └── mdb_institution_membership (1:N) - Institution memberships per WP
```

**Cascading Deletes**:

- Delete `mdb_person` → cascades to all related tables
- Delete `mdb_wahlperiode_membership` → cascades to `mdb_institution_membership`

---

## Views

### 1. `mdb_current_members`

Lists currently active Bundestag members (latest wahlperiode, still active).

**Columns**:

- `mdb_id`, `nachname`, `vorname`, `ortszusatz`
- `anrede_titel`, `akad_titel`, `partei_kurz`, `geschlecht`
- `wahlperiode`, `mandatsart`, `wkr_name`, `wkr_land`

**Use Case**: "Show all current MdBs"

---

### 2. `mdb_full_names`

Complete name information with history, including formatted display names.

**Columns**:

- `mdb_id`, `name_id`, `display_name`, `full_nachname`
- All name components with history
- `is_current` flag (1 if current name, 0 if historical)

**Use Case**: "How should we address this person?" / "What was their name in 2005?"

---

### 3. `mdb_career_summary`

Statistical summary of each MdB's parliamentary career.

**Columns**:

- `mdb_id`, `nachname`, `vorname`, `partei_kurz`
- `anzahl_wahlperioden` - Number of wahlperioden served
- `erste_wahlperiode`, `letzte_wahlperiode` - First and last WP
- `mandat_beginn`, `mandat_ende` - Career start and end dates
- `anzahl_fraktionen` - Number of different fraktionen

**Use Case**: "Who served the longest?" / "28-year careers"

---

### 4. `mdb_fraktion_summary`

Fraktion (parliamentary group) composition by wahlperiode.

**Columns**:

- `fraktion`, `wahlperiode`, `anzahl_mitglieder`
- `direktmandate`, `listenmandate` - Breakdown by mandate type

**Use Case**: "Fraktion sizes over time" / "Coalition majorities"

---

## Data Examples

### Example 1: Single-Wahlperiode Member

```sql
-- Person
INSERT INTO mdb_person (id) VALUES ('11000001');

-- Name (single, no changes)
INSERT INTO mdb_name (mdb_id, nachname, vorname, anrede_titel, akad_titel, historie_von, historie_bis)
VALUES ('11000001', 'Abelein', 'Manfred', 'Dr.', 'Prof. Dr.', '19.10.1965', NULL);

-- Biographical
INSERT INTO mdb_biographical (mdb_id, geburtsdatum, geschlecht, partei_kurz, beruf)
VALUES ('11000001', '20.10.1930', 'männlich', 'CDU', 'Rechtsanwalt, Wirtschaftsprüfer');

-- Wahlperiode (WP5 only)
INSERT INTO mdb_wahlperiode_membership (mdb_id, wp, mdbwp_von, mdbwp_bis, wkr_nummer, mandatsart)
VALUES ('11000001', 5, '19.10.1965', '19.10.1969', '174', 'Direktmandat');

-- Institution (CDU/CSU fraktion)
INSERT INTO mdb_institution_membership (mdb_wahlperiode_membership_id, insart_lang, ins_lang)
VALUES (1, 'Fraktion/Gruppe', 'Fraktion der CDU/CSU');
```

### Example 2: Multi-Wahlperiode Career with Name Change

```sql
-- Person
INSERT INTO mdb_person (id) VALUES ('11002345');

-- Name 1 (maiden name, 1998-2005)
INSERT INTO mdb_name (mdb_id, nachname, vorname, historie_von, historie_bis)
VALUES ('11002345', 'Schmidt', 'Anna', '26.10.1998', '15.06.2005');

-- Name 2 (married name, 2005-present)
INSERT INTO mdb_name (mdb_id, nachname, vorname, historie_von, historie_bis)
VALUES ('11002345', 'Müller', 'Anna', '15.06.2005', NULL);

-- Three wahlperioden
INSERT INTO mdb_wahlperiode_membership (mdb_id, wp, mdbwp_von, mdbwp_bis)
VALUES
    ('11002345', 14, '26.10.1998', '17.10.2002'),
    ('11002345', 15, '18.10.2002', '17.10.2005'),
    ('11002345', 16, '18.10.2005', '26.10.2009');
```

---

## Query Examples

### Query 1: Find all current SPD members

```sql
SELECT
    mdb_id,
    nachname,
    vorname,
    wahlperiode,
    wkr_name
FROM mdb_current_members
WHERE partei_kurz = 'SPD'
ORDER BY nachname, vorname;
```

### Query 2: Career length analysis

```sql
SELECT
    anzahl_wahlperioden,
    COUNT(*) as anzahl_personen
FROM mdb_career_summary
GROUP BY anzahl_wahlperioden
ORDER BY anzahl_wahlperioden DESC;
```

### Query 3: Name changes during mandate

```sql
SELECT
    mp.id,
    mn1.nachname as alter_name,
    mn2.nachname as neuer_name,
    mn2.historie_von as aenderungsdatum
FROM mdb_person mp
JOIN mdb_name mn1 ON mp.id = mn1.mdb_id AND mn1.historie_bis IS NOT NULL
JOIN mdb_name mn2 ON mp.id = mn2.mdb_id
    AND mn2.historie_von = mn1.historie_bis
WHERE mn1.nachname != mn2.nachname;
```

### Query 4: Fraktion switchers

```sql
SELECT
    mp.id,
    mn.nachname,
    mwm.wp,
    GROUP_CONCAT(DISTINCT mim.ins_lang, ' → ') as fraktionen
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id AND mn.historie_bis IS NULL
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
JOIN mdb_institution_membership mim ON mwm.id = mim.mdb_wahlperiode_membership_id
WHERE mim.insart_lang LIKE '%Fraktion%'
GROUP BY mp.id, mn.nachname, mwm.wp
HAVING COUNT(DISTINCT mim.ins_lang) > 1;
```

### Query 5: Direktmandat vs Listenmandat distribution

```sql
SELECT
    wp,
    mandatsart,
    COUNT(*) as anzahl
FROM mdb_wahlperiode_membership
GROUP BY wp, mandatsart
ORDER BY wp DESC, anzahl DESC;
```

---

## Integration with Existing Schema

### Relationship to `person` table

The existing `person` table stores data from the DIP API (parliamentary activities).

The new `mdb_person` table stores biographical master data from MDB_STAMMDATEN.XML.

**Potential Linkage**:

- `person.id` (DIP API ID) ≠ `mdb_person.id` (MDB Stammdaten ID)
- Link via name matching: `person.nachname/vorname` ↔ `mdb_name.nachname/vorname`
- Link via wahlperiode: Both have wahlperiode associations

**Future Enhancement**:
Create junction table `person_mdb_link` to explicitly map DIP API persons to MDB persons.

### Complementary Data

| Table             | Source             | Content                                       |
| ----------------- | ------------------ | --------------------------------------------- |
| `person`          | DIP API            | Activity-based person records                 |
| `mdb_person`      | MDB_STAMMDATEN.XML | Biographical master data                      |
| **Combined View** | Both               | Complete person profile with bio + activities |

---

## Migration Application

### Apply Migration

```bash
# Using goose
goose -dir internal/database/migrations/sqlite sqlite3 dip.clean.db up

# Or manually
sqlite3 dip.clean.db < internal/database/migrations/sqlite/0010_mdb_stammdaten.sql
```

### Rollback Migration

```bash
goose -dir internal/database/migrations/sqlite sqlite3 dip.clean.db down
```

---

## Data Import Strategy

### Step 1: Parse XML

Use the `validate-xml-dtd` tool to validate XML structure first:

```bash
./bin/validate-xml-dtd -xml MdB-Stammdaten/MDB_STAMMDATEN.XML -v -s
```

### Step 2: Create Import Tool

Create `cmd/import-mdb-stammdaten/main.go`:

- Parse `MDB_STAMMDATEN.XML`
- Extract all `<MDB>` elements
- Insert into database tables in order:
  1. `mdb_stammdaten_version`
  2. `mdb_person`
  3. `mdb_name` (multiple per person)
  4. `mdb_biographical`
  5. `mdb_wahlperiode_membership` (multiple per person)
  6. `mdb_institution_membership` (multiple per wahlperiode)

### Step 3: Validation Queries

After import, verify data integrity:

```sql
-- Check person count
SELECT COUNT(*) FROM mdb_person;  -- Should be ~4,613

-- Check name records
SELECT COUNT(*) FROM mdb_name;    -- Should be ~4,900

-- Check wahlperiode memberships
SELECT COUNT(*) FROM mdb_wahlperiode_membership;  -- Should be ~13,045

-- Check institution memberships
SELECT COUNT(*) FROM mdb_institution_membership;  -- Should be ~16,653

-- Verify referential integrity
SELECT COUNT(*) FROM mdb_name WHERE mdb_id NOT IN (SELECT id FROM mdb_person);
-- Should be 0

-- Check for orphaned records
SELECT COUNT(*) FROM mdb_wahlperiode_membership
WHERE mdb_id NOT IN (SELECT id FROM mdb_person);
-- Should be 0
```

---

## Performance Considerations

### Indexes

All critical foreign keys and query columns are indexed:

- Person ID lookups (fast joins)
- Name searches (nachname, vorname)
- Wahlperiode filtering
- Party/fraktion filtering
- Temporal queries (historie_von, mdbwp_von dates)

### Query Optimization

**DO**:

- Use views for common queries (`mdb_current_members`, etc.)
- Filter by indexed columns (wp, partei_kurz, nachname)
- Use EXISTS for existence checks

**DON'T**:

- Full table scans without WHERE clauses
- LIKE queries without leading wildcard optimization
- Unnecessary JOINs (use views)

### Expected Performance

On typical hardware with 4,613 MdB records:

- Single person lookup: <1ms
- Current members view: <10ms
- Career summary (all persons): <50ms
- Fraktion composition (all WPs): <30ms
- Complex multi-table JOIN: <100ms

---

## Maintenance

### Regular Tasks

1. **Update from Bundestag** (monthly):

   ```bash
   # Download latest XML
   wget https://www.bundestag.de/resource/blob/.../MDB_STAMMDATEN.XML

   # Validate
   ./bin/validate-xml-dtd -xml MDB_STAMMDATEN.XML -s

   # Import
   ./bin/import-mdb-stammdaten -xml MDB_STAMMDATEN.XML -db dip.clean.db
   ```

2. **Check data quality**:

   ```sql
   -- Missing biographical data
   SELECT COUNT(*) FROM mdb_person mp
   LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
   WHERE mb.mdb_id IS NULL;

   -- Names without history dates
   SELECT COUNT(*) FROM mdb_name WHERE historie_von IS NULL;

   -- Active memberships without end date
   SELECT COUNT(*) FROM mdb_wahlperiode_membership
   WHERE mdbwp_bis IS NULL;
   ```

3. **Vacuum and optimize** (quarterly):
   ```bash
   sqlite3 dip.clean.db "VACUUM;"
   sqlite3 dip.clean.db "ANALYZE;"
   ```

---

## Future Enhancements

### Phase 1: Basic Integration

- [ ] Create import tool (`cmd/import-mdb-stammdaten`)
- [ ] Link to existing `person` table
- [ ] Add person photos/portraits

### Phase 2: Extended Data

- [ ] Parse `veroeffentlichungspflichtiges` into structured fields
- [ ] Add electoral district (wahlkreis) master data table
- [ ] Historical fraktion name normalization

### Phase 3: Advanced Features

- [ ] Person timeline view (all events chronologically)
- [ ] Family relationship tracking (based on surnames)
- [ ] Career path analysis (committee assignments, leadership roles)
- [ ] Geographic visualization (wahlkreise on map)

---

## References

- **DTD Definition**: `MdB-Stammdaten/MDB_STAMMDATEN.DTD`
- **Data Source**: `MdB-Stammdaten/MDB_STAMMDATEN.XML`
- **Validator**: `cmd/validate-xml-dtd/`
- **Migration**: `internal/database/migrations/sqlite/0010_mdb_stammdaten.sql`
- **Official Documentation**: https://www.bundestag.de/services/opendata

---

**Migration Version**: 0010
**Created**: December 19, 2025  
**Database**: SQLite 3  
**Schema Version**: Based on MDB_STAMMDATEN.DTD (2025)
