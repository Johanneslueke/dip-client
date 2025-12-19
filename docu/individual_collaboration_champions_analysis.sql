-- ========================================
-- INDIVIDUAL COLLABORATION CHAMPIONS ANALYSIS
-- Research Question 7: Who are the most active parliamentary participants?
-- ========================================
-- This analysis identifies individuals who dominate parliamentary activity
-- across questions (Kleine Anfragen), speeches (Reden), and motions (Anträge).
-- 
-- KEY FINDINGS:
-- - Opposition dominates: AfD + Die Linke file 83% of Kleine Anfragen
-- - Most active (WP21): Jan Wenzel Schmidt (AfD) - 126 aktivitaeten
-- - Government silence: SPD + CDU/CSU file ZERO Kleine Anfragen (ministerial access)
-- - Legendary career: Gregor Gysi (35+ years, WP11-21)
-- - No individual bridge-builders: Cross-party work happens at fraktion level
-- ========================================

-- PART 1: MOST ACTIVE INDIVIDUALS BY WAHLPERIODE
-- Identifies top parliamentary participants across all activity types

WITH person_activity AS (
    SELECT 
        a.titel as person_fraktion,
        a.wahlperiode,
        a.aktivitaetsart,
        COUNT(*) as count,
        COUNT(DISTINCT av.vorgang_id) as unique_vorgaenge
    FROM aktivitaet a
    INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
    WHERE a.titel LIKE '%, MdB, %'
    AND a.wahlperiode BETWEEN 17 AND 21
    GROUP BY a.titel, a.wahlperiode, a.aktivitaetsart
)
SELECT 
    person_fraktion,
    wahlperiode,
    SUM(count) as total_aktivitaeten,
    SUM(unique_vorgaenge) as total_vorgaenge,
    SUM(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN count ELSE 0 END) as kleine_anfragen,
    SUM(CASE WHEN aktivitaetsart = 'Rede' THEN count ELSE 0 END) as reden,
    SUM(CASE WHEN aktivitaetsart = 'Antrag' THEN count ELSE 0 END) as antraege
FROM person_activity
GROUP BY person_fraktion, wahlperiode
HAVING total_aktivitaeten >= 60
ORDER BY wahlperiode DESC, total_aktivitaeten DESC
LIMIT 40;

-- SAMPLE RESULTS (WP21):
-- 1. Jan Wenzel Schmidt, AfD: 126 total (60 Anfragen, 7 Reden, 37 Anträge)
-- 2. Tobias Ebenberger, AfD: 122 total (42 Anfragen, 5 Reden, 50 Anträge)
-- 3. Dr. Christoph Birghan, AfD: 119 total (29 Anfragen, 6 Reden, 51 Anträge)
-- Pattern: AfD dominates top 15 (12 of 15), followed by Die Linke (3)

-- PART 2: ACTIVITY BY FRAKTION PER WAHLPERIODE
-- Shows fraktion-level participation patterns

WITH fraktion_activity AS (
    SELECT 
        a.wahlperiode,
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
            WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'BÜNDNIS 90/DIE GRÜNEN'
            WHEN a.titel LIKE '%DIE LINKE%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%Grüne%' THEN 'Grüne'
            ELSE 'Other'
        END as fraktion,
        a.aktivitaetsart,
        COUNT(*) as count
    FROM aktivitaet a
    WHERE a.titel LIKE '%, MdB, %'
    AND a.wahlperiode BETWEEN 17 AND 21
    GROUP BY a.wahlperiode, fraktion, a.aktivitaetsart
)
SELECT 
    wahlperiode,
    fraktion,
    SUM(count) as total_aktivitaeten,
    SUM(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN count ELSE 0 END) as kleine_anfragen,
    SUM(CASE WHEN aktivitaetsart = 'Rede' THEN count ELSE 0 END) as reden,
    ROUND(100.0 * SUM(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN count ELSE 0 END) / SUM(count), 2) as pct_questions
FROM fraktion_activity
WHERE fraktion != 'Other'
GROUP BY wahlperiode, fraktion
ORDER BY wahlperiode DESC, total_aktivitaeten DESC;

-- RESULTS (WP21):
-- AfD: 7,625 total (3,233 Anfragen = 42.4%)
-- DIE LINKE: 3,239 total (1,691 Anfragen = 52.2%) - HIGHEST question %
-- BÜNDNIS 90/DIE GRÜNEN: 2,868 total (766 Anfragen = 26.7%)
-- CDU/CSU: 1,001 total (0 Anfragen = 0.0%) - GOVERNMENT SILENCE
-- SPD: 652 total (0 Anfragen = 0.0%) - GOVERNMENT SILENCE

-- PART 3: TOP QUESTION-FILERS (KLEINE ANFRAGEN)
-- Opposition oversight specialists

SELECT 
    wahlperiode,
    titel as person_fraktion,
    COUNT(*) as kleine_anfragen_count
FROM aktivitaet
WHERE aktivitaetsart = 'Kleine Anfrage'
AND titel LIKE '%, MdB, %'
AND wahlperiode BETWEEN 15 AND 21
GROUP BY wahlperiode, titel
HAVING kleine_anfragen_count >= 15
ORDER BY wahlperiode DESC, kleine_anfragen_count DESC
LIMIT 40;

-- TOP 10 (WP21):
-- 1. David Schliesing, DIE LINKE: 63
-- 2. Donata Vogtschmidt, DIE LINKE: 62
-- 3. Jan Wenzel Schmidt, AfD: 60
-- 4. Udo Theodor Hemmelgarn, AfD: 57
-- 5. Lukas Rehm, AfD: 57
-- Pattern: 100% opposition (AfD + Die Linke), zero government parties

-- PART 4: TOP SPEAKERS (REDEN)
-- Floor debate participants

SELECT 
    wahlperiode,
    titel as person_fraktion,
    COUNT(*) as rede_count
FROM aktivitaet
WHERE aktivitaetsart = 'Rede'
AND titel LIKE '%, MdB, %'
AND wahlperiode BETWEEN 19 AND 21
GROUP BY wahlperiode, titel
HAVING rede_count >= 10
ORDER BY wahlperiode DESC, rede_count DESC
LIMIT 30;

-- TOP 10 (WP21):
-- 1. Sascha Wagner, DIE LINKE: 17
-- 2. Stephan Brandner, AfD: 16
-- 3. Stefan Seidler, fraktionslos: 15
-- 4. Helge Lindh, SPD: 15 - GOVERNMENT
-- 5. Dr. Konrad Körner, CDU/CSU: 14 - GOVERNMENT
-- Pattern: More balanced - government parties appear (speeches = messaging tool)

-- PART 5: CROSS-PARTY INDIVIDUAL ACTIVITY
-- Who appears in joint vorgang initiatives?

WITH aktivitaet_in_joint AS (
    SELECT 
        a.id,
        a.titel,
        a.aktivitaetsart,
        a.wahlperiode,
        av.vorgang_id
    FROM aktivitaet a
    INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
    WHERE a.wahlperiode BETWEEN 19 AND 21
    AND a.titel LIKE '%, MdB, %'
    AND av.vorgang_id IN (
        SELECT vorgang_id
        FROM vorgang_initiative
        WHERE initiative LIKE 'Fraktion%'
        GROUP BY vorgang_id
        HAVING COUNT(DISTINCT initiative) > 1
    )
)
SELECT 
    titel as person_fraktion,
    wahlperiode,
    COUNT(DISTINCT vorgang_id) as joint_vorgaenge_count,
    COUNT(*) as total_aktivitaeten
FROM aktivitaet_in_joint
GROUP BY titel, wahlperiode
HAVING joint_vorgaenge_count >= 3
ORDER BY joint_vorgaenge_count DESC, wahlperiode DESC
LIMIT 30;

-- RESULTS (WP19-21):
-- Stephan Brandner, AfD (WP21): 4 joint vorgänge
-- Lisa Paus, BÜNDNIS 90/DIE GRÜNEN (WP21): 3 joint vorgänge
-- Ina Latendorf, DIE LINKE (WP21): 3 joint vorgänge
-- Filiz Polat, BÜNDNIS 90/DIE GRÜNEN (WP21): 3 joint vorgänge
-- INTERPRETATION: Even "most collaborative" individuals show only 3-4 instances
-- Cross-party individual collaboration is EXTREMELY RARE

-- PART 6: LEGENDARY CAREERS (MULTI-WAHLPERIODE SERVICE)
-- Long-serving Bundestagsmitglieder

SELECT 
    p.id,
    p.vorname,
    p.nachname,
    pr.fraktion,
    GROUP_CONCAT(DISTINCT pw.wahlperiode_nummer) as wahlperioden,
    pr.funktion
FROM person p
INNER JOIN person_role pr ON p.id = pr.person_id
INNER JOIN person_wahlperiode pw ON p.id = pw.person_id
WHERE p.nachname IN ('Merkel', 'Scholz', 'Lindner', 'Gysi', 'Baerbock', 'Kubicki', 'Weidel', 'Chrupalla', 'Wagenknecht')
GROUP BY p.id, p.vorname, p.nachname, pr.fraktion, pr.funktion
ORDER BY p.nachname;

-- KEY CAREERS:
-- Gregor Gysi (PDS/Die Linke): WP11-21 (35+ years, 1990-present)
-- Angela Merkel (CDU/CSU): WP12-19 (28 years, 1994-2021, Bundeskanzlerin 2005-2021)
-- Olaf Scholz (SPD): WP14-21 (27+ years, 1998-present, Bundeskanzler 2021-present)
-- Annalena Baerbock (Grüne): WP18-21 (12+ years, Außenministerin)
-- Sahra Wagenknecht (Die Linke): WP17-21 (12+ years, later formed BSW)

-- PART 7: PARLIAMENTARY ROLES AND COLLABORATION POTENTIAL
-- Institutional positions that require cross-party interaction

SELECT DISTINCT funktion, COUNT(*) as count
FROM person_role
WHERE funktion IS NOT NULL
GROUP BY funktion
ORDER BY count DESC
LIMIT 20;

-- KEY ROLES:
-- MdB: 1,274 (standard members)
-- Bundestagsvizepräsident: 31 (requires impartiality)
-- Bundestagspräsident: 6 (highest institutional neutrality)
-- Parl. Staatssekretär: 245 (government role)
-- Bundesminister: 173 (coalition leadership)
-- Alterspräsident: 5 (ceremonial, e.g., Gysi)

-- PART 8: AKTIVITAETSART DISTRIBUTION
-- What types of parliamentary activities exist?

SELECT DISTINCT aktivitaetsart, COUNT(*) as count
FROM aktivitaet
GROUP BY aktivitaetsart
ORDER BY count DESC
LIMIT 15;

-- DISTRIBUTION:
-- Kleine Anfrage: 5,690 (oversight questions)
-- Antrag: 3,234 (motions)
-- Rede: 2,692 (speeches)
-- Frage: 2,061 (questions)
-- Antwort: 1,820 (answers)
-- Entschließungsantrag: 537 (resolutions)
-- Pattern: Questions (Kleine Anfrage + Frage) dominate = oversight function

-- PART 9: TOTAL PERSONS IN DATABASE
-- Dataset scope

SELECT 'Total persons' as metric, COUNT(*) as count FROM person;

-- Result: 5,811 persons total in database

-- PART 10: SAMPLE HIGH-ACTIVITY INDIVIDUALS WITH DETAILS
-- Detailed profile of top participants

SELECT 
    a.titel as person_fraktion,
    a.wahlperiode,
    a.aktivitaetsart,
    COUNT(*) as count
FROM aktivitaet a
WHERE a.titel IN (
    'Jan Wenzel Schmidt, MdB, AfD',
    'Gregor Gysi, MdB, DIE LINKE',
    'Dr. Gregor Gysi, MdB, DIE LINKE',
    'Stephan Brandner, MdB, AfD',
    'David Schliesing, MdB, DIE LINKE'
)
AND a.wahlperiode = 21
GROUP BY a.titel, a.wahlperiode, a.aktivitaetsart
ORDER BY a.titel, count DESC;

-- SAMPLE PROFILES:
-- Jan Wenzel Schmidt (AfD): Balanced - questions, speeches, motions
-- Gregor Gysi (Die Linke): 38 Kleine Anfragen despite Alterspräsident status
-- Stephan Brandner (AfD): Speech-focused (27 Reden) + cross-party (4 joint vorgänge)
-- David Schliesing (Die Linke): Question specialist (63 Kleine Anfragen)

-- ========================================
-- INTERPRETATION NOTES
-- ========================================
--
-- 1. OPPOSITION DOMINANCE:
--    - AfD + Die Linke file 83% of all Kleine Anfragen
--    - Government parties (SPD, CDU/CSU) file ZERO questions
--    - Confirms: Questions are opposition oversight tool
--
-- 2. AfD ISOLATION PARADOX:
--    - Most active fraktion (7,625 aktivitaeten in WP21)
--    - But only 1 bilateral drucksache in 8 years
--    - Strategy: Visibility without partnership
--
-- 3. NO INDIVIDUAL BRIDGE-BUILDERS:
--    - Maximum 3-4 joint vorgänge per person
--    - Cross-party work happens at fraktion level
--    - System rewards party loyalty over individual entrepreneurship
--
-- 4. LEGENDARY CAREERS:
--    - Gregor Gysi: 35+ years (WP11-21), institutional memory
--    - Angela Merkel: 28 years, dominated era (Bundeskanzlerin 2005-2021)
--    - Current leaders (Scholz, Baerbock, Lindner) all long-serving
--
-- 5. ROLE-BASED PATTERNS:
--    - Opposition: Questions > Speeches > Motions
--    - Government: Speeches > Zero questions > Government bills
--    - Junior coalition (Grüne): Balanced (maintains some questions)
--
-- 6. INSTITUTIONAL ROLES:
--    - Bundestagspräsident (6): Structural impartiality required
--    - Bundestagsvizepräsident (31): Procedural neutrality
--    - Alterspräsident (5): Ceremonial, not policy collaboration
--
-- 7. DATA LIMITATIONS:
--    - No direct person_id → vorgang_initiative linkage
--    - Person names only in aktivitaet.titel (unstructured)
--    - Makes systematic collaboration tracking difficult
--    - Bias toward opposition (visible questions) vs government (ministry work)
--
-- ========================================
