-- ========================================
-- COMPREHENSIVE 50-YEAR FRAKTION COLLABORATION ANALYSIS
-- WP7-21 (1972-2025)
-- ========================================
-- This analysis examines how German parliamentary fraktionen (party groups)
-- have collaborated on joint initiatives over 50 years using vorgang_initiative data.
--
-- KEY FINDINGS:
-- - 46x growth in collaboration: 499 (1970s) → 23,105 (2017-2025)
-- - 64% of collaborations are cross-party/opposition, only 36% coalition partners
-- - Most collaborative pair: CDU/CSU + SPD (7,502 joint vorgänge, 20.2%)
-- - Ampel coalition (SPD/Grüne/FDP) conducted 188 three-way initiatives in WP20 before forming government
-- - AfD shows collaboration with all parties (not isolated in vorgang initiatives unlike drucksachen)
-- ========================================

-- PART 1: COLLABORATION TRENDS BY WAHLPERIODE
-- Shows joint initiatives, total fraktion initiatives, and percentage for each WP

WITH fraktion_initiatives AS (
    SELECT
        v.wahlperiode,
        vi.vorgang_id,
        vi.initiative
    FROM vorgang_initiative vi
    INNER JOIN vorgang v ON vi.vorgang_id = v.id
    WHERE vi.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 21
),
vorgang_fraktion_count AS (
    SELECT
        wahlperiode,
        vorgang_id,
        COUNT(DISTINCT initiative) as fraktion_count
    FROM fraktion_initiatives
    GROUP BY wahlperiode, vorgang_id
),
wp_years AS (
    SELECT 
        wahlperiode,
        CAST(SUBSTR(MIN(datum), 1, 4) AS INTEGER) as start_year,
        CAST(SUBSTR(MAX(datum), 1, 4) AS INTEGER) as end_year
    FROM vorgang
    WHERE wahlperiode BETWEEN 7 AND 21 AND datum IS NOT NULL
    GROUP BY wahlperiode
)
SELECT
    vfc.wahlperiode,
    wy.start_year || '-' || wy.end_year as years,
    COUNT(CASE WHEN fraktion_count >= 2 THEN 1 END) as joint_initiatives,
    COUNT(*) as total_fraktion_initiatives,
    ROUND(100.0 * COUNT(CASE WHEN fraktion_count >= 2 THEN 1 END) / COUNT(*), 2) as pct_joint,
    ROUND(1.0 * COUNT(CASE WHEN fraktion_count >= 2 THEN 1 END) / (wy.end_year - wy.start_year + 1), 1) as joint_per_year
FROM vorgang_fraktion_count vfc
LEFT JOIN wp_years wy ON vfc.wahlperiode = wy.wahlperiode
GROUP BY vfc.wahlperiode, wy.start_year, wy.end_year
ORDER BY vfc.wahlperiode;

-- PART 2: COLLABORATION BY DECADE WITH GROWTH RATES
-- Groups wahlperioden into decades and shows growth trends

WITH fraktion_initiatives AS (
    SELECT
        v.wahlperiode,
        CASE
            WHEN v.wahlperiode BETWEEN 7 AND 9 THEN '1970s-1980s (WP7-9)'
            WHEN v.wahlperiode BETWEEN 10 AND 12 THEN '1987-1998 (WP10-12)'
            WHEN v.wahlperiode BETWEEN 13 AND 15 THEN '1998-2009 (WP13-15)'
            WHEN v.wahlperiode BETWEEN 16 AND 18 THEN '2009-2017 (WP16-18)'
            WHEN v.wahlperiode BETWEEN 19 AND 21 THEN '2017-2025 (WP19-21)'
        END as period,
        vi.vorgang_id
    FROM vorgang_initiative vi
    INNER JOIN vorgang v ON vi.vorgang_id = v.id
    WHERE vi.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 21
),
vorgang_fraktion_count AS (
    SELECT
        period,
        vorgang_id,
        COUNT(*) as fraktion_count
    FROM fraktion_initiatives
    GROUP BY period, vorgang_id
    HAVING fraktion_count >= 2
),
period_stats AS (
    SELECT
        period,
        COUNT(*) as joint_initiatives,
        CASE period
            WHEN '1970s-1980s (WP7-9)' THEN 14
            WHEN '1987-1998 (WP10-12)' THEN 11
            WHEN '1998-2009 (WP13-15)' THEN 11
            WHEN '2009-2017 (WP16-18)' THEN 8
            WHEN '2017-2025 (WP19-21)' THEN 8
        END as years
    FROM vorgang_fraktion_count
    GROUP BY period
)
SELECT
    period,
    joint_initiatives,
    years,
    ROUND(1.0 * joint_initiatives / years, 1) as avg_per_year,
    ROUND(100.0 * (joint_initiatives - LAG(joint_initiatives) OVER (ORDER BY period)) / 
          LAG(joint_initiatives) OVER (ORDER BY period), 1) as growth_pct
FROM period_stats
ORDER BY period;

-- PART 3: TOP FRAKTION COLLABORATION PAIRS (1972-2025)
-- All-time ranking of which fraktion pairs have worked together most

WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 21
)
SELECT
    fraktion1,
    fraktion2,
    COUNT(*) as joint_vorgaenge,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fraktion_pairs), 2) as pct_of_total
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_vorgaenge DESC
LIMIT 15;

-- PART 4: COLLABORATION BY COALITION ERA
-- Shows how collaboration patterns varied under different governments

WITH coalition_mapping AS (
    SELECT 7 as wp, '1972-1976 SPD/FDP' as coalition_era
    UNION SELECT 8, '1976-1982 SPD/FDP'
    UNION SELECT 9, '1980-1983 SPD/FDP'
    UNION SELECT 10, '1983-1987 CDU/FDP'
    UNION SELECT 11, '1987-1990 CDU/FDP'
    UNION SELECT 12, '1990-1994 CDU/FDP'
    UNION SELECT 13, '1994-1998 CDU/FDP'
    UNION SELECT 14, '1998-2002 SPD/Grüne'
    UNION SELECT 15, '2002-2005 SPD/Grüne'
    UNION SELECT 16, '2005-2009 CDU/SPD (GroKo I)'
    UNION SELECT 17, '2009-2013 CDU/FDP'
    UNION SELECT 18, '2013-2017 CDU/SPD (GroKo II)'
    UNION SELECT 19, '2017-2021 CDU/SPD (GroKo III)'
    UNION SELECT 20, '2017-2021 CDU/SPD (GroKo III)'
    UNION SELECT 21, '2021-2025 SPD/Grüne/FDP (Ampel)'
),
fraktion_initiatives AS (
    SELECT
        v.wahlperiode,
        vi.vorgang_id,
        vi.initiative
    FROM vorgang_initiative vi
    INNER JOIN vorgang v ON vi.vorgang_id = v.id
    WHERE vi.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 21
),
vorgang_fraktion_count AS (
    SELECT
        wahlperiode,
        vorgang_id,
        COUNT(DISTINCT initiative) as fraktion_count
    FROM fraktion_initiatives
    GROUP BY wahlperiode, vorgang_id
)
SELECT
    cm.coalition_era,
    COUNT(CASE WHEN vfc.fraktion_count >= 2 THEN 1 END) as joint_initiatives,
    COUNT(*) as total_fraktion_initiatives,
    ROUND(100.0 * COUNT(CASE WHEN vfc.fraktion_count >= 2 THEN 1 END) / COUNT(*), 2) as pct_joint
FROM vorgang_fraktion_count vfc
INNER JOIN coalition_mapping cm ON vfc.wahlperiode = cm.wp
GROUP BY cm.coalition_era
ORDER BY cm.coalition_era;

-- PART 5: TOP COLLABORATION PAIRS BY ERA
-- Breaking down collaboration patterns into historical periods

-- 1972-1998: Social-Liberal & Kohl Era
WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 13
)
SELECT
    '1972-1998: Social-Liberal & Kohl Era (WP7-13)' as era,
    fraktion1,
    fraktion2,
    COUNT(*) as joint_vorgaenge
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_vorgaenge DESC
LIMIT 8;

-- 1998-2009: Red-Green Era
WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 14 AND 16
)
SELECT
    '1998-2009: Red-Green Era (WP14-16)' as era,
    fraktion1,
    fraktion2,
    COUNT(*) as joint_vorgaenge
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_vorgaenge DESC
LIMIT 8;

-- 2009-2017: Merkel Era II
WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 17 AND 18
)
SELECT
    '2009-2017: Merkel Era II (WP17-18)' as era,
    fraktion1,
    fraktion2,
    COUNT(*) as joint_vorgaenge
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_vorgaenge DESC
LIMIT 8;

-- 2017-2025: Recent Era
WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 19 AND 21
)
SELECT
    '2017-2025: Recent Era (WP19-21)' as era,
    fraktion1,
    fraktion2,
    COUNT(*) as joint_vorgaenge
FROM fraktion_pairs
GROUP BY fraktion1, fraktion2
ORDER BY joint_vorgaenge DESC
LIMIT 10;

-- PART 6: AFD COLLABORATION PATTERN (Since WP19, 2017)
-- AfD shows collaboration in vorgang initiatives (unlike drucksachen where isolated)

WITH fraktion_pairs AS (
    SELECT
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 19 AND 21
        AND (vi1.initiative = 'Fraktion der AfD' OR vi2.initiative = 'Fraktion der AfD')
)
SELECT
    CASE
        WHEN fraktion1 = 'Fraktion der AfD' THEN fraktion2
        ELSE fraktion1
    END as other_fraktion,
    COUNT(*) as joint_with_afd,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM fraktion_pairs), 2) as pct_of_afd_collaborations
FROM fraktion_pairs
GROUP BY other_fraktion
ORDER BY joint_with_afd DESC;

-- PART 7: COLLABORATION BY VORGANGSTYP
-- What types of parliamentary procedures see most collaboration

WITH fraktion_initiatives AS (
    SELECT
        v.vorgangstyp,
        vi.vorgang_id
    FROM vorgang_initiative vi
    INNER JOIN vorgang v ON vi.vorgang_id = v.id
    WHERE vi.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 21
),
vorgang_fraktion_count AS (
    SELECT
        vorgangstyp,
        vorgang_id,
        COUNT(*) as fraktion_count
    FROM fraktion_initiatives
    GROUP BY vorgangstyp, vorgang_id
    HAVING fraktion_count >= 2
)
SELECT
    vorgangstyp,
    COUNT(*) as joint_initiatives
FROM vorgang_fraktion_count
GROUP BY vorgangstyp
ORDER BY joint_initiatives DESC
LIMIT 10;

-- PART 8: COALITION VS OPPOSITION COLLABORATION PATTERN
-- Reveals that 64% of collaborations are cross-party, not coalition partners

WITH coalition_pairs AS (
    SELECT 7 as wp, 'Fraktion der SPD' as f1, 'Fraktion der FDP' as f2
    UNION SELECT 8, 'Fraktion der SPD', 'Fraktion der FDP'
    UNION SELECT 9, 'Fraktion der SPD', 'Fraktion der FDP'
    UNION SELECT 10, 'Fraktion der CDU/CSU', 'Fraktion der FDP'
    UNION SELECT 11, 'Fraktion der CDU/CSU', 'Fraktion der FDP'
    UNION SELECT 12, 'Fraktion der CDU/CSU', 'Fraktion der FDP'
    UNION SELECT 13, 'Fraktion der CDU/CSU', 'Fraktion der FDP'
    UNION SELECT 14, 'Fraktion der SPD', 'Fraktion BÜNDNIS 90/DIE GRÜNEN'
    UNION SELECT 15, 'Fraktion der SPD', 'Fraktion BÜNDNIS 90/DIE GRÜNEN'
    UNION SELECT 16, 'Fraktion der CDU/CSU', 'Fraktion der SPD'
    UNION SELECT 17, 'Fraktion der CDU/CSU', 'Fraktion der FDP'
    UNION SELECT 18, 'Fraktion der CDU/CSU', 'Fraktion der SPD'
    UNION SELECT 19, 'Fraktion der CDU/CSU', 'Fraktion der SPD'
    UNION SELECT 20, 'Fraktion der CDU/CSU', 'Fraktion der SPD'
),
fraktion_pairs AS (
    SELECT
        v.wahlperiode,
        vi1.initiative as fraktion1,
        vi2.initiative as fraktion2
    FROM vorgang_initiative vi1
    INNER JOIN vorgang_initiative vi2 ON vi1.vorgang_id = vi2.vorgang_id
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative < vi2.initiative
        AND vi1.initiative LIKE 'Fraktion%'
        AND vi2.initiative LIKE 'Fraktion%'
        AND v.wahlperiode BETWEEN 7 AND 20
),
categorized AS (
    SELECT
        fp.wahlperiode,
        fp.fraktion1,
        fp.fraktion2,
        CASE
            WHEN EXISTS (
                SELECT 1 FROM coalition_pairs cp 
                WHERE cp.wp = fp.wahlperiode 
                AND ((cp.f1 = fp.fraktion1 AND cp.f2 = fp.fraktion2)
                     OR (cp.f1 = fp.fraktion2 AND cp.f2 = fp.fraktion1))
            ) THEN 'Coalition Partners'
            ELSE 'Cross-Party/Opposition'
        END as collaboration_type
    FROM fraktion_pairs fp
)
SELECT
    collaboration_type,
    COUNT(*) as joint_vorgaenge,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM categorized), 2) as pct
FROM categorized
GROUP BY collaboration_type
ORDER BY joint_vorgaenge DESC;

-- PART 9: AMPEL PRE-COALITION PATTERN
-- SPD/Grüne/FDP conducted 188 three-way initiatives in WP20 before forming coalition

WITH fraktion_triples AS (
    SELECT
        v.wahlperiode,
        vi1.vorgang_id,
        COUNT(DISTINCT vi1.initiative) as fraktion_count
    FROM vorgang_initiative vi1
    INNER JOIN vorgang v ON vi1.vorgang_id = v.id
    WHERE vi1.initiative IN ('Fraktion der SPD', 'Fraktion BÜNDNIS 90/DIE GRÜNEN', 'Fraktion der FDP')
        AND v.wahlperiode BETWEEN 16 AND 21
    GROUP BY v.wahlperiode, vi1.vorgang_id
    HAVING fraktion_count = 3
)
SELECT
    wahlperiode,
    CASE wahlperiode
        WHEN 16 THEN 'GroKo I (CDU/SPD)'
        WHEN 17 THEN 'CDU/FDP'
        WHEN 18 THEN 'GroKo II (CDU/SPD)'
        WHEN 19 THEN 'GroKo III (CDU/SPD)'
        WHEN 20 THEN 'GroKo III (CDU/SPD)'
        WHEN 21 THEN 'Ampel (SPD/Grüne/FDP) - IN POWER'
    END as government,
    COUNT(*) as all_three_ampel_fraktionen_together
FROM fraktion_triples
GROUP BY wahlperiode
ORDER BY wahlperiode;
