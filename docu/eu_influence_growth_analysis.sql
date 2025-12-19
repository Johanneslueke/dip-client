-- EU Influence Growth Analysis (WP7-21: 1972-2025)
-- Analyzes how EU legislative influence on German Bundestag has evolved over 50+ years
-- Tracks EU-Vorlage trends across wahlperioden and historical EU integration milestones

-- ==============================================================================
-- 1. EU-VORLAGE TRENDS BY WAHLPERIODE (WP7-21)
-- ==============================================================================
-- Shows absolute counts and percentage of total parliamentary activity per wahlperiode

SELECT 'EU-Vorlage Trends by Wahlperiode (WP7-21)' as analysis;

SELECT 
    wahlperiode,
    COUNT(*) as eu_vorlage_count,
    (SELECT COUNT(*) FROM vorgang v2 WHERE v2.wahlperiode = v.wahlperiode) as total_vorgaenge,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM vorgang v2 WHERE v2.wahlperiode = v.wahlperiode), 2) as pct_of_wp
FROM vorgang v
WHERE vorgangstyp = 'EU-Vorlage'
    AND wahlperiode >= 7
GROUP BY wahlperiode
ORDER BY wahlperiode;


-- ==============================================================================
-- 2. DECADE COMPARISON (1970s-2020s)
-- ==============================================================================
-- Aggregates by decade groupings to show long-term trends

SELECT '' as spacer;
SELECT 'EU-Vorlage as Share of Parliamentary Activity by Decade (WP7-21)' as analysis;

SELECT 
    CASE 
        WHEN wahlperiode IN (7, 8, 9) THEN '1970s-1980s (WP7-9)'
        WHEN wahlperiode IN (10, 11, 12) THEN '1990s (WP10-12)'
        WHEN wahlperiode IN (13, 14, 15) THEN '2000s (WP13-15)'
        WHEN wahlperiode IN (16, 17, 18) THEN '2010s (WP16-18)'
        WHEN wahlperiode IN (19, 20, 21) THEN '2020s (WP19-21)'
    END as decade,
    SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) as eu_vorlage_count,
    COUNT(*) as total_vorgaenge,
    ROUND(100.0 * SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) / COUNT(*), 2) as eu_pct,
    ROUND(SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) * 1.0 / COUNT(DISTINCT wahlperiode), 1) as avg_per_wp
FROM vorgang
WHERE wahlperiode >= 7
GROUP BY decade
ORDER BY decade;


-- ==============================================================================
-- 3. EU INTEGRATION MILESTONES IMPACT
-- ==============================================================================
-- Groups by major EU treaty milestones to show policy impact
-- Maastricht (1993), Euro (1999), Lisbon (2009)

SELECT '' as spacer;
SELECT 'EU Integration Milestones Impact' as analysis;

SELECT 
    CASE 
        WHEN wahlperiode IN (7, 8, 9, 10) THEN 'Pre-Maastricht (WP7-10, 1972-1994)'
        WHEN wahlperiode IN (11, 12, 13, 14) THEN 'Post-Maastricht/Euro (WP11-14, 1994-2009)'
        WHEN wahlperiode IN (15, 16, 17) THEN 'Post-Lisbon (WP15-17, 2009-2017)'
        WHEN wahlperiode IN (18, 19, 20, 21) THEN 'Recent (WP18-21, 2013-2025)'
    END as period,
    SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) as eu_vorlage_count,
    COUNT(*) as total_vorgaenge,
    ROUND(100.0 * SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) / COUNT(*), 2) as eu_pct
FROM vorgang
WHERE wahlperiode >= 7
GROUP BY period
ORDER BY MIN(wahlperiode);


-- ==============================================================================
-- 4. GROWTH RATES BETWEEN WAHLPERIODEN
-- ==============================================================================
-- Shows year-over-year change and percentage growth between consecutive wahlperioden

SELECT '' as spacer;
SELECT 'EU-Vorlage Growth Between Wahlperioden (WP7-21)' as analysis;

WITH wp_counts AS (
    SELECT 
        wahlperiode,
        COUNT(*) as eu_vorlage_count
    FROM vorgang
    WHERE vorgangstyp = 'EU-Vorlage'
        AND wahlperiode >= 7
    GROUP BY wahlperiode
)
SELECT 
    wahlperiode,
    eu_vorlage_count,
    LAG(eu_vorlage_count) OVER (ORDER BY wahlperiode) as prev_wp,
    eu_vorlage_count - LAG(eu_vorlage_count) OVER (ORDER BY wahlperiode) as change,
    ROUND(100.0 * (eu_vorlage_count - LAG(eu_vorlage_count) OVER (ORDER BY wahlperiode)) / NULLIF(LAG(eu_vorlage_count) OVER (ORDER BY wahlperiode), 0), 1) as pct_change
FROM wp_counts
ORDER BY wahlperiode;


-- ==============================================================================
-- 5. WAHLPERIODE DURATION AND NORMALIZED ANNUAL RATES
-- ==============================================================================
-- Accounts for different wahlperiode lengths to calculate per-year rates

SELECT '' as spacer;
SELECT 'Wahlperiode Duration and Years' as analysis;

SELECT 
    wahlperiode,
    MIN(SUBSTR(datum, 1, 4)) as start_year,
    MAX(SUBSTR(datum, 1, 4)) as end_year,
    COUNT(DISTINCT SUBSTR(datum, 1, 4)) as years_span,
    COUNT(*) as total_vorgaenge,
    SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) as eu_vorlage_count,
    ROUND(SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) * 1.0 / NULLIF(COUNT(DISTINCT SUBSTR(datum, 1, 4)), 0), 1) as eu_vorlage_per_year
FROM vorgang
WHERE wahlperiode >= 7
    AND datum IS NOT NULL
    AND datum != ''
GROUP BY wahlperiode
ORDER BY wahlperiode;


-- ==============================================================================
-- 6. NORMALIZED DECADE COMPARISON (EU-VORLAGE PER YEAR)
-- ==============================================================================
-- Annual rate comparison across decades for fair comparison

SELECT '' as spacer;
SELECT 'EU-Vorlage Annual Rate by Decade (Normalized)' as analysis;

SELECT 
    CASE 
        WHEN wahlperiode IN (7, 8, 9) THEN '1970s-1980s (WP7-9)'
        WHEN wahlperiode IN (10, 11, 12) THEN '1990s (WP10-12)'
        WHEN wahlperiode IN (13, 14, 15) THEN '2000s (WP13-15)'
        WHEN wahlperiode IN (16, 17, 18) THEN '2010s (WP16-18)'
        WHEN wahlperiode IN (19, 20, 21) THEN '2020s (WP19-21)'
    END as decade,
    SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) as total_eu_vorlage,
    COUNT(DISTINCT SUBSTR(datum, 1, 4)) as total_years,
    ROUND(SUM(CASE WHEN vorgangstyp = 'EU-Vorlage' THEN 1 ELSE 0 END) * 1.0 / NULLIF(COUNT(DISTINCT SUBSTR(datum, 1, 4)), 0), 1) as eu_vorlage_per_year
FROM vorgang
WHERE wahlperiode >= 7
    AND datum IS NOT NULL
    AND datum != ''
GROUP BY decade
ORDER BY decade;
