# Drucksache-Vorgang Relationship Analysis

**Analysis Date:** December 17, 2025  
**Dataset:** Complete dip.clean.db (326,960 vorgänge, 201,840 drucksachen)

---

## Executive Summary

This analysis examines the structural and collaborative relationship between **Drucksachen** (formal parliamentary documents) and **Vorgänge** (legislative procedures) in the German Bundestag. The relationship reveals a critical distinction between **procedural inclusion** and **policy partnership** in fraktion collaboration.

**Key Findings:**

- **98.11%** of Drucksachen link to at least one Vorgang
- **28.95%** of Vorgänge have linked Drucksachen
- Joint vorgang initiatives produce 54,770 drucksachen, but **only 7.14% are also joint fraktion**
- Joint fraktion drucksachen almost always link to vorgänge (**97.42%**)
- This asymmetry reveals the difference between mandatory procedural participation and voluntary policy collaboration

---

## Part 1: Structural Relationship

### Database Architecture

The `drucksache_vorgangsbezug` table links formal documents to legislative procedures:

- **Primary key:** (drucksache_id, vorgang_id, display_order)
- **Foreign keys:** References both drucksache(id) and vorgang(id)
- **Additional fields:** titel, vorgangstyp, display_order

### Coverage Statistics

| Metric                         | Count   | Percentage |
| ------------------------------ | ------- | ---------- |
| **Total Drucksachen**          | 201,840 | 100%       |
| Drucksachen WITH vorgang links | 198,025 | **98.11%** |
| **Total Vorgänge**             | 326,960 | 100%       |
| Vorgänge WITH drucksache links | 94,663  | **28.95%** |

**Interpretation:**

- Nearly all formal documents link to a legislative procedure
- Less than one-third of procedures generate formal documents
- Many vorgänge are procedural (questions, oversight) without requiring drucksachen

---

## Part 2: Relationship Cardinality

### Links Per Drucksache

| Vorgänge Count | Drucksachen | Percentage |
| -------------- | ----------- | ---------- |
| **1**          | **184,316** | **93.08%** |
| 2              | 7,432       | 3.75%      |
| 3              | 1,389       | 0.70%      |
| 4              | 4,888       | 2.47%      |

**Pattern:** The overwhelming majority (93%) of drucksachen link to exactly **one vorgang** - a nearly one-to-one relationship. Multiple linkages occur when:

- Drucksache addresses multiple related procedures
- Wahlvorschläge (election proposals) cover multiple committee appointments
- Comprehensive reports reference multiple legislative processes

---

## Part 3: Linkage by Document Type

### Drucksachetyp - Vorgang Link Rates

| Drucksachetyp                       | Total  | With Vorgang | % Linked    |
| ----------------------------------- | ------ | ------------ | ----------- |
| **Beschluss** (Resolution)          | 22,175 | 22,174       | **100.00%** |
| **Empfehlungen** (Recommendations)  | 14,685 | 14,685       | **100.00%** |
| **Beschlussempfehlung**             | 6,007  | 6,007        | **100.00%** |
| **Gesetzentwurf** (Bill)            | 14,155 | 14,147       | **99.94%**  |
| **Antrag** (Motion)                 | 21,126 | 20,800       | **98.46%**  |
| **Verordnung** (Ordinance)          | 6,178  | 6,100        | **98.74%**  |
| **Antwort** (Answer)                | 24,519 | 24,015       | **97.94%**  |
| **Kleine Anfrage** (Minor Question) | 23,530 | 23,050       | **97.96%**  |
| **Unterrichtung** (Notification)    | 24,954 | 23,448       | **93.96%**  |

**Key Insight:** Substantive legislative documents (bills, motions, resolutions) have near-perfect linkage (98-100%), while informational documents have slightly lower rates. This confirms that **vorgänge are the procedural containers** for legislative work.

---

## Part 4: Joint Fraktion Drucksachen → Vorgänge

### Do Joint Policy Documents Link to Procedures?

| Metric                     | Count | Percentage |
| -------------------------- | ----- | ---------- |
| Joint fraktion drucksachen | 4,231 | 100%       |
| WITH vorgang link          | 4,122 | **97.42%** |

**Finding:** Joint fraktion drucksachen almost universally link to vorgänge. This makes sense - formal policy documents (co-authored bills, motions) automatically create or link to legislative procedures.

### Vorgangstypen from Joint Drucksachen

| Vorgangstyp                | Drucksachen | % of Joint |
| -------------------------- | ----------- | ---------- |
| **Antrag**                 | 1,614       | **38.15%** |
| **Gesetzgebung**           | 1,373       | **32.45%** |
| Entschließungsantrag BT    | 417         | 9.86%      |
| Kleine Anfrage             | 248         | 5.86%      |
| Besetzung externer Gremien | 167         | 3.95%      |
| Besetzung interner Gremien | 111         | 2.62%      |
| Große Anfrage              | 105         | 2.48%      |
| EU-Vorlage                 | 21          | 0.50%      |
| Untersuchungsausschuss     | 18          | 0.43%      |

**Pattern:** Joint fraktion drucksachen predominantly link to:

1. **Antrag procedures (38%)** - policy motions and proposals
2. **Gesetzgebung (32%)** - formal legislative processes
3. Combined **70%** are substantive policy procedures

This confirms joint drucksachen represent **voluntary policy partnerships**, not procedural obligations.

---

## Part 5: Joint Vorgänge → Drucksachen (The Critical Finding)

### Do Joint Procedural Initiatives Produce Joint Documents?

| Metric                             | Count     | Rate             |
| ---------------------------------- | --------- | ---------------- |
| Joint fraktion initiative vorgänge | 44,285    | -                |
| Linked drucksachen produced        | 54,770    | 1.24 per vorgang |
| **Also joint fraktion authorship** | **3,912** | **7.14%**        |

**Critical Discovery:** Joint vorgang initiatives produce drucksachen at a normal rate (1.24 per vorgang), BUT **only 7.14%** of those drucksachen are also co-authored by multiple fraktionen.

### What This Reveals

**92.86% of drucksachen from joint vorgänge are SINGLE fraktion authored**, meaning:

1. **Oversight Questions:** Joint question initiative → each fraktion gets separate answer document
2. **Committee Work:** Multi-party committee assignments → individual fraktion position papers
3. **Procedural Motions:** Required multi-party sponsorship → single fraktion statements
4. **Budget Reviews:** Joint oversight → separate fraktion evaluations

**The 7.14% exception** represents cases where procedural collaboration matured into policy partnership:

- True cross-party consensus bills
- Coalition agreement implementations
- Constitutional-level changes requiring supermajority
- European integration measures

---

## Part 6: Asymmetric Relationship Pattern

### Forward Direction: Joint Drucksachen → Vorgänge

```
4,231 joint fraktion drucksachen
         ↓ (97.42% link)
4,122 link to vorgänge
         ↓
Predominantly Antrag (38%) and Gesetzgebung (32%) procedures
```

**Nature:** Voluntary policy partnerships producing formal co-authored documents that link to legislative procedures.

### Reverse Direction: Joint Vorgänge → Drucksachen

```
44,285 joint fraktion initiative vorgänge
         ↓ (generates 1.24 docs per vorgang)
54,770 drucksachen produced
         ↓ (only 7.14% joint)
3,912 also joint fraktion authored
```

**Nature:** Mandatory procedural participation producing primarily single-fraktion documents despite multi-party initiative.

---

## Part 7: Conceptual Model

### Vorgänge = Procedural Container

A **Vorgang** represents the legislative case file or procedure:

- Initiated by one or more fraktionen
- Contains all related activities and documents
- Tracks the lifecycle of a legislative matter
- May or may not produce formal documents

**Examples:**

- Gesetzgebung: Bill introduction → committee review → amendments → final vote
- Kleine Anfrage: Question submission → government response
- Antrag: Motion proposal → debate → vote

### Drucksachen = Documentary Output

A **Drucksache** represents formal printed parliamentary documents:

- Bills, motions, answers, reports, resolutions
- Official record of positions and decisions
- Can be single-fraktion or multi-fraktion authored
- Nearly always links to a parent vorgang

**Examples:**

- Gesetzentwurf: Formal bill text
- Antwort: Official government response
- Antrag: Written motion proposal
- Beschlussempfehlung: Committee recommendation

---

## Part 8: The Collaboration Discontinuity

### Why Joint Initiatives Don't Produce Joint Documents

**1. Procedural Design:**

- Parliamentary rules require multi-party sponsorship for certain initiatives
- Each fraktion retains right to individual position statements
- Committee assignments distribute work but not authorship

**2. Oversight Function:**

- Questions directed at government receive official answers
- Answers are from government, not from fraktionen
- Fraktionen may jointly ask but don't jointly answer

**3. Political Strategy:**

- Joint initiative signals shared concern
- Separate documents allow nuanced positions
- Coalition partners coordinate procedure but maintain distinct brands

**4. Documentary Convention:**

- Drucksachen record official positions
- Fraktionen rarely co-author unless true policy agreement
- Procedural collaboration ≠ policy consensus

### Why Joint Documents Almost Always Have Vorgänge

**1. Structural Necessity:**

- Formal documents require procedural basis
- Bills must follow Gesetzgebung procedure
- Motions create Antrag procedures

**2. Parliamentary Process:**

- Co-authored bill → automatic Gesetzgebung vorgang
- Joint motion → creates Antrag vorgang
- Parliamentary system requires procedural tracking

**3. Coalition Governance:**

- Coalition agreements mandate joint bill introductions
- Joint documents formalize coalition policy
- Vorgänge track legislative implementation

---

## Part 9: Sample Relationships (WP20-21)

### Joint Fraktion Gesetzentwürfe and Their Vorgänge

| WP  | Drucksachetyp | Vorgangstyp  | Titel                                                                                          |
| --- | ------------- | ------------ | ---------------------------------------------------------------------------------------------- |
| 21  | Gesetzentwurf | Gesetzgebung | Entwurf eines Gesetzes zur Änderung des Abgeordnetengesetzes                                   |
| 21  | Gesetzentwurf | Gesetzgebung | Entwurf eines Gesetzes zur Beschleunigung des Wohnungsbaus                                     |
| 21  | Gesetzentwurf | Gesetzgebung | Entwurf eines Gesetzes zur Errichtung eines Sondervermögens Infrastruktur und Klimaneutralität |
| 21  | Gesetzentwurf | Gesetzgebung | Entwurf eines Haushaltsbegleitgesetzes 2025                                                    |
| 21  | Gesetzentwurf | Gesetzgebung | Entwurf eines Gesetzes zur Umsetzung von Vorgaben der Richtlinie (EU) 2023/2413                |

**Pattern:** Every joint fraktion Gesetzentwurf creates a Gesetzgebung vorgang. The bill (drucksache) is the formal policy document, the procedure (vorgang) is the legislative process tracking it through parliament.

---

## Part 10: Implications for Collaboration Analysis

### Two Types of Collaboration Revealed

**1. Vorgang Initiative Collaboration (Procedural Inclusion)**

- **Volume:** 44,285 joint initiatives
- **Nature:** Mandatory/procedural participation
- **Output:** 54,770 drucksachen (mostly single-fraktion)
- **Pattern:** Includes AfD normally (600+ with major parties)
- **Interpretation:** Parliamentary system requires multi-party engagement in procedures

**2. Drucksache Co-Authorship (Policy Partnership)**

- **Volume:** 4,231 joint drucksachen
- **Nature:** Voluntary policy agreement
- **Output:** Nearly all link to vorgänge (97%)
- **Pattern:** AfD isolated (1 bilateral only)
- **Interpretation:** True policy consensus rare, selective partnerships

### The 7.14% Overlap Zone

The **3,912 drucksachen** that are both:

1. From joint vorgang initiatives, AND
2. Co-authored by multiple fraktionen

These represent the **sweet spot of collaboration** - cases where procedural cooperation matured into substantive policy partnership. Likely includes:

- Coalition agreement implementations
- Constitutional amendments
- European integration measures
- Emergency legislation (pandemic, economic crisis)
- Consensus foreign policy

---

## Conclusion

The drucksache-vorgang relationship is **structurally tight** (98% linked) but **collaboratively asymmetric**:

1. **Vorgänge are procedural containers** - nearly all involve some form of multi-party participation through parliamentary rules

2. **Drucksachen are policy documents** - only co-authored when true partnership exists

3. **The 93% discontinuity** (joint vorgänge producing single-fraktion drucksachen) reveals the difference between:

   - **Procedural inclusion:** System requires participation
   - **Policy partnership:** Rare voluntary collaboration

4. **The 97% linkage** (joint drucksachen to vorgänge) shows formal policy documents always exist within procedural frameworks

5. **This explains our dual analysis findings:**
   - Vorgang analysis: 44,284 joint initiatives (broad procedural engagement)
   - Drucksache analysis: 4,231 joint documents (selective policy partnerships)
   - Only 7.14% overlap: True consensus is rare

**Final Insight:** The German parliamentary system ensures **procedural inclusion** (all parties participate in legislative processes) while preserving **documentary independence** (parties maintain distinct policy positions). The rare cases of joint drucksachen represent genuine cross-party consensus - either coalition governance or extraordinary circumstances requiring supermajority legitimacy.
