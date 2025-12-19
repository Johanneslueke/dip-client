# MdB Stammdaten Foreign Key Relationships

## Overview

Migration `0011_mdb_foreign_keys.sql` adds proper foreign key relationships between the MdB Stammdaten tables and existing DIP tables, enabling referential integrity and data integration.

## Foreign Key Relationships Added

### 1. mdb_wahlperiode_membership → wahlperiode

**Type**: Many-to-One  
**Purpose**: Links MdB wahlperiode memberships to the reference wahlperiode table

```sql
mdb_wahlperiode_membership.wp → wahlperiode.nummer
```

**Benefits**:

- Ensures all wahlperiode numbers are valid
- Enables joins with other wahlperiode-related data
- Maintains referential integrity

### 2. person_mdb_link (Junction Table)

**Type**: Many-to-Many  
**Purpose**: Links DIP person records with MdB biographical master data

```sql
person_mdb_link.person_id → person.id
person_mdb_link.mdb_id → mdb_person.id
```

**Features**:

- **Match Confidence**: Tracks quality of matches (exact, high, medium, low, manual)
- **Match Method**: Records how the match was determined
- **Verification**: Optional manual verification tracking
- **Cascading Deletes**: Maintains integrity when persons are deleted

## Junction Table Structure

```sql
CREATE TABLE person_mdb_link (
    person_id TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    match_confidence TEXT NOT NULL CHECK(match_confidence IN ('exact', 'high', 'medium', 'low', 'manual')),
    match_method TEXT NOT NULL,
    verified_by TEXT,
    verified_at TEXT,
    notes TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (person_id, mdb_id)
);
```

## Views Created

### person_with_mdb_bio

Combines DIP person data with MdB biographical information.

**Columns**:

- DIP data: person_id, dip_vorname, dip_nachname, typ, aktualisiert
- MdB link: mdb_id, match_confidence
- MdB biographical: geburtsdatum, geburtsort, geschlecht, partei_kurz, beruf, vita_kurz
- Career summary: anzahl_wahlperioden, erste_mitgliedschaft, letzte_mitgliedschaft

**Example Query**:

```sql
SELECT person_id, dip_nachname, mdb_nachname, geschlecht, partei_kurz, anzahl_wahlperioden
FROM person_with_mdb_bio
WHERE match_confidence IN ('exact', 'high')
LIMIT 10;
```

### person_wahlperiode_with_bio

Shows persons active in specific wahlperioden with biographical data.

**Columns**:

- DIP data: person_id, dip_vorname, dip_nachname, wahlperiode_nummer
- MdB biographical: partei_kurz, geschlecht, geburtsdatum
- Electoral data: mandatsart, wkr_name, wkr_land, mdbwp_von, mdbwp_bis

**Example Query**:

```sql
SELECT
    wahlperiode_nummer,
    dip_nachname,
    partei_kurz,
    mandatsart,
    wkr_name
FROM person_wahlperiode_with_bio
WHERE wahlperiode_nummer = 20
ORDER BY dip_nachname
LIMIT 10;
```

## Relationship Diagram

```
┌──────────────┐
│  wahlperiode │
│  (reference) │
└──────┬───────┘
       │
       │ FK: wp → nummer
       │
┌──────▼────────────────────────┐
│ mdb_wahlperiode_membership    │
│                               │
│  • mdb_id                     │
│  • wp (FK)                    │
│  • mandatsart, wkr_name, etc. │
└──────┬────────────────────────┘
       │
       │ FK: mdb_id → id
       │
┌──────▼───────┐         ┌────────────────┐
│  mdb_person  │◄────────┤ person_mdb_link│
│              │         │                │
│  • id (PK)   │         │ • person_id    │
└──────┬───────┘         │ • mdb_id       │
       │                 │ • confidence   │
       │                 │ • method       │
       │                 └───────┬────────┘
       │                         │
       │                         │ FK: person_id → id
       │                         │
       ├──────────────┐   ┌──────▼───────┐
       │              │   │    person    │
       │              │   │   (DIP API)  │
   ┌───▼──────┐  ┌───▼──────────────┐   │
   │ mdb_name │  │ mdb_biographical │   │  • id (PK)     │
   │          │  │                  │   │  • vorname     │
   │ • names  │  │ • geburtsdatum   │   │  • nachname    │
   │ • history│  │ • geschlecht     │   │  • typ         │
   └──────────┘  │ • partei_kurz    │   └────────────────┘
                 │ • beruf          │
                 └──────────────────┘
```

## Usage Examples

### 1. Find DIP persons with biographical data

```sql
SELECT
    p.id,
    p.nachname,
    p.vorname,
    mb.geschlecht,
    mb.geburtsdatum,
    mb.partei_kurz
FROM person p
JOIN person_mdb_link pml ON p.id = pml.person_id
JOIN mdb_biographical mb ON pml.mdb_id = mb.mdb_id
WHERE pml.match_confidence IN ('exact', 'high')
LIMIT 10;
```

### 2. Analyze persons by wahlperiode with gender breakdown

```sql
SELECT
    w.nummer as wahlperiode,
    COUNT(*) as total_members,
    COUNT(CASE WHEN mb.geschlecht = 'männlich' THEN 1 END) as maennlich,
    COUNT(CASE WHEN mb.geschlecht = 'weiblich' THEN 1 END) as weiblich
FROM wahlperiode w
JOIN mdb_wahlperiode_membership mwm ON w.nummer = mwm.wp
LEFT JOIN mdb_biographical mb ON mwm.mdb_id = mb.mdb_id
GROUP BY w.nummer
ORDER BY w.nummer;
```

### 3. Find persons with activities in specific wahlperiode

```sql
SELECT DISTINCT
    p.id,
    p.nachname,
    p.vorname,
    mb.partei_kurz,
    COUNT(DISTINCT a.id) as anzahl_aktivitaeten
FROM person p
JOIN person_wahlperiode pw ON p.id = pw.person_id
LEFT JOIN person_mdb_link pml ON p.id = pml.person_id
LEFT JOIN mdb_biographical mb ON pml.mdb_id = mb.mdb_id
LEFT JOIN aktivitaet a ON p.id = a.person_id
WHERE pw.wahlperiode_nummer = 20
GROUP BY p.id, p.nachname, p.vorname, mb.partei_kurz
HAVING anzahl_aktivitaeten > 0
ORDER BY anzahl_aktivitaeten DESC
LIMIT 20;
```

### 4. Verify wahlperiode foreign key integrity

```sql
-- All should reference valid wahlperioden
SELECT
    mwm.wp,
    COUNT(*) as member_count,
    w.start_year,
    w.end_year
FROM mdb_wahlperiode_membership mwm
JOIN wahlperiode w ON mwm.wp = w.nummer
GROUP BY mwm.wp, w.start_year, w.end_year
ORDER BY mwm.wp;
```

## Match Confidence Levels

| Level    | Description                                 | Use Case                                       |
| -------- | ------------------------------------------- | ---------------------------------------------- |
| `exact`  | Perfect name match (vorname + nachname)     | Automatic matching with high certainty         |
| `high`   | Very likely match (name variants, umlauts)  | Automatic with manual verification recommended |
| `medium` | Possible match (partial name, maiden names) | Requires manual verification                   |
| `low`    | Uncertain match (common names, ambiguous)   | Manual verification required                   |
| `manual` | Manually verified by user                   | Confirmed by human review                      |

## Populating person_mdb_link

To create links between DIP persons and MdB persons, you'll need a matching tool. Example:

```sql
-- Exact name matches (case-insensitive)
INSERT INTO person_mdb_link (person_id, mdb_id, match_confidence, match_method)
SELECT DISTINCT
    p.id,
    mp.id,
    'exact',
    'name_exact_match'
FROM person p
JOIN mdb_name mn ON
    LOWER(p.nachname) = LOWER(mn.nachname) AND
    LOWER(p.vorname) = LOWER(mn.vorname)
JOIN mdb_person mp ON mn.mdb_id = mp.id
WHERE (mn.historie_von IS NULL OR mn.historie_von = '')
  AND NOT EXISTS (
      SELECT 1 FROM person_mdb_link
      WHERE person_id = p.id AND mdb_id = mp.id
  );
```

## Migration Details

**File**: `internal/database/migrations/sqlite/0011_mdb_foreign_keys.sql`

**Changes**:

1. Created `person_mdb_link` junction table
2. Recreated `mdb_wahlperiode_membership` with FK to `wahlperiode.nummer`
3. Ensured all referenced wahlperiode numbers exist in reference table
4. Created `person_with_mdb_bio` view
5. Created `person_wahlperiode_with_bio` view

**Verified**:

- ✅ All 13,045 mdb_wahlperiode_membership records reference valid wahlperioden
- ✅ Wahlperiode 1-21 all exist in reference table
- ✅ Cascading deletes configured correctly
- ✅ Indexes created for join performance

## Benefits

1. **Referential Integrity**: Database enforces valid relationships
2. **Data Quality**: Invalid wahlperiode numbers prevented
3. **Performance**: Indexed foreign keys optimize joins
4. **Flexibility**: Junction table supports many-to-many relationships
5. **Traceability**: Match confidence and method tracking
6. **Integration**: Easy to combine DIP activities with MdB biographical data

## Next Steps

1. Create tool to populate `person_mdb_link` with automatic matches
2. Build UI for manual verification of medium/low confidence matches
3. Analyze coverage: how many DIP persons have biographical data
4. Use biographical data to enrich activity analysis (age, gender, experience)
