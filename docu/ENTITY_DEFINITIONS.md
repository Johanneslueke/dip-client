# DIP Entity Definitions: Vorgang, Drucksache, and Aktivität

## Overview

The German Bundestag DIP (Dokumentations- und Informationssystem für Parlamentsmaterialien) API organizes parliamentary data into three core entity types that work together in a hierarchical relationship:

```
VORGANG (Procedural Container)
    ├─ DRUCKSACHE (Formal Document)
    │   └─ DrucksacheText (Full text content)
    └─ AKTIVITÄT (Individual Person Actions)
```

---

## 1. VORGANG (Parliamentary Procedure/Process)

### Definition

A **Vorgang** is the **procedural container** for a parliamentary initiative. It represents the entire lifecycle of a legislative or oversight process from initiation to conclusion.

### Key Characteristics

**What it describes:**

- The **procedural journey** of a parliamentary initiative
- The **legislative or oversight process** itself, not the documents or people
- A **unique ID** that connects all related activities and documents

**Attributes:**

- `id`: Unique identifier (e.g., "329238")
- `titel`: Title of the procedure
- `vorgangstyp`: Type of procedure
  - Examples: "Kleine Anfrage", "Gesetzentwurf", "Antrag", "Große Anfrage"
- `datum`: Date of the procedure
- `wahlperiode`: Electoral period (7-21)
- `abstract`: Summary of the procedure's content
- `beratungsstand`: Current status/stage of deliberation
- `initiative`: Array of initiating fraktionen
- `sachgebiet`: Subject areas
- `gesta`: Official procedure number

**What it can link to:**

- **Multiple Drucksachen** (via `drucksache_vorgangsbezug`)
- **Multiple Aktivitäten** (via `aktivitaet_vorgangsbezug`)
- **Multiple Vorgangspositionen** (procedural steps)
- **Other Vorgänge** (via `vorgang_verlinkung` for related procedures)
- **Verkündung** (publication in official gazette)
- **Inkrafttreten** (coming into force)

### Example

```sql
id: 329238
titel: Gewährung von Geld- und Sachleistungen an Afghanen in Pakistan
vorgangstyp: Kleine Anfrage
datum: 2025-12-12
wahlperiode: 21
```

**Real-world meaning:** This Vorgang represents the parliamentary oversight procedure where parliamentarians formally asked the government about aid to Afghans in Pakistan. The Vorgang tracks this question through its entire lifecycle.

### Historical Coverage

- **Database has:** WP7-21 (1972-2025) = **50 years**
- **Total records:** 414,296 vorgänge
- **Dominant types:** 60% are questions (Kleine/Große Anfragen)

---

## 2. DRUCKSACHE (Printed Document/Publication)

### Definition

A **Drucksache** is a **formal parliamentary document** with an official document number. It's the tangible, published artifact that gets distributed to parliament members and the public.

### Key Characteristics

**What it describes:**

- **Officially numbered documents** submitted to or produced by parliament
- **Formal written content** with specific formatting and publication requirements
- **Authored documents** that can have multiple co-authors

**Attributes:**

- `id`: Unique identifier (e.g., "283846")
- `dokumentnummer`: Official document number (e.g., "21/3258")
  - Format: `{wahlperiode}/{sequential_number}`
- `titel`: Document title (actual question/proposal content)
- `drucksachetyp`: Type of printed document
  - Examples: "Kleine Anfrage", "Antwort", "Gesetzentwurf", "Antrag"
- `datum`: Publication date
- `wahlperiode`: Electoral period
- `autoren_anzahl`: Number of authors/co-signers
- `vorgangsbezug_anzahl`: Number of linked procedures
- `fundstelle_*`: Publication details (PDF URL, page numbers, etc.)

**What it can link to:**

- **Authors** (via `drucksache_autor_anzeige` → `person`)
- **Initiating entities** (via `drucksache_urheber` → `urheber`)
  - Fraktionen (e.g., "Fraktion der AfD")
  - Government entities (e.g., "Bundesregierung")
- **One or more Vorgänge** (via `drucksache_vorgangsbezug`)
- **Ressorts** (government ministries involved)
- **Full text** (via `drucksache_text`)

### Example

```sql
id: 283846
dokumentnummer: 21/3258
drucksachetyp: Kleine Anfrage
titel: Gewährung von Geld- und Sachleistungen an Afghanen in Pakistan
datum: 2025-12-12
wahlperiode: 21
autoren_anzahl: 17
vorgangsbezug_anzahl: 1
```

**Real-world meaning:** This is the actual printed document with number 21/3258 containing the formal written question. It has 17 co-authors (AfD members) and is linked to one Vorgang (the procedural container).

### Historical Coverage

- **Database has:** WP7-21 (1972-2025) = **50 years**
- **Total records:** 24,507 question drucksachen
- **Key insight:** One Vorgang can have multiple Drucksachen (e.g., question + answer)

---

## 3. AKTIVITÄT (Individual Action/Participation)

### Definition

An **Aktivität** represents an **individual person's participation** in a parliamentary document or procedure. It tracks WHO did WHAT in the parliamentary process.

### Key Characteristics

**What it describes:**

- **Individual participation** by specific parliamentarians
- **Person-level tracking** of actions (asking, signing, speaking, etc.)
- **Multiplicity**: One Drucksache with 17 authors = 17 Aktivität records

**Attributes:**

- `id`: Unique identifier (e.g., "1748548")
- `titel`: **Person's name** (e.g., "Jochen Haug, MdB, AfD")
  - Format: `{Name}, MdB, {Fraktion}`
  - MdB = "Mitglied des Bundestages" (Member of Parliament)
- `aktivitaetsart`: Type of activity
  - Examples: "Kleine Anfrage", "Antrag", "Rede", "Frage", "Antwort"
- `datum`: Date of activity
- `wahlperiode`: Electoral period
- `vorgangsbezug_anzahl`: Number of linked procedures
- `fundstelle_dokumentnummer`: Links to the document (e.g., "21/3258")
- `fundstelle_dokumentart`: Whether it's a Drucksache or Plenarprotokoll

**What it can link to:**

- **One or more Vorgänge** (via `aktivitaet_vorgangsbezug`)
- **The underlying Drucksache or Plenarprotokoll** (via fundstelle)
- **Deskriptors** (subject keywords)

### Example

```sql
id: 1748548
titel: Jochen Haug, MdB, AfD
aktivitaetsart: Kleine Anfrage
datum: 2025-12-12
wahlperiode: 21
vorgangsbezug_anzahl: 1
fundstelle_dokumentnummer: 21/3258
```

**Real-world meaning:** Jochen Haug (AfD member) signed/co-authored the Kleine Anfrage document 21/3258. Each of the 17 co-authors gets their own Aktivität record.

### Historical Coverage

- **Database has:** WP18-21 (2014-2025) = **Only 12 years!**
- **Total records:** 648,329 aktivitäten
- **Critical limitation:** Cannot track individual participation before 2014

---

## Hierarchical Relationships

### Example: One Kleine Anfrage Question

```
VORGANG #329238: "Gewährung von Geld- und Sachleistungen..."
├─ Type: Kleine Anfrage
├─ Status: Procedural container
├─ Initiated by: Fraktion der AfD
│
├── DRUCKSACHE #283846 (Document number 21/3258)
│   ├─ Type: Kleine Anfrage
│   ├─ Title: [Full question text]
│   ├─ Authors: 17 parliamentarians
│   ├─ Published: 2025-12-12
│   └─ Links to: Vorgang #329238
│
└── AKTIVITÄTEN (17 individual participation records)
    ├─ #1748532: Steffen Janich, MdB, AfD
    ├─ #1748533: Markus Matzerath, MdB, AfD
    ├─ #1748534: Stefan Keuter, MdB, AfD
    ├─ #1748535: Dr. Christian Wirth, MdB, AfD
    ├─ #1748536: Dr. Rainer Rothfuß, MdB, AfD
    ├─ ... (12 more co-authors)
    └─ All link to: Vorgang #329238 and Drucksache 21/3258
```

### Multiplicity Patterns

**One-to-Many:**

- 1 Vorgang → Many Drucksachen
  - Example: Question (Kleine Anfrage) + Answer (Antwort) = 2 Drucksachen, 1 Vorgang

**Many-to-One:**

- Many Aktivitäten → 1 Drucksache
  - Example: 17 co-authors = 17 Aktivität records for 1 Drucksache

**Many-to-Many:**

- Many Aktivitäten → Many Vorgänge (people can participate in multiple procedures)
- Many Drucksachen → Many Vorgänge (documents can relate to multiple procedures)

---

## What Each Entity Can Describe

### VORGANG Capabilities

✅ **Can describe:**

- Legislative processes (Gesetzentwurf → law passage)
- Oversight procedures (Kleine Anfrage → government response)
- Parliamentary initiatives (Anträge)
- Procedural status and timeline
- Relationships between procedures
- Subject areas and policy domains
- Initiating fraktionen (group level)

❌ **Cannot describe:**

- Individual person participation (need Aktivität)
- Actual document text (need Drucksache + DrucksacheText)
- Exact wording of questions/proposals (need Drucksache)

### DRUCKSACHE Capabilities

✅ **Can describe:**

- Formal document content (titles, full text)
- Official publication numbers
- Multiple authors/co-signers
- Government ministry involvement (Ressorts)
- Initiating entities (Fraktionen, Bundesregierung)
- PDF links and page numbers
- Document type and structure

❌ **Cannot describe:**

- Procedural status/progress (need Vorgang)
- Individual actions beyond authorship (need Aktivität)
- Floor debates or speeches (need Plenarprotokoll + Aktivität)

### AKTIVITÄT Capabilities

✅ **Can describe:**

- Individual parliamentarian actions
- Personal participation in initiatives
- Fraktion membership at time of action
- Multiple types of participation (signing, speaking, questioning)
- Person-level activity patterns over time
- Co-signature networks

❌ **Cannot describe:**

- Document content (need Drucksache)
- Procedural outcomes (need Vorgang)
- Full activity history before 2014 (data limitation)

---

## Data Quality and Coverage Summary

| Entity         | Time Span   | Records  | Coverage Quality     |
| -------------- | ----------- | -------- | -------------------- |
| **Vorgang**    | WP7-21      | 414,296  | ✅ Complete 50 years |
|                | (1972-2025) |          |                      |
| **Drucksache** | WP7-21      | 24,507\* | ✅ Complete 50 years |
|                | (1972-2025) |          | (\*question docs)    |
| **Aktivität**  | WP18-21     | 648,329  | ⚠️ Only 12 years     |
|                | (2014-2025) |          | (2014-present)       |

**Critical implication for research:**

- **Institutional analysis** (fraktion collaboration): Use Vorgang + Drucksache (50 years available)
- **Individual analysis** (person-level participation): Limited to Aktivität (only 12 years)
- **Research Question #7 & #9** used Aktivität data, so findings only cover WP18-21

---

## Use Cases by Entity

### Use VORGANG when analyzing:

- Legislative productivity over time
- Procedural patterns (how many questions vs laws)
- Cross-reference between related procedures
- Beratungsstand (deliberation status) tracking
- Subject area distributions (Sachgebiet)

### Use DRUCKSACHE when analyzing:

- Document content (titles, text)
- Fraktion-level authorship patterns
- Government ministry involvement
- Official publication patterns
- Collaboration via co-authorship

### Use AKTIVITÄT when analyzing:

- Individual parliamentarian behavior
- Personal activity levels (e.g., Jan Wenzel Schmidt: 126 aktivitäten)
- Fraktion membership changes over time
- Person-to-document linkages
- Co-signature networks at person level

---

## Common Query Patterns

### 1. Find all documents for a procedure

```sql
SELECT d.*
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
WHERE dv.vorgang_id = '329238';
```

### 2. Find all people who participated in a procedure

```sql
SELECT a.titel, a.aktivitaetsart, a.datum
FROM aktivitaet a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE av.vorgang_id = '329238';
```

### 3. Find all procedures a person participated in

```sql
SELECT v.titel, v.vorgangstyp, v.datum
FROM vorgang v
INNER JOIN aktivitaet_vorgangsbezug av ON v.id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
WHERE a.titel LIKE '%Jan Wenzel Schmidt%';
```

### 4. Count collaborations between fraktionen (50-year analysis)

```sql
-- Use Drucksache urheber, not Aktivität (broader coverage)
SELECT
    u1.bezeichnung AS fraktion1,
    u2.bezeichnung AS fraktion2,
    COUNT(DISTINCT d.id) AS joint_documents
FROM drucksache d
INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
INNER JOIN urheber u1 ON du1.urheber_id = u1.id
INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
INNER JOIN urheber u2 ON du2.urheber_id = u2.id
WHERE u1.id < u2.id  -- Avoid duplicates
AND u1.bezeichnung LIKE '%Fraktion%'
AND u2.bezeichnung LIKE '%Fraktion%'
GROUP BY u1.bezeichnung, u2.bezeichnung;
```

---

## Key Insights from Relationship Analysis

### From Research Question #4 (Drucksache-Vorgang Relationships):

- **98.11%** of Drucksachen link to Vorgänge (high data quality)
- **10x volume difference**: 414,296 Vorgänge vs 42,344 Drucksachen (WP7-21)
  - Reason: Many procedures are oral/procedural only (debates, speeches)
  - Not all Vorgänge produce formal documents

### From Research Question #9 (Oversight Evolution):

- **Aktivität explosion in WP19**: 402,582 records (62% of all aktivitäten)
- **Correlation**: Matches the "procedural explosion" (11,715 question vorgänge)
- **Pattern**: AfD entry → massive increase in individual questioning activity

### From Research Question #7 (Individual Champions):

- **Aktivität.titel format discovered**: "Name, MdB, Fraktion"
- **Most active individual**: Jan Wenzel Schmidt (AfD) - 126 aktivitäten in WP21
- **Opposition dominance**: 83% of Kleine Anfragen filed by AfD + Die Linke

---

## Summary Table: Entity Comparison

| Aspect              | VORGANG           | DRUCKSACHE       | AKTIVITÄT           |
| ------------------- | ----------------- | ---------------- | ------------------- |
| **Represents**      | Process/Procedure | Formal Document  | Individual Action   |
| **Granularity**     | Container         | Document         | Person              |
| **ID Example**      | 329238            | 283846           | 1748548             |
| **Key Field**       | vorgangstyp       | dokumentnummer   | titel (person name) |
| **Historical Data** | 50 years          | 50 years         | 12 years            |
| **Volume (total)**  | 414,296           | 42,344           | 648,329             |
| **Authorship**      | Fraktion (group)  | Multiple authors | Single person       |
| **Use for 50yr**    | ✅ Yes            | ✅ Yes           | ❌ No (2014+)       |

---

## Conclusion

These three entities form a **hierarchical information architecture**:

1. **VORGANG** = "What happened procedurally?" (the process)
2. **DRUCKSACHE** = "What was formally published?" (the document)
3. **AKTIVITÄT** = "Who did what specifically?" (the individual)

For **long-term historical analysis** (50 years), rely on **Vorgang + Drucksache**.  
For **individual behavior tracking**, use **Aktivität** but accept **12-year limitation**.

The architecture allows analysis at three levels:

- **Institutional** (Vorgang: procedural patterns)
- **Organizational** (Drucksache: fraktion collaboration)
- **Individual** (Aktivität: personal participation)

This multi-level structure enables the German Bundestag to track everything from high-level legislative productivity down to individual parliamentarian contributions.
