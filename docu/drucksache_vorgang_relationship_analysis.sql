-- ========================================
-- DRUCKSACHE-VORGANG RELATIONSHIP ANALYSIS
-- Understanding the connection between formal documents and legislative procedures
-- ========================================
-- This analysis examines how Drucksachen (formal documents) relate to Vorgänge
-- (legislative procedures) through the drucksache_vorgangsbezug linking table.
--
-- KEY FINDINGS:
-- - 98.11% of Drucksachen link to at least one Vorgang
-- - 28.95% of Vorgänge have linked Drucksachen
-- - Joint vorgang initiatives rarely produce joint drucksachen (7.14%)
-- - Joint drucksachen almost always link to vorgänge (97.42%)
-- - Reveals procedural inclusion vs policy partnership distinction
-- ========================================

-- PART 1: Basic Coverage Statistics
-- Shows what percentage of drucksachen and vorgänge are linked

SELECT 
    'Total drucksachen' as metric,
    COUNT(*) as count,
    '-' as with_link,
    '-' as pct
FROM drucksache
UNION ALL
SELECT 
    'Drucksachen WITH vorgang links',
    COUNT(DISTINCT drucksache_id),
    COUNT(DISTINCT drucksache_id),
    ROUND(100.0 * COUNT(DISTINCT drucksache_id) / (SELECT COUNT(*) FROM drucksache), 2) || '%'
FROM drucksache_vorgangsbezug
UNION ALL
SELECT 
    'Total vorgänge',
    COUNT(*),
    '-',
    '-'
FROM vorgang
UNION ALL
SELECT 
    'Vorgänge WITH drucksache links',
    COUNT(DISTINCT dv.vorgang_id),
    COUNT(DISTINCT dv.vorgang_id),
    ROUND(100.0 * COUNT(DISTINCT dv.vorgang_id) / (SELECT COUNT(*) FROM vorgang), 2) || '%'
FROM drucksache_vorgangsbezug dv;

-- PART 2: Links Per Drucksache Distribution
-- Shows how many vorgänge each drucksache typically links to

SELECT 
    vorgaenge_count,
    COUNT(*) as drucksachen,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct
FROM (
    SELECT drucksache_id, COUNT(*) as vorgaenge_count
    FROM drucksache_vorgangsbezug
    GROUP BY drucksache_id
)
GROUP BY vorgaenge_count
ORDER BY vorgaenge_count
LIMIT 15;

-- PART 3: Linkage Rates by Drucksachetyp
-- Shows which document types link to vorgänge

SELECT 
    d.drucksachetyp,
    COUNT(DISTINCT d.id) as total_drucksachen,
    COUNT(DISTINCT dv.drucksache_id) as with_vorgang,
    ROUND(100.0 * COUNT(DISTINCT dv.drucksache_id) / COUNT(DISTINCT d.id), 2) as pct_with_vorgang
FROM drucksache d
LEFT JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
GROUP BY d.drucksachetyp
ORDER BY total_drucksachen DESC
LIMIT 15;

-- PART 4: Joint Fraktion Drucksachen - Vorgang Linkages
-- Do joint fraktion drucksachen link to vorgänge?

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
    COUNT(DISTINCT jd.drucksache_id) as joint_fraktion_drucksachen,
    COUNT(DISTINCT dv.drucksache_id) as with_vorgang_link,
    ROUND(100.0 * COUNT(DISTINCT dv.drucksache_id) / COUNT(DISTINCT jd.drucksache_id), 2) as pct_linked
FROM joint_drucksachen jd
LEFT JOIN drucksache_vorgangsbezug dv ON jd.drucksache_id = dv.drucksache_id;

-- PART 5: Vorgangstypen from Joint Fraktion Drucksachen
-- What kinds of procedures do joint drucksachen link to?

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
    dv.vorgangstyp,
    COUNT(DISTINCT dv.drucksache_id) as drucksachen,
    COUNT(*) as total_links,
    ROUND(100.0 * COUNT(DISTINCT dv.drucksache_id) / (SELECT COUNT(*) FROM joint_drucksachen), 2) as pct_of_joint
FROM joint_drucksachen jd
INNER JOIN drucksache_vorgangsbezug dv ON jd.drucksache_id = dv.drucksache_id
GROUP BY dv.vorgangstyp
ORDER BY drucksachen DESC
LIMIT 15;

-- PART 6: Reverse Relationship - Joint Vorgänge to Drucksachen
-- Do joint vorgang initiatives produce drucksachen?

WITH joint_vorgaenge AS (
    SELECT DISTINCT vi1.vorgang_id
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    WHERE vi1.id < vi2.id
        AND (vi1.initiative LIKE '%Fraktion%' AND vi2.initiative LIKE '%Fraktion%')
)
SELECT 
    COUNT(DISTINCT jv.vorgang_id) as joint_initiative_vorgaenge,
    COUNT(DISTINCT dv.drucksache_id) as linked_drucksachen,
    ROUND(COUNT(DISTINCT dv.drucksache_id) * 1.0 / COUNT(DISTINCT jv.vorgang_id), 2) as drucksachen_per_vorgang
FROM joint_vorgaenge jv
LEFT JOIN drucksache_vorgangsbezug dv ON jv.vorgang_id = dv.vorgang_id;

-- PART 7: Critical Finding - Collaboration Discontinuity
-- How many drucksachen from joint vorgänge are ALSO joint fraktion?

WITH joint_vorgaenge AS (
    SELECT DISTINCT vi1.vorgang_id
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    WHERE vi1.id < vi2.id
        AND (vi1.initiative LIKE '%Fraktion%' AND vi2.initiative LIKE '%Fraktion%')
),
vorgang_drucksachen AS (
    SELECT DISTINCT dv.drucksache_id
    FROM joint_vorgaenge jv
    INNER JOIN drucksache_vorgangsbezug dv ON jv.vorgang_id = dv.vorgang_id
),
joint_drucksachen AS (
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
    COUNT(DISTINCT vd.drucksache_id) as drucksachen_from_joint_vorgaenge,
    COUNT(DISTINCT jd.drucksache_id) as also_joint_fraktion_authorship,
    ROUND(100.0 * COUNT(DISTINCT jd.drucksache_id) / COUNT(DISTINCT vd.drucksache_id), 2) as pct_joint_continuity
FROM vorgang_drucksachen vd
LEFT JOIN joint_drucksachen jd ON vd.drucksache_id = jd.drucksache_id;

-- PART 8: Sample Relationships
-- Concrete examples of joint drucksachen and their linked vorgänge

WITH joint_drucksachen AS (
    SELECT DISTINCT 
        d.id,
        d.titel as drucksache_titel,
        d.drucksachetyp,
        d.wahlperiode
    FROM drucksache d
    INNER JOIN drucksache_urheber du1 ON d.id = du1.drucksache_id
    INNER JOIN drucksache_urheber du2 ON d.id = du2.drucksache_id
    INNER JOIN urheber u1 ON du1.urheber_id = u1.id
    INNER JOIN urheber u2 ON du2.urheber_id = u2.id
    WHERE du1.urheber_id < du2.urheber_id
        AND u1.titel LIKE 'Fraktion%'
        AND u2.titel LIKE 'Fraktion%'
        AND d.wahlperiode >= 20
)
SELECT 
    jd.wahlperiode,
    jd.drucksachetyp,
    dv.vorgangstyp,
    jd.drucksache_titel
FROM joint_drucksachen jd
INNER JOIN drucksache_vorgangsbezug dv ON jd.id = dv.drucksache_id
WHERE jd.drucksachetyp = 'Gesetzentwurf'
LIMIT 15;

-- PART 9: Summary Statistics
-- Consolidated view of key metrics

SELECT 
    'Drucksachen coverage' as metric,
    '98.11% link to vorgänge' as value
UNION ALL
SELECT 
    'Vorgänge coverage',
    '28.95% have drucksachen'
UNION ALL
SELECT 
    'Typical relationship',
    '93% drucksachen link to exactly 1 vorgang'
UNION ALL
SELECT 
    'Joint vorgang initiatives',
    '44,285 total'
UNION ALL
SELECT 
    'Drucksachen from joint vorgänge',
    '54,770 (avg 1.24 per vorgang)'
UNION ALL
SELECT 
    'Joint continuity rate',
    'Only 7.14% also joint fraktion drucksachen'
UNION ALL
SELECT 
    'Joint fraktion drucksachen',
    '4,231 total'
UNION ALL
SELECT 
    'Link to vorgänge',
    '97.42% (4,122 drucksachen)'
UNION ALL
SELECT 
    'Most common vorgang type',
    'Antrag (38.15%) and Gesetzgebung (32.45%)';
