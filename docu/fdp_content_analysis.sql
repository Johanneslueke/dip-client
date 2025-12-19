-- =========================================================
-- FDP ACTIVITY CONTENT ANALYSIS
-- =========================================================
-- Purpose: Deep dive into FDP aktivitäten content to understand
--          what topics, institutions, and geographic areas they focus on
-- Coverage: Primarily WP19 (2017-2021) with historical comparison WP14-15
-- Date: December 2025
-- =========================================================

.mode column
.headers on
.width 60 10 8

-- =========================================================
-- PART 1: FDP ACTIVITY VOLUME BY TYPE
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 1: FDP ACTIVITY BREAKDOWN BY TYPE' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    aktivitaetsart as 'Activity Type',
    COUNT(*) as 'Count',
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) as '% of FDP'
FROM aktivitaet
WHERE titel LIKE '%FDP%'
    AND wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
GROUP BY aktivitaetsart
ORDER BY COUNT(*) DESC
LIMIT 15;

SELECT '' as blank;

-- =========================================================
-- PART 2: TOP SUBJECT TERMS (SACHBEGRIFFE)
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 2: TOP 50 SUBJECT TERMS IN FDP QUESTIONS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Subject Term',
    COUNT(DISTINCT a.id) as 'Questions',
    ROUND(COUNT(DISTINCT a.id) * 100.0 / (
        SELECT COUNT(*) 
        FROM aktivitaet 
        WHERE aktivitaetsart = 'Kleine Anfrage' 
        AND titel LIKE '%FDP%' 
        AND wahlperiode = 19
    ), 2) as '% of FDP Q'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 50;

SELECT '' as blank;

-- =========================================================
-- PART 3: GEOGRAPHIC FOCUS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 3: GEOGRAPHIC FOCUS OF FDP QUESTIONS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Country/Region',
    COUNT(DISTINCT a.id) as 'Questions',
    ROUND(COUNT(DISTINCT a.id) * 100.0 / (
        SELECT COUNT(*) 
        FROM aktivitaet 
        WHERE aktivitaetsart = 'Kleine Anfrage' 
        AND titel LIKE '%FDP%' 
        AND wahlperiode = 19
    ), 2) as '% of FDP Q'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Geograph. Begriffe'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 40;

SELECT '' as blank;

-- =========================================================
-- PART 4: INSTITUTIONAL FOCUS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 4: INSTITUTIONS TARGETED BY FDP QUESTIONS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Institution',
    COUNT(DISTINCT a.id) as 'Questions',
    ROUND(COUNT(DISTINCT a.id) * 100.0 / (
        SELECT COUNT(*) 
        FROM aktivitaet 
        WHERE aktivitaetsart = 'Kleine Anfrage' 
        AND titel LIKE '%FDP%' 
        AND wahlperiode = 19
    ), 2) as '% of FDP Q'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Institutionen'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 40;

SELECT '' as blank;

-- =========================================================
-- PART 5: HISTORICAL COMPARISON - TOPIC EVOLUTION
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 5: FDP TOPIC EVOLUTION ACROSS WAHLPERIODEN' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

-- Top topics WP14
SELECT '--- Top 20 Topics WP14 (1998-2002) ---' as section;
SELECT '' as blank;

SELECT 
    vd.name as 'Subject Term',
    COUNT(DISTINCT a.id) as 'Count'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 14
    AND vd.typ = 'Sachbegriffe'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 20;

SELECT '' as blank;

-- Top topics WP15
SELECT '--- Top 20 Topics WP15 (2002-2005) ---' as section;
SELECT '' as blank;

SELECT 
    vd.name as 'Subject Term',
    COUNT(DISTINCT a.id) as 'Count'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 15
    AND vd.typ = 'Sachbegriffe'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 20;

SELECT '' as blank;

-- Top topics WP19
SELECT '--- Top 20 Topics WP19 (2017-2021) ---' as section;
SELECT '' as blank;

SELECT 
    vd.name as 'Subject Term',
    COUNT(DISTINCT a.id) as 'Count'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 20;

SELECT '' as blank;

-- =========================================================
-- PART 6: COVID-19 RELATED QUESTIONS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 6: COVID-19 FOCUS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    'Total COVID-19 related questions: ' || COUNT(DISTINCT a.id) as stat
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND (vd.name = 'COVID-19' OR vd.name = 'Seuchenbekämpfung');

SELECT '' as blank;

-- COVID-19 related sub-topics
SELECT 
    vd.name as 'COVID-19 Related Topic',
    COUNT(DISTINCT a.id) as 'Questions'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
    AND a.id IN (
        SELECT DISTINCT a2.id
        FROM aktivitaet a2
        JOIN aktivitaet_vorgangsbezug av2 ON a2.id = av2.aktivitaet_id
        JOIN vorgang v2 ON av2.vorgang_id = v2.id
        JOIN vorgang_deskriptor vd2 ON v2.id = vd2.vorgang_id
        WHERE vd2.name IN ('COVID-19', 'Seuchenbekämpfung')
    )
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 30;

SELECT '' as blank;

-- =========================================================
-- PART 7: DIGITALIZATION FOCUS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 7: DIGITALIZATION & TECH TOPICS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Digital/Tech Topic',
    COUNT(DISTINCT a.id) as 'Questions'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
    AND (
        vd.name LIKE '%Digital%'
        OR vd.name LIKE '%Internet%'
        OR vd.name LIKE '%Informationstechnik%'
        OR vd.name LIKE '%Datenschutz%'
        OR vd.name LIKE '%Cyber%'
        OR vd.name = 'Informationssicherheit'
    )
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC;

SELECT '' as blank;

-- =========================================================
-- PART 8: FINANCIAL/ECONOMIC OVERSIGHT
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 8: FINANCIAL & ECONOMIC TOPICS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Financial/Economic Topic',
    COUNT(DISTINCT a.id) as 'Questions'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
    AND (
        vd.name LIKE '%Steuer%'
        OR vd.name LIKE '%Finanz%'
        OR vd.name LIKE '%Bank%'
        OR vd.name LIKE '%Wirtschaft%'
        OR vd.name LIKE '%Kredit%'
        OR vd.name = 'Bundesmittel'
        OR vd.name = 'Besteuerungsverfahren'
    )
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC
LIMIT 30;

SELECT '' as blank;

-- =========================================================
-- PART 9: GOVERNMENT OVERSIGHT TOPICS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 9: GOVERNMENT OVERSIGHT & TRANSPARENCY (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    vd.name as 'Oversight Topic',
    COUNT(DISTINCT a.id) as 'Questions'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.typ = 'Sachbegriffe'
    AND (
        vd.name = 'Programm der Bundesregierung'
        OR vd.name = 'Personalausstattung'
        OR vd.name = 'Externe Beratung'
        OR vd.name = 'Evaluation'
        OR vd.name = 'Studie'
        OR vd.name = 'Politikberatung'
        OR vd.name = 'Gesetzesfolgenabschätzung'
        OR vd.name = 'Gutachten'
        OR vd.name = 'Öffentlichkeitsarbeit der Bundesregierung'
        OR vd.name = 'Beschaffung'
        OR vd.name = 'Baukosten'
    )
GROUP BY vd.name
ORDER BY COUNT(DISTINCT a.id) DESC;

SELECT '' as blank;

-- =========================================================
-- PART 10: TOP QUESTIONERS AND THEIR FOCUS AREAS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 10: TOP 15 FDP QUESTIONERS (WP19)' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    titel as 'Person',
    COUNT(*) as 'Total Questions'
FROM aktivitaet
WHERE aktivitaetsart = 'Kleine Anfrage'
    AND titel LIKE '%FDP%'
    AND wahlperiode = 19
GROUP BY titel
ORDER BY COUNT(*) DESC
LIMIT 15;

SELECT '' as blank;

-- =========================================================
-- PART 11: SAMPLE QUESTION TITLES BY TOPIC
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 11: SAMPLE QUESTION CONTENT' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

-- Sample COVID questions
SELECT '--- Sample COVID-19 Questions ---' as section;
SELECT '' as blank;

SELECT 
    v.titel as 'Question Title',
    a.datum as 'Date'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.name = 'COVID-19'
ORDER BY RANDOM()
LIMIT 10;

SELECT '' as blank;

-- Sample Digitalization questions
SELECT '--- Sample Digitalization Questions ---' as section;
SELECT '' as blank;

SELECT 
    v.titel as 'Question Title',
    a.datum as 'Date'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.name = 'Digitalisierung'
ORDER BY RANDOM()
LIMIT 10;

SELECT '' as blank;

-- Sample Financial oversight questions
SELECT '--- Sample Financial Oversight Questions ---' as section;
SELECT '' as blank;

SELECT 
    v.titel as 'Question Title',
    a.datum as 'Date'
FROM aktivitaet a
JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
JOIN vorgang v ON av.vorgang_id = v.id
JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE a.aktivitaetsart = 'Kleine Anfrage'
    AND a.titel LIKE '%FDP%'
    AND a.wahlperiode = 19
    AND vd.name = 'Bundesmittel'
ORDER BY RANDOM()
LIMIT 10;

SELECT '' as blank;

-- =========================================================
-- PART 12: SUMMARY STATISTICS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 12: OVERALL SUMMARY' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 'Total FDP Kleine Anfragen (WP19): ' || COUNT(*) as stat
FROM aktivitaet
WHERE aktivitaetsart = 'Kleine Anfrage'
    AND titel LIKE '%FDP%'
    AND wahlperiode = 19;

SELECT 'Unique FDP questioners (WP19): ' || COUNT(DISTINCT titel) as stat
FROM aktivitaet
WHERE aktivitaetsart = 'Kleine Anfrage'
    AND titel LIKE '%FDP%'
    AND wahlperiode = 19;

SELECT 'Date range: ' || MIN(datum) || ' to ' || MAX(datum) as stat
FROM aktivitaet
WHERE aktivitaetsart = 'Kleine Anfrage'
    AND titel LIKE '%FDP%'
    AND wahlperiode = 19;

SELECT '' as blank;
