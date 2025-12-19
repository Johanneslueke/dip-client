-- ============================================================================
-- RESEARCH QUESTION #9: HOW HAS PARLIAMENTARY OVERSIGHT EVOLVED?
-- Analysis of 50 Years of Parliamentary Questions (1972-2025)
-- ============================================================================
-- Context: From RQ1 we learned that questions represent 60% of all vorgang
-- volume (248,577 out of 414,296 vorgänge). This analysis examines the
-- evolution of parliamentary oversight through Kleine Anfragen and 
-- Große Anfragen across Wahlperioden 7-21.
--
-- Key Data Structure:
-- - aktivitaet records individual participation in questions
-- - drucksache contains the actual question text (titel field)
-- - vorgang serves as procedural container
-- - Linkage: aktivitaet → vorgang → drucksache
--
-- From RQ7 we know: Opposition files 83% of questions in WP21
-- (AfD 3,233, Die Linke 1,691 vs SPD 0, CDU/CSU 0)
-- ============================================================================

-- ============================================================================
-- PART 1: BASELINE - Question Volume Over 50 Years
-- ============================================================================
-- How has the use of parliamentary questions evolved?
-- Compare Kleine Anfragen (routine oversight) vs Große Anfragen (major inquiries)

-- 1A: Total Question Volume by Wahlperiode
SELECT 
    wahlperiode,
    COUNT(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN 1 END) as kleine_anfragen,
    COUNT(CASE WHEN aktivitaetsart = 'Große Anfrage' THEN 1 END) as grosse_anfragen,
    COUNT(CASE WHEN aktivitaetsart = 'Frage' THEN 1 END) as einzelfragen,
    COUNT(*) as total_questions,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as pct_of_total
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage', 'Frage')
AND wahlperiode BETWEEN 7 AND 21
GROUP BY wahlperiode
ORDER BY wahlperiode;

-- 1B: Question Growth Rate by Decade
SELECT 
    CASE 
        WHEN wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    COUNT(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN 1 END) as kleine_anfragen,
    COUNT(CASE WHEN aktivitaetsart = 'Große Anfrage' THEN 1 END) as grosse_anfragen,
    COUNT(*) as total_questions,
    ROUND(AVG(CASE WHEN aktivitaetsart = 'Kleine Anfrage' THEN 1.0 ELSE 0.0 END) * 100, 2) as pct_kleine
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- 1C: Questions per Drucksache (shows group question pattern)
-- Multiple aktivitaeten can link to same question drucksache (co-signers)
SELECT 
    d.wahlperiode,
    d.drucksachetyp,
    COUNT(DISTINCT d.id) as unique_drucksachen,
    COUNT(DISTINCT a.id) as total_aktivitaeten,
    ROUND(CAST(COUNT(DISTINCT a.id) AS FLOAT) / COUNT(DISTINCT d.id), 2) as avg_cosigners_per_question
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN aktivitaet_vorgangsbezug av ON dv.vorgang_id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
AND a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
GROUP BY d.wahlperiode, d.drucksachetyp
ORDER BY d.wahlperiode, d.drucksachetyp;

-- ============================================================================
-- PART 2: TOPIC ANALYSIS - What Are They Asking About?
-- ============================================================================
-- Use keyword extraction from drucksache.titel to categorize question topics
-- Similar methodology to Part 5a policy content analysis from RQ2

-- 2A: Foreign Policy Questions (Außenpolitik)
SELECT 
    CASE 
        WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Europa%' OR d.titel LIKE '%EU-%' OR d.titel LIKE '%Europäisch%' THEN d.id END) as europa_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%USA%' OR d.titel LIKE '%Amerika%' OR d.titel LIKE '%Vereinigte Staaten%' THEN d.id END) as usa_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Russland%' OR d.titel LIKE '%Sowjet%' OR d.titel LIKE '%UdSSR%' THEN d.id END) as russia_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%China%' OR d.titel LIKE '%chinesisch%' THEN d.id END) as china_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Ukraine%' THEN d.id END) as ukraine_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Afghanistan%' THEN d.id END) as afghanistan_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Syrien%' OR d.titel LIKE '%Nahost%' OR d.titel LIKE '%Israel%' THEN d.id END) as middle_east_questions,
    COUNT(DISTINCT d.id) as total_questions,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN d.titel LIKE '%Europa%' OR d.titel LIKE '%EU-%' OR d.titel LIKE '%Europäisch%' THEN d.id END) AS FLOAT) / COUNT(DISTINCT d.id) * 100, 2) as pct_europa
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- 2B: Domestic Policy Questions (Innenpolitik)
SELECT 
    CASE 
        WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Migration%' OR d.titel LIKE '%Asyl%' OR d.titel LIKE '%Flüchtling%' OR d.titel LIKE '%Abschiebung%' THEN d.id END) as migration_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Klima%' OR d.titel LIKE '%Umwelt%' OR d.titel LIKE '%Energie%' OR d.titel LIKE '%CO2%' THEN d.id END) as climate_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Sicherheit%' OR d.titel LIKE '%Polizei%' OR d.titel LIKE '%Terror%' OR d.titel LIKE '%Verfassungsschutz%' THEN d.id END) as security_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Wirtschaft%' OR d.titel LIKE '%Unternehmen%' OR d.titel LIKE '%Industrie%' THEN d.id END) as economy_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Sozial%' OR d.titel LIKE '%Rente%' OR d.titel LIKE '%Arbeitslos%' OR d.titel LIKE '%Hartz%' THEN d.id END) as social_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Gesundheit%' OR d.titel LIKE '%Pflege%' OR d.titel LIKE '%Corona%' OR d.titel LIKE '%Covid%' THEN d.id END) as health_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Bildung%' OR d.titel LIKE '%Schule%' OR d.titel LIKE '%Universität%' THEN d.id END) as education_questions,
    COUNT(DISTINCT d.id) as total_questions
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- 2C: Procedural/Administrative Questions (Regierungskontrolle)
SELECT 
    CASE 
        WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Haushalt%' OR d.titel LIKE '%Budget%' OR d.titel LIKE '%Einzelplan%' THEN d.id END) as budget_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Bundesregierung%' OR d.titel LIKE '%Minister%' OR d.titel LIKE '%Behörde%' THEN d.id END) as government_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Bundestag%' OR d.titel LIKE '%Abgeordnete%' OR d.titel LIKE '%Fraktion%' THEN d.id END) as parliament_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Bundeswehr%' OR d.titel LIKE '%Militär%' OR d.titel LIKE '%Verteidigung%' THEN d.id END) as military_questions,
    COUNT(DISTINCT d.id) as total_questions
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- 2D: Topic Overlap - Multi-Issue Questions
-- Questions that mention multiple policy areas (complex inquiries)
SELECT 
    d.wahlperiode,
    COUNT(DISTINCT d.id) as total_questions,
    COUNT(DISTINCT CASE 
        WHEN (d.titel LIKE '%Europa%' OR d.titel LIKE '%EU-%') 
        AND (d.titel LIKE '%Migration%' OR d.titel LIKE '%Asyl%') 
        THEN d.id 
    END) as europa_migration_overlap,
    COUNT(DISTINCT CASE 
        WHEN (d.titel LIKE '%Klima%' OR d.titel LIKE '%Umwelt%') 
        AND (d.titel LIKE '%Wirtschaft%' OR d.titel LIKE '%Industrie%') 
        THEN d.id 
    END) as climate_economy_overlap,
    COUNT(DISTINCT CASE 
        WHEN (d.titel LIKE '%Sicherheit%' OR d.titel LIKE '%Terror%') 
        AND (d.titel LIKE '%Migration%' OR d.titel LIKE '%Asyl%') 
        THEN d.id 
    END) as security_migration_overlap
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY d.wahlperiode
ORDER BY d.wahlperiode;

-- ============================================================================
-- PART 3: FRAKTION QUESTIONING PATTERNS
-- ============================================================================
-- Who is using oversight tools? Opposition vs government patterns

-- 3A: Questions by Fraktion and Wahlperiode
-- Extract fraktion from aktivitaet.titel using the "Name, MdB, FRAKTION" pattern
SELECT 
    a.wahlperiode,
    -- Extract fraktion from titel (after last comma)
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' OR a.titel LIKE '%PDS%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        WHEN a.titel LIKE '%fraktionslos%' THEN 'fraktionslos'
        ELSE 'Sonstige'
    END as fraktion,
    COUNT(*) as total_aktivitaeten,
    COUNT(DISTINCT av.vorgang_id) as unique_questions,
    ROUND(CAST(COUNT(*) AS FLOAT) / COUNT(DISTINCT av.vorgang_id), 2) as avg_cosigners
FROM aktivitaet a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND a.wahlperiode BETWEEN 7 AND 21
GROUP BY a.wahlperiode, fraktion
ORDER BY a.wahlperiode, total_aktivitaeten DESC;

-- 3B: Opposition vs Government Questioning (WP19-21 focus)
-- Define government coalitions:
-- WP19: CDU/CSU + SPD (Grand Coalition)
-- WP20: SPD + GRÜNE + FDP (Traffic Light Coalition)
-- WP21: Current (assume SPD + GRÜNE + FDP continuing)
SELECT 
    a.wahlperiode,
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
        ELSE 'Sonstige'
    END as fraktion,
    CASE 
        WHEN a.wahlperiode = 19 AND a.titel LIKE '%AfD%' THEN 'Opposition'
        WHEN a.wahlperiode = 19 AND (a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%') THEN 'Opposition'
        WHEN a.wahlperiode = 19 AND (a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%') THEN 'Opposition'
        WHEN a.wahlperiode = 19 AND a.titel LIKE '%FDP%' THEN 'Opposition'
        WHEN a.wahlperiode = 19 AND (a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' OR a.titel LIKE '%SPD%') THEN 'Government'
        WHEN a.wahlperiode >= 20 AND a.titel LIKE '%AfD%' THEN 'Opposition'
        WHEN a.wahlperiode >= 20 AND (a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%') THEN 'Opposition'
        WHEN a.wahlperiode >= 20 AND (a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%') THEN 'Opposition'
        WHEN a.wahlperiode >= 20 AND (a.titel LIKE '%SPD%' OR a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%FDP%') THEN 'Government'
        ELSE 'Unknown'
    END as coalition_role,
    COUNT(DISTINCT av.vorgang_id) as unique_questions
FROM aktivitaet a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND a.wahlperiode BETWEEN 19 AND 21
GROUP BY a.wahlperiode, fraktion, coalition_role
ORDER BY a.wahlperiode, unique_questions DESC;

-- 3C: Cross-Party Question Coalitions
-- Do fraktionen co-sign questions across party lines?
-- Similar to collaboration analysis but for oversight function
SELECT 
    d.wahlperiode,
    GROUP_CONCAT(DISTINCT CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'LINKE'
        WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END) as fraktion_coalition,
    COUNT(DISTINCT d.id) as joint_questions
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN aktivitaet_vorgangsbezug av ON dv.vorgang_id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY d.wahlperiode, d.id
HAVING COUNT(DISTINCT CASE 
    WHEN a.titel LIKE '%AfD%' THEN 'AfD'
    WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'LINKE'
    WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
    WHEN a.titel LIKE '%SPD%' THEN 'SPD'
    WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
    WHEN a.titel LIKE '%FDP%' THEN 'FDP'
END) > 1
ORDER BY d.wahlperiode, joint_questions DESC;

-- ============================================================================
-- PART 4: GOVERNMENT RESPONSE PATTERNS
-- ============================================================================
-- How does government respond to parliamentary questions?
-- Link Kleine Anfrage to corresponding Antwort aktivitaeten

-- 4A: Response Rate by Wahlperiode
SELECT 
    a_frage.wahlperiode,
    COUNT(DISTINCT CASE WHEN a_frage.aktivitaetsart = 'Kleine Anfrage' THEN av_frage.vorgang_id END) as kleine_anfragen_total,
    COUNT(DISTINCT CASE WHEN a_antwort.aktivitaetsart = 'Antwort' THEN av_antwort.vorgang_id END) as antworten_total,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN a_antwort.aktivitaetsart = 'Antwort' THEN av_antwort.vorgang_id END) AS FLOAT) / 
          COUNT(DISTINCT CASE WHEN a_frage.aktivitaetsart = 'Kleine Anfrage' THEN av_frage.vorgang_id END) * 100, 2) as response_rate_pct
FROM aktivitaet a_frage
INNER JOIN aktivitaet_vorgangsbezug av_frage ON a_frage.id = av_frage.aktivitaet_id
LEFT JOIN aktivitaet_vorgangsbezug av_antwort ON av_frage.vorgang_id = av_antwort.vorgang_id
LEFT JOIN aktivitaet a_antwort ON av_antwort.aktivitaet_id = a_antwort.id 
    AND a_antwort.aktivitaetsart = 'Antwort'
WHERE a_frage.aktivitaetsart = 'Kleine Anfrage'
AND a_frage.wahlperiode BETWEEN 7 AND 21
GROUP BY a_frage.wahlperiode
ORDER BY a_frage.wahlperiode;

-- 4B: Response Patterns by Asking Fraktion (WP21 focus)
-- Do opposition questions get answered differently than government questions?
SELECT 
    CASE 
        WHEN a_frage.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a_frage.titel LIKE '%DIE LINKE%' OR a_frage.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a_frage.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a_frage.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a_frage.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a_frage.titel LIKE '%CDU/CSU%' OR a_frage.titel LIKE '%CDU%' OR a_frage.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a_frage.titel LIKE '%FDP%' THEN 'FDP'
        ELSE 'Sonstige'
    END as asking_fraktion,
    COUNT(DISTINCT av_frage.vorgang_id) as questions_asked,
    COUNT(DISTINCT CASE WHEN a_antwort.id IS NOT NULL THEN av_antwort.vorgang_id END) as questions_answered,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN a_antwort.id IS NOT NULL THEN av_antwort.vorgang_id END) AS FLOAT) / 
          COUNT(DISTINCT av_frage.vorgang_id) * 100, 2) as answer_rate_pct
FROM aktivitaet a_frage
INNER JOIN aktivitaet_vorgangsbezug av_frage ON a_frage.id = av_frage.aktivitaet_id
LEFT JOIN aktivitaet_vorgangsbezug av_antwort ON av_frage.vorgang_id = av_antwort.vorgang_id
LEFT JOIN aktivitaet a_antwort ON av_antwort.aktivitaet_id = a_antwort.id 
    AND a_antwort.aktivitaetsart = 'Antwort'
WHERE a_frage.aktivitaetsart = 'Kleine Anfrage'
AND a_frage.wahlperiode = 21
GROUP BY asking_fraktion
ORDER BY questions_asked DESC;

-- ============================================================================
-- PART 5: MINISTRY-SPECIFIC OVERSIGHT
-- ============================================================================
-- Which government departments face most scrutiny?
-- Use keyword matching on drucksache.titel to identify ministry focus

-- 5A: Ministry Mentions in Questions (WP21)
SELECT 
    'Auswärtiges Amt' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Auswärtiges Amt%' OR d.titel LIKE '%Außenminister%' OR d.titel LIKE '%Einzelplan 05%')

UNION ALL

SELECT 
    'Bundesministerium des Innern' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Bundesministerium des Innern%' OR d.titel LIKE '%Innenminister%' OR d.titel LIKE '%BMI%' OR d.titel LIKE '%Einzelplan 06%')

UNION ALL

SELECT 
    'Bundesministerium der Finanzen' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Bundesministerium der Finanzen%' OR d.titel LIKE '%Finanzminister%' OR d.titel LIKE '%BMF%' OR d.titel LIKE '%Einzelplan 08%')

UNION ALL

SELECT 
    'Bundesministerium für Wirtschaft' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Bundesministerium für Wirtschaft%' OR d.titel LIKE '%Wirtschaftsminister%' OR d.titel LIKE '%BMWK%' OR d.titel LIKE '%Einzelplan 09%')

UNION ALL

SELECT 
    'Bundesministerium für Arbeit und Soziales' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Bundesministerium für Arbeit%' OR d.titel LIKE '%Arbeitsminister%' OR d.titel LIKE '%BMAS%' OR d.titel LIKE '%Einzelplan 11%')

UNION ALL

SELECT 
    'Bundesministerium der Verteidigung' as ministry,
    COUNT(DISTINCT d.id) as questions_received
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
AND (d.titel LIKE '%Bundesministerium der Verteidigung%' OR d.titel LIKE '%Verteidigungsminister%' OR d.titel LIKE '%BMVg%' OR d.titel LIKE '%Bundeswehr%' OR d.titel LIKE '%Einzelplan 14%')

ORDER BY questions_received DESC;

-- 5B: Ministry Oversight Evolution Over Time
SELECT 
    CASE 
        WHEN d.wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN d.wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN d.wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN d.wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN d.wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Auswärtiges Amt%' OR d.titel LIKE '%Außenminister%' THEN d.id END) as foreign_ministry,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Innenminister%' OR d.titel LIKE '%BMI%' THEN d.id END) as interior_ministry,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Finanzminister%' OR d.titel LIKE '%BMF%' THEN d.id END) as finance_ministry,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Wirtschaftsminister%' OR d.titel LIKE '%BMWK%' THEN d.id END) as economy_ministry,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Verteidigungsminister%' OR d.titel LIKE '%Bundeswehr%' THEN d.id END) as defense_ministry,
    COUNT(DISTINCT d.id) as total_questions
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- ============================================================================
-- PART 6: PARTISAN VS INVESTIGATIVE QUESTIONING
-- ============================================================================
-- Analyze whether questions are confrontational/partisan or substantive/investigative
-- Use linguistic cues in drucksache.titel

-- 6A: Confrontational Language Patterns (WP19-21)
SELECT 
    d.wahlperiode,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Versagen%' OR d.titel LIKE '%Skandal%' OR d.titel LIKE '%Verfehlung%' THEN d.id END) as confrontational_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Umsetzung%' OR d.titel LIKE '%Stand der%' OR d.titel LIKE '%Fortschritt%' THEN d.id END) as procedural_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Hintergründe%' OR d.titel LIKE '%Ursachen%' OR d.titel LIKE '%Zusammenhänge%' THEN d.id END) as investigative_questions,
    COUNT(DISTINCT d.id) as total_questions,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN d.titel LIKE '%Versagen%' OR d.titel LIKE '%Skandal%' OR d.titel LIKE '%Verfehlung%' THEN d.id END) AS FLOAT) / COUNT(DISTINCT d.id) * 100, 2) as pct_confrontational
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 19 AND 21
GROUP BY d.wahlperiode
ORDER BY d.wahlperiode;

-- 6B: AfD Questioning Patterns vs Other Opposition
-- Compare AfD question style to Die Linke (traditional opposition)
SELECT 
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        ELSE 'Other Opposition'
    END as fraktion,
    COUNT(DISTINCT d.id) as total_questions,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Migration%' OR d.titel LIKE '%Asyl%' OR d.titel LIKE '%Abschiebung%' THEN d.id END) as migration_focus,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Islam%' OR d.titel LIKE '%Muslim%' THEN d.id END) as islam_focus,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Gender%' OR d.titel LIKE '%Geschlecht%' THEN d.id END) as gender_focus,
    COUNT(DISTINCT CASE WHEN d.titel LIKE '%Klima%' OR d.titel LIKE '%Umwelt%' THEN d.id END) as climate_focus,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN d.titel LIKE '%Migration%' OR d.titel LIKE '%Asyl%' OR d.titel LIKE '%Abschiebung%' THEN d.id END) AS FLOAT) / COUNT(DISTINCT d.id) * 100, 2) as pct_migration
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN aktivitaet_vorgangsbezug av ON dv.vorgang_id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 19 AND 21
AND a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND (a.titel LIKE '%AfD%' OR a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' 
     OR a.titel LIKE '%GRÜNE%' OR a.titel LIKE '%CDU/CSU%')
GROUP BY fraktion
ORDER BY total_questions DESC;

-- ============================================================================
-- PART 7: TEMPORAL EVOLUTION - Question Intensity Over 50 Years
-- ============================================================================
-- How has question frequency changed relative to legislative activity?

-- 7A: Questions per Legislative Initiative (Oversight Intensity)
SELECT 
    v.wahlperiode,
    COUNT(DISTINCT CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN v.id END) as question_vorgaenge,
    COUNT(DISTINCT CASE WHEN v.vorgangstyp IN ('Antrag', 'Gesetzentwurf') THEN v.id END) as legislative_vorgaenge,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN v.id END) AS FLOAT) / 
          COUNT(DISTINCT CASE WHEN v.vorgangstyp IN ('Antrag', 'Gesetzentwurf') THEN v.id END), 2) as questions_per_initiative,
    COUNT(DISTINCT v.id) as total_vorgaenge
FROM vorgang v
WHERE v.wahlperiode BETWEEN 7 AND 21
GROUP BY v.wahlperiode
ORDER BY v.wahlperiode;

-- 7B: Oversight Intensity by Decade
SELECT 
    CASE 
        WHEN v.wahlperiode BETWEEN 7 AND 9 THEN '1972-1982'
        WHEN v.wahlperiode BETWEEN 10 AND 12 THEN '1983-1994'
        WHEN v.wahlperiode BETWEEN 13 AND 15 THEN '1995-2005'
        WHEN v.wahlperiode BETWEEN 16 AND 18 THEN '2006-2017'
        WHEN v.wahlperiode BETWEEN 19 AND 21 THEN '2018-2025'
    END as decade,
    SUM(CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) as question_vorgaenge,
    SUM(CASE WHEN v.vorgangstyp IN ('Antrag', 'Gesetzentwurf') THEN 1 ELSE 0 END) as legislative_vorgaenge,
    ROUND(CAST(SUM(CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) AS FLOAT) / 
          SUM(CASE WHEN v.vorgangstyp IN ('Antrag', 'Gesetzentwurf') THEN 1 ELSE 0 END), 2) as questions_per_initiative,
    COUNT(*) as total_vorgaenge,
    ROUND(CAST(SUM(CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100, 2) as pct_questions
FROM vorgang v
WHERE v.wahlperiode BETWEEN 7 AND 21
GROUP BY decade
ORDER BY decade;

-- 7C: Coalition Type and Question Volume
-- Grand coalitions leave smaller opposition, does this affect question volume?
SELECT 
    v.wahlperiode,
    CASE 
        WHEN v.wahlperiode IN (17, 18, 19) THEN 'Grand Coalition'
        WHEN v.wahlperiode IN (20, 21) THEN 'Traffic Light Coalition'
        ELSE 'Other Coalition'
    END as coalition_type,
    COUNT(CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 END) as question_volume,
    COUNT(*) as total_vorgaenge,
    ROUND(CAST(COUNT(CASE WHEN v.vorgangstyp IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 END) AS FLOAT) / COUNT(*) * 100, 2) as pct_questions
FROM vorgang v
WHERE v.wahlperiode BETWEEN 7 AND 21
GROUP BY v.wahlperiode, coalition_type
ORDER BY v.wahlperiode;

-- ============================================================================
-- PART 8: COMPARATIVE CONTEXT - Germany in European Perspective
-- ============================================================================
-- How does German oversight behavior compare to questions about other countries?

-- 8A: Domestic vs International Focus
SELECT 
    d.wahlperiode,
    COUNT(DISTINCT CASE WHEN 
        d.titel LIKE '%Deutschland%' OR d.titel LIKE '%Bundesrepublik%' OR d.titel LIKE '%deutschen%'
        THEN d.id END) as domestic_focus,
    COUNT(DISTINCT CASE WHEN 
        d.titel LIKE '%Europa%' OR d.titel LIKE '%EU-%' OR d.titel LIKE '%Europäisch%'
        OR d.titel LIKE '%USA%' OR d.titel LIKE '%China%' OR d.titel LIKE '%Russland%'
        THEN d.id END) as international_focus,
    COUNT(DISTINCT d.id) as total_questions,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN 
        d.titel LIKE '%Deutschland%' OR d.titel LIKE '%Bundesrepublik%' OR d.titel LIKE '%deutschen%'
        THEN d.id END) AS FLOAT) / COUNT(DISTINCT d.id) * 100, 2) as pct_domestic
FROM drucksache d
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY d.wahlperiode
ORDER BY d.wahlperiode;

-- ============================================================================
-- PART 9: QUESTION COMPLEXITY AND CO-SIGNERS
-- ============================================================================
-- Are questions becoming more collective or more individual?

-- 9A: Average Co-Signers Per Question Over Time
SELECT 
    d.wahlperiode,
    d.drucksachetyp,
    COUNT(DISTINCT d.id) as unique_questions,
    COUNT(DISTINCT a.id) as total_signers,
    ROUND(CAST(COUNT(DISTINCT a.id) AS FLOAT) / COUNT(DISTINCT d.id), 2) as avg_signers_per_question
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN aktivitaet_vorgangsbezug av ON dv.vorgang_id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode BETWEEN 7 AND 21
GROUP BY d.wahlperiode, d.drucksachetyp
ORDER BY d.wahlperiode, d.drucksachetyp;

-- 9B: Fraktion Discipline in Questioning (WP21)
-- Do fraktionen ask questions collectively or allow individual initiative?
SELECT 
    CASE 
        WHEN a.titel LIKE '%AfD%' THEN 'AfD'
        WHEN a.titel LIKE '%DIE LINKE%' OR a.titel LIKE '%Die Linke%' THEN 'DIE LINKE'
        WHEN a.titel LIKE '%BÜNDNIS 90/DIE GRÜNEN%' OR a.titel LIKE '%GRÜNE%' THEN 'GRÜNE'
        WHEN a.titel LIKE '%SPD%' THEN 'SPD'
        WHEN a.titel LIKE '%CDU/CSU%' OR a.titel LIKE '%CDU%' OR a.titel LIKE '%CSU%' THEN 'CDU/CSU'
        WHEN a.titel LIKE '%FDP%' THEN 'FDP'
    END as fraktion,
    COUNT(DISTINCT d.id) as unique_questions,
    COUNT(DISTINCT a.id) as total_aktivitaeten,
    ROUND(CAST(COUNT(DISTINCT a.id) AS FLOAT) / COUNT(DISTINCT d.id), 2) as avg_members_per_question,
    COUNT(DISTINCT CASE WHEN subq.signer_count = 1 THEN d.id END) as solo_questions,
    ROUND(CAST(COUNT(DISTINCT CASE WHEN subq.signer_count = 1 THEN d.id END) AS FLOAT) / COUNT(DISTINCT d.id) * 100, 2) as pct_solo
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN aktivitaet_vorgangsbezug av ON dv.vorgang_id = av.vorgang_id
INNER JOIN aktivitaet a ON av.aktivitaet_id = a.id
INNER JOIN (
    SELECT 
        d2.id as drucksache_id,
        COUNT(DISTINCT a2.id) as signer_count
    FROM drucksache d2
    INNER JOIN drucksache_vorgangsbezug dv2 ON d2.id = dv2.drucksache_id
    INNER JOIN aktivitaet_vorgangsbezug av2 ON dv2.vorgang_id = av2.vorgang_id
    INNER JOIN aktivitaet a2 ON av2.aktivitaet_id = a2.id
    WHERE d2.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
    AND a2.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
    AND d2.wahlperiode = 21
    GROUP BY d2.id
) subq ON d.id = subq.drucksache_id
WHERE d.drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND a.aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND d.wahlperiode = 21
GROUP BY fraktion
ORDER BY unique_questions DESC;

-- ============================================================================
-- PART 10: SUMMARY STATISTICS - 50-Year Overview
-- ============================================================================

-- 10A: Overall Question Evolution Summary
SELECT 
    'Total Questions (WP7-21)' as metric,
    COUNT(*) as value
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode BETWEEN 7 AND 21

UNION ALL

SELECT 
    'Total Answers (WP7-21)' as metric,
    COUNT(*) as value
FROM aktivitaet
WHERE aktivitaetsart = 'Antwort'
AND wahlperiode BETWEEN 7 AND 21

UNION ALL

SELECT 
    'Unique Question Drucksachen (WP7-21)' as metric,
    COUNT(DISTINCT id) as value
FROM drucksache
WHERE drucksachetyp IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode BETWEEN 7 AND 21

UNION ALL

SELECT 
    'Earliest Question (WP7)' as metric,
    COUNT(*) as value
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode = 7

UNION ALL

SELECT 
    'Latest Question (WP21)' as metric,
    COUNT(*) as value
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode = 21;

-- 10B: Peak Question Periods
SELECT 
    wahlperiode,
    COUNT(*) as question_volume,
    RANK() OVER (ORDER BY COUNT(*) DESC) as volume_rank
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
AND wahlperiode BETWEEN 7 AND 21
GROUP BY wahlperiode
ORDER BY question_volume DESC
LIMIT 5;

-- ============================================================================
-- END OF ANALYSIS
-- ============================================================================
-- Key Research Questions Addressed:
-- 1. How has question volume evolved over 50 years? (Part 1)
-- 2. What topics dominate oversight questions? (Part 2)
-- 3. Who uses oversight tools? (Part 3)
-- 4. How does government respond? (Part 4)
-- 5. Which ministries face most scrutiny? (Part 5)
-- 6. Are questions partisan or investigative? (Part 6)
-- 7. Has oversight intensity changed? (Part 7)
-- 8. Domestic vs international focus? (Part 8)
-- 9. Individual vs collective questioning? (Part 9)
-- 10. Overall 50-year summary (Part 10)
-- ============================================================================
