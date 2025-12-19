# Link Person-MdB Tool

Links DIP `person` records with MdB biographical master data (`mdb_person`) using intelligent name matching.

## Quick Start

```bash
# Dry run to preview matches
./bin/link-person-mdb --dry-run --verbose

# Create high-confidence links only (exact + high)
./bin/link-person-mdb --min-confidence high

# Create all links including medium confidence
./bin/link-person-mdb --min-confidence medium

# Verbose mode for debugging
./bin/link-person-mdb --verbose --min-confidence high
```

## Overview

This tool populates the `person_mdb_link` junction table which connects:

- DIP persons (from activity data API)
- MdB biographical master data (from MDB_STAMMDATEN.XML)

Once linked, biographical data (gender, birth date, party affiliation, career summary) can be joined with activity data for enriched analysis.

## Matching Strategy

### 1. Exact Match (confidence: `exact`)

Perfect case-insensitive match of first name and last name.

**Example:**

- DIP: `Olaf Scholz` → MdB: `Olaf Scholz` ✅

### 2. High Confidence Match (confidence: `high`)

#### Name with Prefix

First name matches, last name matches with noble prefix variations.

**Examples:**

- DIP: `Karl-Theodor Guttenberg` → MdB: `Karl-Theodor zu Guttenberg` ✅
- DIP: `Annette Schavan` → MdB: `Annette von Schavan` ✅

#### Umlaut Variations

Names match after normalizing umlauts (ä→ae, ö→oe, ü→ue, ß→ss).

**Examples:**

- DIP: `Jürgen Trittin` → MdB: `Juergen Trittin` ✅
- DIP: `Bärbel Bas` → MdB: `Baerbel Bas` ✅

### 3. Medium Confidence Match (confidence: `medium`)

#### First Name Initial

Last name matches, first name matches by initial only.

**Example:**

- DIP: `T. Müller` → MdB: `Thomas Müller` ⚠️

#### Fuzzy Match

Other name variations detected by fuzzy matching algorithm.

## Multiple Matches

When a DIP person matches multiple MdB persons, the tool flags it for manual review and skips automatic linking.

**Example:**

- DIP: `Thomas Schmidt` might match 5+ MdB persons

These require human verification to determine the correct link.

## Results Summary

After running the tool on production data (2025-12-19):

```
=== Matching Statistics ===
  Total DIP persons:         5,811
  Total MdB persons:         4,597

  Exact matches:             4,610 (79.3%)
  High confidence:               4 (0.1%)
  Medium confidence:             0 (0.0%)
  Already linked:                0
  Multiple matches:             31 (requires manual review)
  No matches:                1,162 (20.0%)
  Skipped (below min):           4

  Total linked:              4,614 (79.4% coverage)
```

### Gender Distribution (Linked Persons)

- Male: 3,536 (76.6%)
- Female: 1,077 (23.3%)
- Diverse: 1 (0.0%)

### Party Distribution (Top 10 Linked Persons)

1. SPD: 1,424 (30.9%)
2. CDU: 1,415 (30.7%)
3. FDP: 488 (10.6%)
4. CSU: 287 (6.2%)
5. BÜNDNIS 90/DIE GRÜNEN: 275 (6.0%)
6. DIE LINKE.: 226 (4.9%)
7. AfD: 200 (4.3%)
8. PDS: 48 (1.0%)
9. GRÜNE: 48 (1.0%)
10. Plos: 27 (0.6%)

## Unlinked Persons (20%)

The 1,162 unlinked persons fall into these categories:

1. **Non-parliamentarians**: Staff, ministers without MdB status, international guests
2. **Name mismatches**: Married name vs maiden name, nicknames, missing data
3. **Temporary roles**: Short-term substitutes, interim members
4. **Data quality**: Missing or incomplete biographical data
5. **Historical records**: Persons before WP 1 or special cases

## Usage Options

```
--db string
    Path to SQLite database (default "dip.clean.db")

--dry-run
    Show matches without creating links
    Use this to preview results before committing

--min-confidence string
    Minimum confidence level to create links: exact, high, medium (default "high")
    - exact: Only perfect matches (safest)
    - high: Exact + name variations (recommended)
    - medium: All matches including fuzzy (review carefully)

--verbose
    Show detailed matching information
    Logs each match with person IDs, names, and match method
```

## Confidence Level Recommendations

- **Production use**: `--min-confidence high` (recommended)

  - 4,614 links with high precision
  - Minimal false positives
  - 79.4% coverage

- **Data exploration**: `--min-confidence medium`

  - Additional fuzzy matches
  - Review results carefully
  - May include false positives

- **Conservative**: `--min-confidence exact`
  - Only perfect name matches
  - 4,610 links (79.3% coverage)
  - Zero false positives

## Views and Analysis

After linking, use these views for enriched analysis:

### person_with_mdb_bio

Joins person with biographical data.

```sql
SELECT
    person_id,
    dip_nachname,
    dip_vorname,
    geschlecht,
    geburtsdatum,
    partei_kurz,
    anzahl_wahlperioden,
    beruf,
    vita_kurz
FROM person_with_mdb_bio
WHERE mdb_id IS NOT NULL
ORDER BY anzahl_wahlperioden DESC;
```

**Top Members by Wahlperioden:**

- Wolfgang Schäuble: 14 WPs
- Heinz Riesenhuber: 11 WPs
- Richard Stücklen: 11 WPs
- Gregor Gysi: 10 WPs
- Hermann Otto Solms: 10 WPs

### person_wahlperiode_with_bio

Joins person activity by Wahlperiode with biographical data.

```sql
SELECT
    wp_nummer,
    COUNT(DISTINCT person_id) as unique_persons,
    COUNT(CASE WHEN geschlecht = 'männlich' THEN 1 END) as male,
    COUNT(CASE WHEN geschlecht = 'weiblich' THEN 1 END) as female,
    COUNT(*) as total_activities
FROM person_wahlperiode_with_bio
WHERE wp_nummer = 21
GROUP BY wp_nummer;
```

### Example Analyses

#### Gender-based activity analysis

```sql
SELECT
    geschlecht,
    COUNT(DISTINCT person_id) as persons,
    COUNT(*) as activities,
    AVG(activity_count) as avg_activities_per_person
FROM person_with_mdb_bio
WHERE mdb_id IS NOT NULL
GROUP BY geschlecht;
```

#### Party-based participation

```sql
SELECT
    partei_kurz,
    COUNT(DISTINCT person_id) as members,
    AVG(anzahl_wahlperioden) as avg_terms
FROM person_with_mdb_bio
WHERE mdb_id IS NOT NULL AND partei_kurz IS NOT NULL
GROUP BY partei_kurz
ORDER BY members DESC;
```

#### Age distribution (current members)

```sql
SELECT
    CAST((julianday('now') - julianday(geburtsdatum))/365.25 AS INTEGER) as age,
    COUNT(*) as count
FROM person_with_mdb_bio
WHERE mdb_id IS NOT NULL
  AND geburtsdatum IS NOT NULL
  AND anzahl_wahlperioden > 0
GROUP BY age
ORDER BY age;
```

## Manual Verification

For the 31 multiple matches, create verification queries:

```sql
-- Show multiple matches for review
SELECT
    p.id as dip_id,
    p.vorname as dip_vorname,
    p.nachname as dip_nachname,
    GROUP_CONCAT(mp.id || ': ' || mn.vorname || ' ' || mn.nachname, '; ') as mdb_matches
FROM person p
JOIN person_mdb_link pml ON p.id = pml.person_id
JOIN mdb_person mp ON pml.mdb_id = mp.id
JOIN mdb_name mn ON mp.id = mn.mdb_id
WHERE (mn.historie_bis IS NULL OR mn.historie_bis = '')
GROUP BY p.id
HAVING COUNT(*) > 1;
```

Then manually verify and update:

```sql
-- Update confidence to 'manual' after verification
UPDATE person_mdb_link
SET
    match_confidence = 'manual',
    verified_by = 'your_name',
    verified_at = datetime('now'),
    notes = 'Verified correct match'
WHERE person_id = ? AND mdb_id = ?;

-- Delete incorrect link
DELETE FROM person_mdb_link
WHERE person_id = ? AND mdb_id = ?;
```

## Implementation Details

### Name Normalization

- Convert to lowercase
- Trim whitespace
- Remove noble prefixes: `von`, `zu`, `van`
- Remove suffixes: `jr.`, `sr.`
- Format: `lastname firstname`

### Fuzzy Matching Variations

1. First name only (for middle names)
2. First part of hyphenated names
3. Umlaut normalization (ä/ae, ö/oe, ü/ue, ß/ss)
4. First name initial + full last name

### Transaction Safety

All links created in a single transaction. If any error occurs, all changes are rolled back.

## Database Schema

### person_mdb_link

```sql
CREATE TABLE person_mdb_link (
    person_id TEXT NOT NULL,           -- DIP person.id
    mdb_id TEXT NOT NULL,              -- MdB person ID
    match_confidence TEXT NOT NULL,    -- exact, high, medium, low, manual
    match_method TEXT NOT NULL,        -- name_exact_match, name_with_prefix, etc.
    verified_by TEXT,                  -- Manual verification user
    verified_at TEXT,                  -- Manual verification timestamp
    notes TEXT,                        -- Additional notes
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    PRIMARY KEY (person_id, mdb_id),
    FOREIGN KEY (person_id) REFERENCES person(id) ON DELETE CASCADE,
    FOREIGN KEY (mdb_id) REFERENCES mdb_person(id) ON DELETE CASCADE
);
```

## Performance

- **Runtime**: ~1 second for 5,811 persons
- **Throughput**: ~5,000 matches/second
- **Memory**: Loads all MdB names into memory (~4,600 records)
- **Transaction**: Atomic bulk insert

## Future Improvements

1. **Historical name matching**: Match against `mdb_name` historical records
2. **Birth date verification**: Use birth dates to disambiguate multiple matches
3. **Constituency matching**: Compare electoral districts for verification
4. **Interactive review**: Web UI for manual verification of multiple matches
5. **Machine learning**: Train model on verified matches for better fuzzy matching
6. **Levenshtein distance**: More sophisticated string similarity
