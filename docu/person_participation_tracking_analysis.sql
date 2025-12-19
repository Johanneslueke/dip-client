-- ============================================================================
-- PERSON-LEVEL PARTICIPATION TRACKING ANALYSIS
-- Comprehensive Individual Parliamentarian Activity Patterns (1997-2025)
-- ============================================================================
-- Context: This analysis tracks individual parliamentarian participation
-- across all parliamentary activities. Coverage includes WP13-15 (1997-2005)
-- and WP18-21 (2014-2025), spanning 28 years of aktivitaet data.
--
-- Key Data Sources:
-- - aktivitaet: Individual actions (WP13-15, 18-21, 858,218+ records)
-- - drucksache_autor_anzeige: Document authorship (WP7-21, 114,876 records)
-- - person: Parliamentarian master data (5,811 persons)
-- - person_role: Functions and fraktion memberships (2,733 roles)
-- ============================================================================

-- ============================================================================
-- PART 1: INDIVIDUAL ACTIVITY PROFILES
-- ============================================================================
-- Extract person names from aktivitaet.titel and analyze activity patterns

-- 1A: Most Active Individuals by Total Activity (All Wahlperioden)
WITH person_activity AS (
    SELECT 
        a.titel as person_name,
        -- Extract fraktion from titel (format: "Name, MdB, Fraktion")
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
            ELSE 'Sonstige'
        END as fraktion,
        a.wahlperiode,
        COUNT(*) as total_aktivitaeten,
        COUNT(DISTINCT a.aktivitaetsart) as activity_types,
        MIN(a.datum) as first_activity,
        MAX(a.datum) as last_activity,
        ROUND(JULIANDAY(MAX(a.datum)) - JULIANDAY(MIN(a.datum))) as days_active
    FROM aktivitaet a
    WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    GROUP BY a.titel, fraktion, a.wahlperiode
)
SELECT 
    person_name,
    fraktion,
    wahlperiode,
    total_aktivitaeten,
    activity_types,
    first_activity,
    last_activity,
    days_active
FROM person_activity
ORDER BY total_aktivitaeten DESC
LIMIT 50;

-- 1B: Activity Distribution by Type for Top 10 Individuals (WP21)
WITH top_persons AS (
    SELECT a.titel as person_name
    FROM aktivitaet a
    WHERE a.wahlperiode = 21
    GROUP BY a.titel
    ORDER BY COUNT(*) DESC
    LIMIT 10
)
SELECT 
    a.titel as person_name,
    a.aktivitaetsart,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY a.titel), 2) as pct_of_person_total
FROM aktivitaet a
WHERE a.titel IN (SELECT person_name FROM top_persons)
AND a.wahlperiode = 21
GROUP BY a.titel, a.aktivitaetsart
ORDER BY a.titel, count DESC;

-- 1C: Career Longevity - Individuals Active Across Multiple Wahlperioden
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%PDS%' THEN 'PDS'
        ELSE 'Sonstige'
    END as fraktion,
    COUNT(DISTINCT a.wahlperiode) as wahlperioden_count,
    GROUP_CONCAT(DISTINCT a.wahlperiode ORDER BY a.wahlperiode) as wahlperioden,
    COUNT(*) as total_aktivitaeten,
    MIN(a.datum) as career_start,
    MAX(a.datum) as career_end,
    ROUND((JULIANDAY(MAX(a.datum)) - JULIANDAY(MIN(a.datum))) / 365.25, 1) as years_active
FROM aktivitaet a
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY a.titel, fraktion
HAVING COUNT(DISTINCT a.wahlperiode) >= 4
ORDER BY wahlperioden_count DESC, total_aktivitaeten DESC
LIMIT 50;

-- ============================================================================
-- PART 2: ACTIVITY SPECIALIZATION PATTERNS
-- ============================================================================
-- Identify individuals specialized in specific types of parliamentary work
-- 2A: Question Specialists (Kleine Anfrage focused)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%PDS%' THEN 'PDS'
    END as fraktion,
    a.wahlperiode,
    COUNT(CASE WHEN a.aktivitaetsart = 'Kleine Anfrage' THEN 1 END) as kleine_anfragen,
    COUNT(CASE WHEN a.aktivitaetsart = 'Große Anfrage' THEN 1 END) as grosse_anfragen,
    COUNT(*) as total_aktivitaeten,
    ROUND(COUNT(CASE WHEN a.aktivitaetsart = 'Kleine Anfrage' THEN 1 END) * 100.0 / COUNT(*), 2) as pct_questions
FROM aktivitaet a
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING kleine_anfragen > 50  -- Filter for active questioners
ORDER BY kleine_anfragen DESC
LIMIT 50;
-- 2B: Legislative Specialists (Gesetzentwurf/Antrag focused)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%PDS%' THEN 'PDS'
    END as fraktion,
    a.wahlperiode,
    COUNT(CASE WHEN a.aktivitaetsart = 'Gesetzentwurf' THEN 1 END) as gesetzentwuerfe,
    COUNT(CASE WHEN a.aktivitaetsart = 'Antrag' THEN 1 END) as antraege,
    COUNT(CASE WHEN a.aktivitaetsart = 'Entschließungsantrag' THEN 1 END) as entschliessungsantraege,
    COUNT(*) as total_aktivitaeten,
    ROUND((COUNT(CASE WHEN a.aktivitaetsart IN ('Gesetzentwurf', 'Antrag') THEN 1 END) * 100.0) / COUNT(*), 2) as pct_legislative
FROM aktivitaet a
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING (gesetzentwuerfe + antraege) > 30
ORDER BY (gesetzentwuerfe + antraege) DESC
LIMIT 50;esetzentwuerfe + antraege) > 30
ORDER BY (gesetzentwuerfe + antraege) DESC
LIMIT 30;

-- 2C: Floor Activity Specialists (Rede/Debate focused)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END as fraktion,
    a.wahlperiode,
    COUNT(CASE WHEN a.aktivitaetsart = 'Rede' THEN 1 END) as reden,
    COUNT(CASE WHEN a.aktivitaetsart = 'Zwischenfrage' THEN 1 END) as zwischenfragen,
    COUNT(CASE WHEN a.aktivitaetsart = 'Kurzintervention' THEN 1 END) as kurzinterventionen,
    COUNT(*) as total_aktivitaeten,
    ROUND(COUNT(CASE WHEN a.aktivitaetsart IN ('Rede', 'Zwischenfrage', 'Kurzintervention') THEN 1 END) * 100.0 / COUNT(*), 2) as pct_floor
FROM aktivitaet a
WHERE a.wahlperiode = 21
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING reden > 20
ORDER BY reden DESC
LIMIT 30;

-- ============================================================================
-- PART 3: FRAKTION-LEVEL INDIVIDUAL BEHAVIOR
-- ============================================================================
-- Compare individual behavior patterns across fraktionen

-- 3A: Average Activity by Fraktion Member (WP21)
WITH person_counts AS (
    SELECT 
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
            ELSE 'Sonstige'
        END as fraktion,
        a.titel as person_name,
        COUNT(*) as aktivitaeten_per_person
    FROM aktivitaet a
    WHERE a.wahlperiode = 21
    GROUP BY fraktion, a.titel
)
SELECT 
    fraktion,
    COUNT(DISTINCT person_name) as unique_members,
    SUM(aktivitaeten_per_person) as total_aktivitaeten,
    ROUND(AVG(aktivitaeten_per_person), 2) as avg_per_member,
    MAX(aktivitaeten_per_person) as most_active_member,
    MIN(aktivitaeten_per_person) as least_active_member,
    ROUND(AVG(aktivitaeten_per_person) * 1.0 / (MAX(aktivitaeten_per_person) * 1.0), 3) as activity_equality_ratio
FROM person_counts
WHERE fraktion != 'Sonstige'
GROUP BY fraktion
ORDER BY avg_per_member DESC;

-- 3B: Activity Type Distribution by Fraktion (WP21)
SELECT 
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END as fraktion,
    a.aktivitaetsart,
    COUNT(*) as total_count,
    COUNT(DISTINCT a.titel) as unique_persons,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT a.titel), 2) as avg_per_person
FROM aktivitaet a
WHERE a.wahlperiode = 21
AND a.titel LIKE '%MdB%'  -- Filter for Bundestag members
GROUP BY fraktion, a.aktivitaetsart
ORDER BY fraktion, total_count DESC;

-- ============================================================================
-- PART 4: TEMPORAL ACTIVITY PATTERNS
-- 4A: Monthly Activity Intensity by Top Individuals (All WPs)
WITH top_30_persons AS (
    SELECT a.titel as person_name
    FROM aktivitaet a
    WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    GROUP BY a.titel
    ORDER BY COUNT(*) DESC
    LIMIT 30
)
SELECT 
    a.titel as person_name,
    a.wahlperiode,
    STRFTIME('%Y-%m', a.datum) as month,
    COUNT(*) as aktivitaeten_count
FROM aktivitaet a
WHERE a.titel IN (SELECT person_name FROM top_30_persons)
GROUP BY a.titel, a.wahlperiode, month
ORDER BY a.titel, a.wahlperiode, month;
-- 4B: Activity Trends - First Half vs Second Half of Wahlperiode
WITH wp_midpoint AS (
    SELECT 
        a.wahlperiode,
        MIN(a.datum) as wp_start,
        MAX(a.datum) as wp_end,
        DATE(MIN(a.datum), '+' || 
            CAST((JULIANDAY(MAX(a.datum)) - JULIANDAY(MIN(a.datum))) / 2 AS INTEGER) || ' days') as wp_midpoint
    FROM aktivitaet a
    WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    GROUP BY a.wahlperiode
)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%PDS%' THEN 'PDS'
    END as fraktion,
    a.wahlperiode,
    COUNT(CASE WHEN a.datum < m.wp_midpoint THEN 1 END) as first_half_count,
    COUNT(CASE WHEN a.datum >= m.wp_midpoint THEN 1 END) as second_half_count,
    ROUND(
        (COUNT(CASE WHEN a.datum >= m.wp_midpoint THEN 1 END) * 1.0) / 
        NULLIF(COUNT(CASE WHEN a.datum < m.wp_midpoint THEN 1 END), 0), 
    2) as second_to_first_ratio
FROM aktivitaet a
INNER JOIN wp_midpoint m ON a.wahlperiode = m.wahlperiode
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING (first_half_count + second_half_count) > 100
ORDER BY a.wahlperiode DESC, (first_half_count + second_half_count) DESC
LIMIT 100;
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING (first_half_count + second_half_count) > 50
ORDER BY a.wahlperiode DESC, (first_half_count + second_half_count) DESC;

-- ============================================================================
-- PART 5: CO-PARTICIPATION NETWORKS
-- ============================================================================
-- Identify individuals who frequently work together

-- 5A: Most Frequent Co-Signers (Same Drucksache)
WITH person_drucksache AS (
    SELECT DISTINCT
        a.titel as person_name,
        a.fundstelle_dokumentnummer as dokumentnummer,
        a.wahlperiode
    FROM aktivitaet a
    WHERE a.wahlperiode = 21
    AND a.aktivitaetsart IN ('Kleine Anfrage', 'Antrag', 'Gesetzentwurf')
)
SELECT 
    p1.person_name as person_1,
    p2.person_name as person_2,
    COUNT(DISTINCT p1.dokumentnummer) as joint_documents,
    p1.wahlperiode
FROM person_drucksache p1
INNER JOIN person_drucksache p2 
    ON p1.dokumentnummer = p2.dokumentnummer 
    AND p1.wahlperiode = p2.wahlperiode
    AND p1.person_name < p2.person_name  -- Avoid duplicates
GROUP BY p1.person_name, p2.person_name, p1.wahlperiode
HAVING joint_documents >= 50
ORDER BY joint_documents DESC
LIMIT 50;

-- 5B: Cross-Fraktion Co-Participation (Rare bridge-builders)
WITH person_drucksache AS (
    SELECT DISTINCT
        a.titel as person_name,
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        END as fraktion,
        a.fundstelle_dokumentnummer as dokumentnummer,
        a.wahlperiode
    FROM aktivitaet a
    WHERE a.wahlperiode BETWEEN 19 AND 21
    AND a.aktivitaetsart IN ('Antrag', 'Gesetzentwurf', 'Entschließungsantrag')
)
SELECT 
    p1.person_name as person_1,
    p1.fraktion as fraktion_1,
    p2.person_name as person_2,
    p2.fraktion as fraktion_2,
    COUNT(DISTINCT p1.dokumentnummer) as joint_documents,
    p1.wahlperiode
FROM person_drucksache p1
INNER JOIN person_drucksache p2 
    ON p1.dokumentnummer = p2.dokumentnummer 
    AND p1.wahlperiode = p2.wahlperiode
    AND p1.person_name < p2.person_name
    AND p1.fraktion != p2.fraktion  -- Cross-fraktion only
WHERE p1.fraktion IS NOT NULL 
AND p2.fraktion IS NOT NULL
GROUP BY p1.person_name, p1.fraktion, p2.person_name, p2.fraktion, p1.wahlperiode
HAVING joint_documents >= 5
ORDER BY joint_documents DESC, p1.wahlperiode DESC
LIMIT 50;

-- ============================================================================
-- PART 6: INDIVIDUAL IMPACT METRICS
-- ============================================================================
-- Measure individual influence and reach

-- 6A: Document Reach - Individuals with Most Vorgang Connections
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU_CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%PDS%' THEN 'PDS'
        ELSE 'Sonstige'
    END as fraktion,
    a.wahlperiode,
    COUNT(*) as total_aktivitaeten,
    COUNT(DISTINCT av.vorgang_id) as unique_vorgaenge,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT av.vorgang_id), 2) as aktivitaeten_per_vorgang,
    SUM(a.vorgangsbezug_anzahl) as total_vorgang_connections
FROM aktivitaet a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY a.titel, fraktion, a.wahlperiode
HAVING total_aktivitaeten > 50
ORDER BY unique_vorgaenge DESC
LIMIT 50;

-- 6B: Authorship Impact - Via Drucksache Autor Anzeige (Full Historical Data)
SELECT 
    p.vorname || ' ' || p.nachname as person_name,
    pr.fraktion,
    COUNT(DISTINCT daa.drucksache_id) as authored_drucksachen,
    COUNT(DISTINCT d.wahlperiode) as wahlperioden_active,
    MIN(d.datum) as first_authorship,
    MAX(d.datum) as last_authorship,
    ROUND((JULIANDAY(MAX(d.datum)) - JULIANDAY(MIN(d.datum))) / 365.25, 1) as years_active
FROM person p
INNER JOIN drucksache_autor_anzeige daa ON p.id = daa.person_id
INNER JOIN drucksache d ON daa.drucksache_id = d.id
LEFT JOIN person_role pr ON p.id = pr.person_id AND pr.funktion = 'MdB'
GROUP BY p.id, person_name, pr.fraktion
HAVING authored_drucksachen > 20
ORDER BY authored_drucksachen DESC
LIMIT 50;

-- ============================================================================
-- PART 7: ACTIVITY DIVERSITY INDEX
-- ============================================================================
-- Measure how diversified individuals are across activity types

-- 7A: Activity Diversity Score (Higher = More Diverse)
WITH person_activity_types AS (
    SELECT 
        a.titel as person_name,
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        END as fraktion,
        a.aktivitaetsart,
        COUNT(*) as count,
        SUM(COUNT(*)) OVER (PARTITION BY a.titel) as total_aktivitaeten
    FROM aktivitaet a
    WHERE a.wahlperiode = 21
    GROUP BY a.titel, fraktion, a.aktivitaetsart
)
SELECT 
    person_name,
    fraktion,
    total_aktivitaeten,
    COUNT(DISTINCT aktivitaetsart) as activity_type_count,
    -- Calculate Shannon diversity index
    ROUND(-1 * SUM((count * 1.0 / total_aktivitaeten) * 
        LOG(count * 1.0 / total_aktivitaeten) / LOG(2)), 3) as diversity_index,
    -- List activity types
    GROUP_CONCAT(aktivitaetsart || ':' || count, ', ') as activity_breakdown
FROM person_activity_types
WHERE total_aktivitaeten > 20
GROUP BY person_name, fraktion, total_aktivitaeten
ORDER BY diversity_index DESC
LIMIT 30;

-- 7B: Specialists vs Generalists
WITH person_stats AS (
    SELECT 
        a.titel as person_name,
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        END as fraktion,
        COUNT(*) as total_aktivitaeten,
        COUNT(DISTINCT a.aktivitaetsart) as activity_types,
        MAX(count_per_type.max_count) as max_in_one_type
    FROM aktivitaet a
    INNER JOIN (
        SELECT titel, MAX(type_count) as max_count
        FROM (
            SELECT titel, aktivitaetsart, COUNT(*) as type_count
            FROM aktivitaet
            WHERE wahlperiode = 21
            GROUP BY titel, aktivitaetsart
        )
        GROUP BY titel
    ) count_per_type ON a.titel = count_per_type.titel
    WHERE a.wahlperiode = 21
    GROUP BY a.titel, fraktion
    HAVING total_aktivitaeten > 20
)
SELECT 
    person_name,
    fraktion,
    total_aktivitaeten,
    activity_types,
    max_in_one_type,
    ROUND(max_in_one_type * 100.0 / total_aktivitaeten, 2) as pct_in_primary_type,
    CASE 
        WHEN max_in_one_type * 100.0 / total_aktivitaeten > 80 THEN 'Specialist'
        WHEN max_in_one_type * 100.0 / total_aktivitaeten > 60 THEN 'Focused'
        WHEN max_in_one_type * 100.0 / total_aktivitaeten > 40 THEN 'Balanced'
        ELSE 'Generalist'
    END as profile_type
FROM person_stats
ORDER BY pct_in_primary_type DESC;

-- ============================================================================
-- PART 8: COMPARISON WITH INSTITUTIONAL DATA
-- ============================================================================
-- Compare individual behavior with fraktion-level patterns

-- 8A: Individual Contribution to Fraktion Activity
WITH fraktion_totals AS (
    SELECT 
        CASE 
            WHEN a.titel LIKE '%AfD%' THEN 'AfD'
            WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
            WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
            WHEN a.titel LIKE '%SPD%' THEN 'SPD'
            WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
            WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        END as fraktion,
        COUNT(*) as fraktion_total
    FROM aktivitaet a
    WHERE a.wahlperiode = 21
    GROUP BY fraktion
)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END as fraktion,
    COUNT(*) as individual_aktivitaeten,
    ft.fraktion_total,
    ROUND(COUNT(*) * 100.0 / ft.fraktion_total, 2) as pct_of_fraktion
FROM aktivitaet a
INNER JOIN fraktion_totals ft ON 
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END = ft.fraktion
WHERE a.wahlperiode = 21
GROUP BY a.titel, fraktion, ft.fraktion_total
ORDER BY pct_of_fraktion DESC
LIMIT 50;

-- ============================================================================
-- PART 9: GOVERNMENT VS OPPOSITION BEHAVIOR
-- ============================================================================
-- Compare individual patterns in government vs opposition roles

-- 9A: Opposition Question Activity (WP20-21)
SELECT 
    a.titel as person_name,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END as fraktion,
    CASE 
        WHEN a.wahlperiode = 20 AND a.titel LIKE '%CDU/CSU%' THEN 'Opposition'
        WHEN a.wahlperiode = 20 AND (a.titel LIKE '%SPD%' OR a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%FDP%') THEN 'Government'
        WHEN a.wahlperiode = 21 AND a.titel LIKE '%CDU/CSU%' THEN 'Opposition'
        WHEN a.wahlperiode = 21 AND (a.titel LIKE '%SPD%' OR a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%FDP%') THEN 'Government'
        ELSE 'Opposition'  -- AfD, Linke always opposition
    END as coalition_status,
    a.wahlperiode,
    COUNT(CASE WHEN a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage', 'Frage') THEN 1 END) as questions,
    COUNT(*) as total_aktivitaeten,
    ROUND(COUNT(CASE WHEN a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage', 'Frage') THEN 1 END) * 100.0 / COUNT(*), 2) as pct_questions
FROM aktivitaet a
WHERE a.wahlperiode BETWEEN 20 AND 21
GROUP BY a.titel, fraktion, coalition_status, a.wahlperiode
HAVING total_aktivitaeten > 20
ORDER BY questions DESC
LIMIT 50;
-- 10A: Overall Individual Participation Summary (All WPs)
SELECT 
    'Total Unique Persons' as metric,
    COUNT(DISTINCT titel) as value
FROM aktivitaet
WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)

UNION ALL

SELECT 
    'Average Aktivitaeten per Person',
    ROUND(AVG(person_count), 2)
FROM (
    SELECT titel, COUNT(*) as person_count
    FROM aktivitaet
    WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    GROUP BY titel
)

UNION ALL

SELECT 
    'Median Aktivitaeten per Person',
    (SELECT COUNT(*) FROM aktivitaet 
     WHERE titel = (
         SELECT titel FROM aktivitaet 
         WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
         GROUP BY titel 
         ORDER BY COUNT(*) 
         LIMIT 1 OFFSET (SELECT COUNT(DISTINCT titel) FROM aktivitaet WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)) / 2
     )
    )

UNION ALL

SELECT 
    'Most Active Individual (Total)',
    MAX(person_count)
FROM (
    SELECT titel, COUNT(*) as person_count
    FROM aktivitaet
    WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    GROUP BY titel
)

-- 10B: Peak Activity Periods (Most Active Months, All Time)
SELECT 
    STRFTIME('%Y-%m', a.datum) as month,
    a.wahlperiode,
    COUNT(*) as total_aktivitaeten,
    COUNT(DISTINCT a.titel) as unique_persons,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT a.titel), 2) as avg_per_person
FROM aktivitaet a
WHERE a.wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY month, a.wahlperiode
ORDER BY total_aktivitaeten DESC
LIMIT 30;

-- 10C: Historical Comparison - Activity by Wahlperiode
SELECT 
    wahlperiode,
    COUNT(*) as total_aktivitaeten,
    COUNT(DISTINCT titel) as unique_persons,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT titel), 2) as avg_per_person,
    MIN(datum) as wp_start,
    MAX(datum) as wp_end,
    ROUND((JULIANDAY(MAX(datum)) - JULIANDAY(MIN(datum))) / 365.25, 1) as years
FROM aktivitaet
WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY wahlperiode
ORDER BY wahlperiode;

-- 10B: Peak Activity Periods (Most Active Months)
SELECT 
    STRFTIME('%Y-%m', a.datum) as month,
    COUNT(*) as total_aktivitaeten,
    COUNT(DISTINCT a.titel) as unique_persons,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT a.titel), 2) as avg_per_person
FROM aktivitaet a
WHERE a.wahlperiode BETWEEN 18 AND 21
GROUP BY month
ORDER BY total_aktivitaeten DESC
LIMIT 20;

-- ============================================================================
-- END OF ANALYSIS
-- ============================================================================
