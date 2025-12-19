-- ========================================
-- 50-YEAR FRAKTION COLLABORATION VIA DRUCKSACHEN
-- WP7-21 (1972-2025) - COMPLETE ANALYSIS
-- ========================================
-- This analysis examines fraktion collaboration through joint drucksache authorship
-- over 50 years. Unlike vorgang_initiative (parliamentary procedures),
-- drucksachen represent formal legislative documents (bills, motions, proposals).
--
-- KEY FINDINGS:
-- - 4,231 joint fraktion drucksachen over 50 years
-- - Most collaborative pair: CDU/CSU + FDP (2,189, 26.2%)
-- - Peak collaboration: 1998-2009 red-green era (1,461 joint drucksachen)
-- - WP18 Grand Coalition: 154 joint drucksachen (CDU/CSU+SPD dominance)
-- - 37.3% are bilateral (2 fraktionen only) - true policy partnerships
-- - AfD has only 1 bilateral collaboration (with CDU/CSU)
-- - Document types: 43.3% Anträge, 26.9% Gesetzentwürfe, 10.4% Entschließungsanträge
-- ========================================

-- PART 1: JOINT DRUCKSACHEN BY WAHLPERIODE (WP7-21)
-- Shows how many drucksachen were jointly authored by multiple fraktionen

WITH drucksache_fraktion_count AS (
    SELECT
        d.wahlperiode,
        d.id,
        COUNT(DISTINCT du.urheber_id) as fraktion_count
    FROM drucksache d
    INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
    INNER JOIN urheber u ON du.urheber_id = u.id
    WHERE u.titel LIKE 'Fraktion%'
    GROUP BY d.wahlperiode, d.id
)
SELECT
    wahlperiode,
    COUNT(CASE WHEN fraktion_count >= 2 THEN 1 END) as joint_drucksachen,
    COUNT(*) as total_fraktion_drucksachen,
    ROUND(100.0 * COUNT(CASE WHEN fraktion_count >= 2 THEN 1 END) / COUNT(*), 2) as pct_joint
FROM drucksache_fraktion_count
GROUP BY wahlperiode
ORDER BY wahlperiode;

-- PART 2: JOINT DRUCKSACHEN BY DECADE
-- Aggregated view showing collaboration trends over time

WITH drucksache_fraktion_count AS (
    SELECT
        CASE
            WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1970s-1980s (WP7-9)'
            WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1987-1998 (WP10-12)'
            WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1998-2009 (WP13-15)'
            WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2009-2017 (WP16-18)'
            WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2017-2025 (WP19-21)'
        END as period,
        d.id,
        COUNT(DISTINCT du.urheber_id) as fraktion_count
    FROM drucksache d
    INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
    INNER JOIN urheber u ON du.urheber_id = u.id
    WHERE u.titel LIKE 'Fraktion%'
    GROUP BY period, d.id
    HAVING fraktion_count >= 2
)
SELECT
    period,
    COUNT(*) as joint_drucksachen
FROM drucksache_fraktion_count
GROUP BY period
ORDER BY period;

-- PART 3: TOP FRAKTION PAIRS (WP7-21 ALL TIME)
-- Identifies which fraktionen collaborate most frequently on drucksachen

WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
)
SELECT
    fraktion1,
    fraktion2,
    COUNT(*) as joint_drucksachen,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fraktion_pairs), 2) as pct_of_total
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 15;

-- PART 4: ERA-SPECIFIC FRAKTION PAIRS
-- Breaks down collaboration by political eras

-- 1972-1998 (WP7-13): Kohl Era
WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN drucksache d ON du1.drucksache_id = d.id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode BETWEEN 7 AND 13
)
SELECT fraktion1, fraktion2, COUNT(*) as joint_drucksachen
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 8;

-- 1998-2009 (WP14-16): Red-Green Era
WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN drucksache d ON du1.drucksache_id = d.id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode BETWEEN 14 AND 16
)
SELECT fraktion1, fraktion2, COUNT(*) as joint_drucksachen
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 8;

-- 2009-2013 (WP17): Black-Yellow Era
WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN drucksache d ON du1.drucksache_id = d.id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode = 17
)
SELECT fraktion1, fraktion2, COUNT(*) as joint_drucksachen
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 8;

-- 2013-2017 (WP18): Grand Coalition Era
WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN drucksache d ON du1.drucksache_id = d.id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode = 18
)
SELECT fraktion1, fraktion2, COUNT(*) as joint_drucksachen
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 8;

-- 2017-2025 (WP19-21): Ampel Era
WITH fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN drucksache d ON du1.drucksache_id = d.id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode BETWEEN 19 AND 21
)
SELECT fraktion1, fraktion2, COUNT(*) as joint_drucksachen
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_drucksachen DESC
LIMIT 10;

-- PART 5: COLLABORATION BY DRUCKSACHETYP
-- Shows which types of documents involve fraktion collaboration

WITH joint_drucksachen AS (
    SELECT DISTINCT du1.drucksache_id
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
)
SELECT
    d.drucksachetyp,
    COUNT(*) as joint_drucksachen,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM joint_drucksachen), 2) as pct
FROM joint_drucksachen jd
INNER JOIN drucksache d ON jd.drucksache_id = d.id
GROUP BY d.drucksachetyp
ORDER BY joint_drucksachen DESC;

-- PART 6: BILATERAL VS MULTI-PARTY COLLABORATION
-- Classifies joint drucksachen by number of fraktionen involved

WITH drucksache_fraktion_count AS (
    SELECT
        d.id,
        COUNT(*) as fraktion_count
    FROM drucksache d
    INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
    INNER JOIN urheber u ON du.urheber_id = u.id
    WHERE u.titel LIKE 'Fraktion%'
    GROUP BY d.id
),
fraktion_pairs AS (
    SELECT
        dfc.fraktion_count
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    INNER JOIN drucksache_fraktion_count dfc ON du1.drucksache_id = dfc.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
)
SELECT
    CASE
        WHEN fraktion_count = 2 THEN 'Bilateral (2 fraktionen)'
        WHEN fraktion_count BETWEEN 3 AND 4 THEN 'Multi-Party (3-4)'
        ELSE 'All-Party (5+)'
    END as collaboration_type,
    COUNT(*) as joint_drucksachen,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fraktion_pairs), 2) as pct
FROM fraktion_pairs
GROUP BY collaboration_type
ORDER BY joint_drucksachen DESC;

-- PART 7: TOP BILATERAL COLLABORATIONS (2 Fraktionen Only)
-- Identifies the most significant two-party partnerships

WITH drucksache_fraktion_count AS (
    SELECT
        d.id,
        COUNT(*) as fraktion_count
    FROM drucksache d
    INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
    INNER JOIN urheber u ON du.urheber_id = u.id
    WHERE u.titel LIKE 'Fraktion%'
    GROUP BY d.id
),
fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    INNER JOIN drucksache_fraktion_count dfc ON du1.drucksache_id = dfc.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND dfc.fraktion_count = 2
)
SELECT
    fraktion1,
    fraktion2,
    COUNT(*) as bilateral_collaborations
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY bilateral_collaborations DESC
LIMIT 12;

-- PART 8: AFD BILATERAL COLLABORATION (WP19-21)
-- Examines AfD's isolation in voluntary two-party partnerships

WITH drucksache_fraktion_count AS (
    SELECT
        d.id,
        COUNT(*) as fraktion_count
    FROM drucksache d
    INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
    INNER JOIN urheber u ON du.urheber_id = u.id
    WHERE u.titel LIKE 'Fraktion%'
        AND d.wahlperiode BETWEEN 19 AND 21
    GROUP BY d.id
),
fraktion_pairs AS (
    SELECT
        u1.titel as fraktion1,
        u2.titel as fraktion2
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    INNER JOIN drucksache_fraktion_count dfc ON du1.drucksache_id = dfc.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND dfc.fraktion_count = 2
        AND (u1.titel = 'Fraktion der AfD' OR u2.titel = 'Fraktion der AfD')
)
SELECT
    CASE
        WHEN fraktion1 = 'Fraktion der AfD' THEN fraktion2
        ELSE fraktion1
    END as other_fraktion,
    COUNT(*) as bilateral_with_afd
FROM fraktion_pairs
GROUP BY other_fraktion
ORDER BY bilateral_with_afd DESC;

-- PART 9: SUMMARY STATISTICS
-- Key metrics from the complete analysis

SELECT
    'Total wahlperioden analyzed' as metric,
    '15 (WP7-21)' as value
UNION ALL
SELECT
    'Total joint fraktion drucksachen',
    CAST(COUNT(*) AS TEXT)
FROM (
    SELECT DISTINCT du1.drucksache_id
    FROM drucksache_urheber du1
    INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
)
UNION ALL
SELECT
    'Most collaborative pair (all-time)',
    'CDU/CSU + FDP (2,189, 26.2%)'
UNION ALL
SELECT
    'Peak collaboration decade',
    '1998-2009 (1,461 joint drucksachen)'
UNION ALL
SELECT
    'WP18 Grand Coalition contribution',
    '154 joint drucksachen (5.3%)'
UNION ALL
SELECT
    'Bilateral collaborations',
    CAST((SELECT COUNT(*) FROM (
        SELECT du1.drucksache_id
        FROM drucksache_urheber du1
        INNER JOIN drucksache_urheber du2 ON du1.drucksache_id = du2.drucksache_id
        INNER JOIN urheber u1 ON du1.urheber_id = u1.id
        INNER JOIN urheber u2 ON du2.urheber_id = u2.id
        INNER JOIN (
            SELECT d.id, COUNT(*) as fraktion_count
            FROM drucksache d
            INNER JOIN drucksache_urheber du ON d.id = du.drucksache_id
            INNER JOIN urheber u ON du.urheber_id = u.id
            WHERE u.titel LIKE 'Fraktion%'
            GROUP BY d.id
        ) dfc ON du1.drucksache_id = dfc.id
        WHERE du1.urheber_id < du2.urheber_id
            AND u1.titel LIKE 'Fraktion%'
            AND u2.titel LIKE 'Fraktion%'
            AND dfc.fraktion_count = 2
    )) AS TEXT)
UNION ALL
SELECT
    'AfD bilateral collaborations',
    '1 (with CDU/CSU only)';

-- ========================================
-- PART 10: POLICY CONTENT ANALYSIS
-- ========================================

-- PART 10A: Anträge by Policy Area
-- Analyzes what kinds of motions fraktionen collaborate on

WITH joint_antraege AS (
    SELECT DISTINCT d.id, d.titel, d.wahlperiode
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp = 'Antrag'
)
SELECT
    CASE
        WHEN titel LIKE '%Haushaltsgesetz%' OR titel LIKE '%Haushalt%' THEN 'Budget/Haushalt'
        WHEN titel LIKE '%Europa%' OR titel LIKE '%EU%' OR titel LIKE '%Europäisch%' THEN 'Europa/EU'
        WHEN titel LIKE '%Klimaschutz%' OR titel LIKE '%Umwelt%' OR titel LIKE '%Energie%' THEN 'Klima/Umwelt/Energie'
        WHEN titel LIKE '%Sicherheit%' OR titel LIKE '%Polizei%' OR titel LIKE '%Terrorismus%' THEN 'Sicherheit'
        WHEN titel LIKE '%Sozial%' OR titel LIKE '%Rente%' OR titel LIKE '%Arbeitslos%' THEN 'Soziales/Rente'
        WHEN titel LIKE '%Bildung%' OR titel LIKE '%Schule%' OR titel LIKE '%Universität%' THEN 'Bildung'
        WHEN titel LIKE '%Gesundheit%' OR titel LIKE '%Pflege%' OR titel LIKE '%Kranken%' THEN 'Gesundheit/Pflege'
        WHEN titel LIKE '%Wirtschaft%' OR titel LIKE '%Unternehmen%' OR titel LIKE '%Steuer%' THEN 'Wirtschaft/Steuern'
        WHEN titel LIKE '%Migration%' OR titel LIKE '%Asyl%' OR titel LIKE '%Flüchtling%' OR titel LIKE '%Integration%' THEN 'Migration/Asyl'
        WHEN titel LIKE '%Digitalisierung%' OR titel LIKE '%Internet%' OR titel LIKE '%Datenschutz%' THEN 'Digitalisierung'
        WHEN titel LIKE '%Verkehr%' OR titel LIKE '%Bahn%' OR titel LIKE '%Mobilität%' THEN 'Verkehr/Mobilität'
        WHEN titel LIKE '%Verteidigung%' OR titel LIKE '%Bundeswehr%' OR titel LIKE '%NATO%' THEN 'Verteidigung'
        WHEN titel LIKE '%Kultur%' OR titel LIKE '%Medien%' OR titel LIKE '%Sport%' THEN 'Kultur/Medien/Sport'
        WHEN titel LIKE '%Landwirtschaft%' OR titel LIKE '%Ernährung%' THEN 'Landwirtschaft'
        WHEN titel LIKE '%Justiz%' OR titel LIKE '%Recht%' OR titel LIKE '%Gesetz%' THEN 'Justiz/Recht'
        WHEN titel LIKE '%Familie%' OR titel LIKE '%Kinder%' OR titel LIKE '%Jugend%' THEN 'Familie/Jugend'
        WHEN titel LIKE '%Entwicklung%' OR titel LIKE '%Afrika%' OR titel LIKE '%Entwicklungshilfe%' THEN 'Entwicklungspolitik'
        WHEN titel LIKE '%Außenpolitik%' OR titel LIKE '%Menschenrechte%' THEN 'Außenpolitik'
        ELSE 'Sonstiges'
    END as policy_area,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM joint_antraege), 2) as pct
FROM joint_antraege
GROUP BY policy_area
ORDER BY count DESC
LIMIT 20;

-- PART 10B: Gesetzentwürfe by Policy Area
-- Analyzes what kinds of bills fraktionen collaborate on

WITH joint_gesetze AS (
    SELECT DISTINCT d.id, d.titel, d.wahlperiode
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp = 'Gesetzentwurf'
)
SELECT
    CASE
        WHEN titel LIKE '%Haushaltsgesetz%' OR titel LIKE '%Haushalt%' THEN 'Budget/Haushalt'
        WHEN titel LIKE '%Europa%' OR titel LIKE '%EU%' OR titel LIKE '%Europäisch%' THEN 'Europa/EU'
        WHEN titel LIKE '%Klimaschutz%' OR titel LIKE '%Umwelt%' OR titel LIKE '%Energie%' THEN 'Klima/Umwelt/Energie'
        WHEN titel LIKE '%Sicherheit%' OR titel LIKE '%Polizei%' OR titel LIKE '%Terrorismus%' OR titel LIKE '%Strafrecht%' THEN 'Sicherheit/Strafrecht'
        WHEN titel LIKE '%Sozial%' OR titel LIKE '%Rente%' OR titel LIKE '%Arbeitslos%' THEN 'Soziales/Rente'
        WHEN titel LIKE '%Bildung%' OR titel LIKE '%Schule%' OR titel LIKE '%Universität%' THEN 'Bildung'
        WHEN titel LIKE '%Gesundheit%' OR titel LIKE '%Pflege%' OR titel LIKE '%Kranken%' THEN 'Gesundheit/Pflege'
        WHEN titel LIKE '%Wirtschaft%' OR titel LIKE '%Unternehmen%' OR titel LIKE '%Steuer%' THEN 'Wirtschaft/Steuern'
        WHEN titel LIKE '%Migration%' OR titel LIKE '%Asyl%' OR titel LIKE '%Flüchtling%' OR titel LIKE '%Integration%' THEN 'Migration/Asyl'
        WHEN titel LIKE '%Digitalisierung%' OR titel LIKE '%Internet%' OR titel LIKE '%Datenschutz%' THEN 'Digitalisierung'
        WHEN titel LIKE '%Verkehr%' OR titel LIKE '%Bahn%' OR titel LIKE '%Mobilität%' THEN 'Verkehr/Mobilität'
        WHEN titel LIKE '%Verteidigung%' OR titel LIKE '%Bundeswehr%' OR titel LIKE '%NATO%' THEN 'Verteidigung'
        WHEN titel LIKE '%Kultur%' OR titel LIKE '%Medien%' OR titel LIKE '%Sport%' THEN 'Kultur/Medien/Sport'
        WHEN titel LIKE '%Landwirtschaft%' OR titel LIKE '%Ernährung%' THEN 'Landwirtschaft'
        WHEN titel LIKE '%Justiz%' OR titel LIKE '%Recht%' OR titel LIKE '%Verfahren%' OR titel LIKE '%Gerichts%' THEN 'Justiz/Recht'
        WHEN titel LIKE '%Familie%' OR titel LIKE '%Kinder%' OR titel LIKE '%Jugend%' THEN 'Familie/Jugend'
        WHEN titel LIKE '%Entwicklung%' OR titel LIKE '%Afrika%' THEN 'Entwicklungspolitik'
        WHEN titel LIKE '%Außenpolitik%' OR titel LIKE '%Menschenrechte%' THEN 'Außenpolitik'
        ELSE 'Sonstiges'
    END as policy_area,
    COUNT(*) as count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM joint_gesetze), 2) as pct
FROM joint_gesetze
GROUP BY policy_area
ORDER BY count DESC
LIMIT 20;

-- PART 10C: Temporal Evolution of Policy Areas
-- Shows how policy priorities changed over 50 years

WITH joint_docs AS (
    SELECT DISTINCT 
        d.id, 
        d.titel, 
        d.wahlperiode,
        d.drucksachetyp,
        CASE
            WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1970s-1980s'
            WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1987-1998'
            WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1998-2009'
            WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2009-2017'
            WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2017-2025'
        END as period
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp IN ('Antrag', 'Gesetzentwurf')
)
SELECT
    period,
    SUM(CASE WHEN titel LIKE '%Europa%' OR titel LIKE '%EU%' OR titel LIKE '%Europäisch%' THEN 1 ELSE 0 END) as Europa,
    SUM(CASE WHEN titel LIKE '%Sozial%' OR titel LIKE '%Rente%' OR titel LIKE '%Arbeitslos%' THEN 1 ELSE 0 END) as Soziales,
    SUM(CASE WHEN titel LIKE '%Klima%' OR titel LIKE '%Umwelt%' OR titel LIKE '%Energie%' THEN 1 ELSE 0 END) as Klima_Umwelt,
    SUM(CASE WHEN titel LIKE '%Sicherheit%' OR titel LIKE '%Polizei%' OR titel LIKE '%Terror%' OR titel LIKE '%Strafrecht%' THEN 1 ELSE 0 END) as Sicherheit,
    SUM(CASE WHEN titel LIKE '%Migration%' OR titel LIKE '%Asyl%' OR titel LIKE '%Flüchtling%' THEN 1 ELSE 0 END) as Migration,
    SUM(CASE WHEN titel LIKE '%Gesundheit%' OR titel LIKE '%Pflege%' OR titel LIKE '%Kranken%' THEN 1 ELSE 0 END) as Gesundheit,
    SUM(CASE WHEN titel LIKE '%Wirtschaft%' OR titel LIKE '%Steuer%' OR titel LIKE '%Unternehmen%' THEN 1 ELSE 0 END) as Wirtschaft,
    SUM(CASE WHEN titel LIKE '%Digitalisierung%' OR titel LIKE '%Internet%' OR titel LIKE '%Datenschutz%' THEN 1 ELSE 0 END) as Digital,
    COUNT(*) as total
FROM joint_docs
GROUP BY period
ORDER BY period;

-- PART 10D: Fraktion Pairs by Policy Area - Europa/EU
-- Shows which fraktionen collaborate on European integration

WITH joint_docs AS (
    SELECT DISTINCT 
        u1.titel as fraktion1,
        u2.titel as fraktion2,
        d.id
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp IN ('Antrag', 'Gesetzentwurf')
        AND (d.titel LIKE '%Europa%' OR d.titel LIKE '%EU%' OR d.titel LIKE '%Europäisch%')
)
SELECT fraktion1, fraktion2, COUNT(*) as europa_docs
FROM joint_docs
GROUP BY fraktion1, fraktion2
ORDER BY europa_docs DESC
LIMIT 10;

-- PART 10E: Fraktion Pairs by Policy Area - Klima/Umwelt/Energie
-- Shows which fraktionen collaborate on climate and environmental policy

WITH joint_docs AS (
    SELECT DISTINCT 
        u1.titel as fraktion1,
        u2.titel as fraktion2,
        d.id
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp IN ('Antrag', 'Gesetzentwurf')
        AND (d.titel LIKE '%Klima%' OR d.titel LIKE '%Umwelt%' OR d.titel LIKE '%Energie%')
)
SELECT fraktion1, fraktion2, COUNT(*) as klima_docs
FROM joint_docs
GROUP BY fraktion1, fraktion2
ORDER BY klima_docs DESC
LIMIT 10;

-- PART 10F: Fraktion Pairs by Policy Area - Soziales/Rente
-- Shows which fraktionen collaborate on social policy and pensions

WITH joint_docs AS (
    SELECT DISTINCT 
        u1.titel as fraktion1,
        u2.titel as fraktion2,
        d.id
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.drucksachetyp IN ('Antrag', 'Gesetzentwurf')
        AND (d.titel LIKE '%Sozial%' OR d.titel LIKE '%Rente%' OR d.titel LIKE '%Arbeitslos%')
)
SELECT fraktion1, fraktion2, COUNT(*) as sozial_docs
FROM joint_docs
GROUP BY fraktion1, fraktion2
ORDER BY sozial_docs DESC
LIMIT 10;
