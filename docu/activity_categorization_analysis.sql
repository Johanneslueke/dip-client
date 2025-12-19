-- =========================================================
-- ACTIVITY CATEGORIZATION AND PERSON LINKAGE ANALYSIS
-- =========================================================
-- Purpose: Categorize all 858,218+ aktivitäten by type and link to persons
-- Coverage: WP13-15 (1997-2005), WP18-21 (2014-2025) = 28 years
-- Date: December 2025
-- =========================================================

-- =========================================================
-- PART 1: ACTIVITY TYPE OVERVIEW
-- =========================================================
-- Get complete breakdown of all activity types with counts

.mode column
.headers on
.width 50 10 12

SELECT '=========================================' as separator;
SELECT 'PART 1: ACTIVITY TYPE OVERVIEW' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 
    aktivitaetsart as 'Activity Type',
    COUNT(*) as 'Total Count',
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM aktivitaet), 2) as 'Percentage'
FROM aktivitaet
GROUP BY aktivitaetsart
ORDER BY COUNT(*) DESC;

SELECT '' as blank;
SELECT 'Total Activities: ' || COUNT(*) as summary FROM aktivitaet;
SELECT '' as blank;

-- =========================================================
-- PART 2: ACTIVITY CATEGORIES - FUNCTIONAL GROUPING
-- =========================================================
-- Group activities into logical categories based on parliamentary function

SELECT '=========================================' as separator;
SELECT 'PART 2: FUNCTIONAL CATEGORIZATION' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

WITH activity_categories AS (
  SELECT 
    aktivitaetsart,
    CASE 
      -- CATEGORY 1: WRITTEN QUESTIONS (Schriftliche Anfragen)
      WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 'Written Questions'
      
      -- CATEGORY 2: RESPONSES (Antworten)
      WHEN aktivitaetsart IN ('Antwort', 'Beantwortung', 'Berichterstattung und Beantwortung', 'Einleitende Ausführungen und Beantwortung') THEN 'Government Responses'
      
      -- CATEGORY 3: ORAL QUESTIONS (Mündliche Anfragen)
      WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 'Oral Questions'
      
      -- CATEGORY 4: LEGISLATIVE PROPOSALS (Gesetzgebung)
      WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 'Legislative Proposals'
      
      -- CATEGORY 5: PARLIAMENTARY SPEECHES (Reden)
      WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag', 'Erwiderung', 'Kurzintervention') THEN 'Parliamentary Speeches'
      
      -- CATEGORY 6: FORMAL DECLARATIONS (Erklärungen)
      WHEN aktivitaetsart IN (
        'Erklärung zum Plenarprotokoll',
        'Erklärung zur Aussprache gem. § 30 Geschäftsordnung BT',
        'Erklärung zum Vermittlungsverfahren (§91 GO-BT, §10 GO-VermA)',
        'Mündliche Erklärung gem. § 31 Geschäftsordnung BT',
        'Persönliche Erklärung gem. § 32 Geschäftsordnung BT',
        'Schriftliche Erklärung gem. § 31 Geschäftsordnung BT'
      ) THEN 'Formal Declarations'
      
      -- CATEGORY 7: PROCEDURAL INTERVENTIONS (Geschäftsordnung)
      WHEN aktivitaetsart IN ('Zur Geschäftsordnung BT', 'Zur Geschäftsordnung BR') THEN 'Procedural Interventions'
      
      -- CATEGORY 8: REPORTING (Berichterstattung)
      WHEN aktivitaetsart IN ('Berichterstattung', 'Berichterstattung (zu Protokoll gegeben)', 'Unterrichtung') THEN 'Committee Reports'
      
      -- CATEGORY 9: ADMINISTRATIVE (Verwaltung)
      WHEN aktivitaetsart IN ('Wahlvorschläge') THEN 'Administrative Actions'
      
      ELSE 'Other'
    END as category,
    COUNT(*) as count
  FROM aktivitaet
  GROUP BY aktivitaetsart
)
SELECT 
    category as 'Category',
    SUM(count) as 'Total',
    ROUND(SUM(count) * 100.0 / (SELECT COUNT(*) FROM aktivitaet), 2) as '%',
    GROUP_CONCAT(aktivitaetsart || ' (' || count || ')', ', ') as 'Activity Types (counts)'
FROM activity_categories
GROUP BY category
ORDER BY SUM(count) DESC;

SELECT '' as blank;

-- =========================================================
-- PART 3: PERSON EXTRACTION AND LINKAGE
-- =========================================================
-- Extract person names from aktivitaet titles

SELECT '=========================================' as separator;
SELECT 'PART 3: PERSON LINKAGE ANALYSIS' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

-- 3A: Sample person extraction from titles
SELECT '--- Sample Person Extractions from Aktivitaet Titles ---' as section;
SELECT '' as blank;

SELECT 
    aktivitaetsart as 'Type',
    titel as 'Person Name',
    datum as 'Date',
    wahlperiode as 'WP'
FROM aktivitaet
WHERE aktivitaetsart IN ('Kleine Anfrage', 'Frage', 'Rede', 'Antrag')
LIMIT 20;

SELECT '' as blank;

-- 3B: Count activities with person names in titles
SELECT '--- Person Name Prevalence ---' as section;
SELECT '' as blank;

WITH person_parsing AS (
  SELECT 
    aktivitaetsart,
    COUNT(*) as total,
    SUM(CASE WHEN titel LIKE '%MdB%' OR titel LIKE '%,%' THEN 1 ELSE 0 END) as with_person_name,
    ROUND(SUM(CASE WHEN titel LIKE '%MdB%' OR titel LIKE '%,%' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as person_pct
  FROM aktivitaet
  GROUP BY aktivitaetsart
)
SELECT 
    aktivitaetsart as 'Activity Type',
    total as 'Total',
    with_person_name as 'With Person',
    person_pct as '% Named'
FROM person_parsing
WHERE person_pct > 0
ORDER BY person_pct DESC;

SELECT '' as blank;

-- =========================================================
-- PART 4: ACTIVITY CATEGORIES BY WAHLPERIODE
-- =========================================================
-- Track how activity categories evolved over time

SELECT '=========================================' as separator;
SELECT 'PART 4: HISTORICAL EVOLUTION BY CATEGORY' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

WITH activity_categories AS (
  SELECT 
    wahlperiode,
    CASE 
      WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 'Written Questions'
      WHEN aktivitaetsart IN ('Antwort', 'Beantwortung', 'Berichterstattung und Beantwortung', 'Einleitende Ausführungen und Beantwortung') THEN 'Government Responses'
      WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 'Oral Questions'
      WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 'Legislative Proposals'
      WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag', 'Erwiderung', 'Kurzintervention') THEN 'Parliamentary Speeches'
      WHEN aktivitaetsart IN (
        'Erklärung zum Plenarprotokoll',
        'Erklärung zur Aussprache gem. § 30 Geschäftsordnung BT',
        'Erklärung zum Vermittlungsverfahren (§91 GO-BT, §10 GO-VermA)',
        'Mündliche Erklärung gem. § 31 Geschäftsordnung BT',
        'Persönliche Erklärung gem. § 32 Geschäftsordnung BT',
        'Schriftliche Erklärung gem. § 31 Geschäftsordnung BT'
      ) THEN 'Formal Declarations'
      WHEN aktivitaetsart IN ('Zur Geschäftsordnung BT', 'Zur Geschäftsordnung BR') THEN 'Procedural Interventions'
      WHEN aktivitaetsart IN ('Berichterstattung', 'Berichterstattung (zu Protokoll gegeben)', 'Unterrichtung') THEN 'Committee Reports'
      WHEN aktivitaetsart IN ('Wahlvorschläge') THEN 'Administrative Actions'
      ELSE 'Other'
    END as category
  FROM aktivitaet
  WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
)
SELECT 
    wahlperiode as 'WP',
    category as 'Category',
    COUNT(*) as 'Count',
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY wahlperiode), 2) as '% of WP'
FROM activity_categories
GROUP BY wahlperiode, category
ORDER BY wahlperiode, COUNT(*) DESC;

SELECT '' as blank;

-- =========================================================
-- PART 5: TOP ACTIVITY PERFORMERS BY CATEGORY
-- =========================================================
-- Identify most active individuals in each category

SELECT '=========================================' as separator;
SELECT 'PART 5: TOP PERFORMERS BY CATEGORY' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

-- 5A: Written Questions (Kleine/Große Anfrage)
SELECT '--- Top 20 Written Question Authors ---' as section;
SELECT '' as blank;

WITH person_activities AS (
  SELECT 
    titel as person_name,
    aktivitaetsart,
    COUNT(*) as count,
    MIN(datum) as first_activity,
    MAX(datum) as last_activity,
    COUNT(DISTINCT wahlperiode) as wahlperioden_count
  FROM aktivitaet
  WHERE aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage')
    AND wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
  GROUP BY titel, aktivitaetsart
)
SELECT 
    person_name as 'Person',
    aktivitaetsart as 'Type',
    count as 'Total',
    wahlperioden_count as 'WPs',
    first_activity as 'First',
    last_activity as 'Last'
FROM person_activities
ORDER BY count DESC
LIMIT 20;

SELECT '' as blank;

-- 5B: Oral Questions (Frage/Zusatzfrage/Zwischenfrage)
SELECT '--- Top 20 Oral Question Performers ---' as section;
SELECT '' as blank;

WITH oral_questions AS (
  SELECT 
    titel as person_name,
    COUNT(*) as total_questions,
    SUM(CASE WHEN aktivitaetsart = 'Frage' THEN 1 ELSE 0 END) as fragen,
    SUM(CASE WHEN aktivitaetsart = 'Zusatzfrage' THEN 1 ELSE 0 END) as zusatzfragen,
    SUM(CASE WHEN aktivitaetsart = 'Zwischenfrage' THEN 1 ELSE 0 END) as zwischenfragen,
    COUNT(DISTINCT wahlperiode) as wps
  FROM aktivitaet
  WHERE aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage')
    AND wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
  GROUP BY titel
)
SELECT 
    person_name as 'Person',
    total_questions as 'Total Oral',
    fragen as 'Fragen',
    zusatzfragen as 'Zusatz',
    zwischenfragen as 'Zwischen',
    wps as 'WPs'
FROM oral_questions
ORDER BY total_questions DESC
LIMIT 20;

SELECT '' as blank;

-- 5C: Parliamentary Speeches
SELECT '--- Top 20 Speech Makers ---' as section;
SELECT '' as blank;

WITH speeches AS (
  SELECT 
    titel as person_name,
    COUNT(*) as total_speeches,
    SUM(CASE WHEN aktivitaetsart = 'Rede' THEN 1 ELSE 0 END) as floor_speeches,
    SUM(CASE WHEN aktivitaetsart = 'Rede (zu Protokoll gegeben)' THEN 1 ELSE 0 END) as written_speeches,
    SUM(CASE WHEN aktivitaetsart IN ('Wortbeitrag', 'Erwiderung', 'Kurzintervention') THEN 1 ELSE 0 END) as interventions,
    COUNT(DISTINCT wahlperiode) as wps
  FROM aktivitaet
  WHERE aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag', 'Erwiderung', 'Kurzintervention')
    AND wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
  GROUP BY titel
)
SELECT 
    person_name as 'Person',
    total_speeches as 'Total',
    floor_speeches as 'Floor',
    written_speeches as 'Written',
    interventions as 'Interventions',
    wps as 'WPs'
FROM speeches
ORDER BY total_speeches DESC
LIMIT 20;

SELECT '' as blank;

-- 5D: Legislative Proposals
SELECT '--- Top 20 Legislative Proposal Authors ---' as section;
SELECT '' as blank;

WITH proposals AS (
  SELECT 
    titel as person_name,
    COUNT(*) as total_proposals,
    SUM(CASE WHEN aktivitaetsart = 'Gesetzentwurf' THEN 1 ELSE 0 END) as bills,
    SUM(CASE WHEN aktivitaetsart = 'Antrag' THEN 1 ELSE 0 END) as motions,
    SUM(CASE WHEN aktivitaetsart = 'Entschließungsantrag' THEN 1 ELSE 0 END) as resolutions,
    SUM(CASE WHEN aktivitaetsart = 'Änderungsantrag' THEN 1 ELSE 0 END) as amendments,
    COUNT(DISTINCT wahlperiode) as wps
  FROM aktivitaet
  WHERE aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag')
    AND wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
  GROUP BY titel
)
SELECT 
    person_name as 'Person',
    total_proposals as 'Total',
    bills as 'Bills',
    motions as 'Motions',
    resolutions as 'Resolutions',
    amendments as 'Amendments',
    wps as 'WPs'
FROM proposals
ORDER BY total_proposals DESC
LIMIT 20;

SELECT '' as blank;

-- =========================================================
-- PART 6: FRAKTION-LEVEL CATEGORY PATTERNS
-- =========================================================
-- Analyze which fraktionen specialize in which activity types

SELECT '=========================================' as separator;
SELECT 'PART 6: FRAKTION PATTERNS BY CATEGORY' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

WITH fraktion_categories AS (
  SELECT 
    CASE 
      WHEN titel LIKE '%AfD%' THEN 'AfD'
      WHEN titel LIKE '%CDU/CSU%' OR titel LIKE '%CDU%' OR titel LIKE '%CSU%' THEN 'CDU_CSU'
      WHEN titel LIKE '%SPD%' THEN 'SPD'
      WHEN titel LIKE '%FDP%' THEN 'FDP'
      WHEN titel LIKE '%GRÜNE%' OR titel LIKE '%BÜNDNIS 90%' OR titel LIKE '%B90%' THEN 'Grüne'
      WHEN titel LIKE '%DIE LINKE%' OR titel LIKE '%LINKE%' THEN 'Die Linke'
      WHEN titel LIKE '%PDS%' THEN 'PDS'
      ELSE 'Other/Government'
    END as fraktion,
    CASE 
      WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 'Written Questions'
      WHEN aktivitaetsart IN ('Antwort', 'Beantwortung', 'Berichterstattung und Beantwortung', 'Einleitende Ausführungen und Beantwortung') THEN 'Government Responses'
      WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 'Oral Questions'
      WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 'Legislative Proposals'
      WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag', 'Erwiderung', 'Kurzintervention') THEN 'Parliamentary Speeches'
      WHEN aktivitaetsart IN (
        'Erklärung zum Plenarprotokoll',
        'Erklärung zur Aussprache gem. § 30 Geschäftsordnung BT',
        'Erklärung zum Vermittlungsverfahren (§91 GO-BT, §10 GO-VermA)',
        'Mündliche Erklärung gem. § 31 Geschäftsordnung BT',
        'Persönliche Erklärung gem. § 32 Geschäftsordnung BT',
        'Schriftliche Erklärung gem. § 31 Geschäftsordnung BT'
      ) THEN 'Formal Declarations'
      WHEN aktivitaetsart IN ('Zur Geschäftsordnung BT', 'Zur Geschäftsordnung BR') THEN 'Procedural Interventions'
      WHEN aktivitaetsart IN ('Berichterstattung', 'Berichterstattung (zu Protokoll gegeben)', 'Unterrichtung') THEN 'Committee Reports'
      WHEN aktivitaetsart IN ('Wahlvorschläge') THEN 'Administrative Actions'
      ELSE 'Other'
    END as category,
    wahlperiode
  FROM aktivitaet
  WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
)
SELECT 
    fraktion as 'Fraktion',
    category as 'Category',
    COUNT(*) as 'Count',
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY fraktion), 2) as '% of Fraktion'
FROM fraktion_categories
GROUP BY fraktion, category
ORDER BY fraktion, COUNT(*) DESC;

SELECT '' as blank;

-- =========================================================
-- PART 7: ACTIVITY INTENSITY PROFILES
-- =========================================================
-- Create persona profiles based on activity patterns

SELECT '=========================================' as separator;
SELECT 'PART 7: PARLIAMENTARIAN ACTIVITY PROFILES' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

WITH person_profiles AS (
  SELECT 
    titel as person_name,
    COUNT(*) as total_activities,
    COUNT(DISTINCT wahlperiode) as wps,
    
    -- Calculate category concentrations
    ROUND(SUM(CASE WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_written_questions,
    ROUND(SUM(CASE WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_oral_questions,
    ROUND(SUM(CASE WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag', 'Erwiderung', 'Kurzintervention') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_speeches,
    ROUND(SUM(CASE WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_legislative,
    ROUND(SUM(CASE WHEN aktivitaetsart IN ('Antwort', 'Beantwortung') THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct_responses,
    
    -- Determine profile
    CASE 
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 70 THEN 'Question Specialist'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Antwort', 'Beantwortung') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 70 THEN 'Government Responder'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 50 THEN 'Speech Specialist'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 40 THEN 'Oral Questioner'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 40 THEN 'Legislative Drafter'
      ELSE 'Generalist'
    END as profile
    
  FROM aktivitaet
  WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    AND titel LIKE '%MdB%'
  GROUP BY titel
  HAVING COUNT(*) >= 100
)
SELECT 
    profile as 'Profile Type',
    COUNT(*) as 'Count',
    ROUND(AVG(total_activities), 1) as 'Avg Activities',
    ROUND(AVG(pct_written_questions), 1) as 'Avg % Written Q',
    ROUND(AVG(pct_oral_questions), 1) as 'Avg % Oral Q',
    ROUND(AVG(pct_speeches), 1) as 'Avg % Speeches',
    ROUND(AVG(pct_legislative), 1) as 'Avg % Legislative'
FROM person_profiles
GROUP BY profile
ORDER BY COUNT(*) DESC;

SELECT '' as blank;

-- Show sample of each profile type
SELECT '--- Sample Individuals by Profile Type ---' as section;
SELECT '' as blank;

WITH person_profiles AS (
  SELECT 
    titel as person_name,
    COUNT(*) as total_activities,
    CASE 
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Kleine Anfrage', 'Große Anfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 70 THEN 'Question Specialist'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Antwort', 'Beantwortung') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 70 THEN 'Government Responder'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Rede', 'Rede (zu Protokoll gegeben)', 'Wortbeitrag') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 50 THEN 'Speech Specialist'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Frage', 'Zusatzfrage', 'Zwischenfrage') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 40 THEN 'Oral Questioner'
      WHEN SUM(CASE WHEN aktivitaetsart IN ('Gesetzentwurf', 'Antrag', 'Entschließungsantrag', 'Änderungsantrag') THEN 1 ELSE 0 END) * 100.0 / COUNT(*) > 40 THEN 'Legislative Drafter'
      ELSE 'Generalist'
    END as profile
  FROM aktivitaet
  WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    AND titel LIKE '%MdB%'
  GROUP BY titel
  HAVING COUNT(*) >= 100
),
ranked_samples AS (
  SELECT 
    profile,
    person_name,
    total_activities,
    ROW_NUMBER() OVER (PARTITION BY profile ORDER BY total_activities DESC) as rank
  FROM person_profiles
)
SELECT 
    profile as 'Profile',
    person_name as 'Example Person',
    total_activities as 'Activities'
FROM ranked_samples
WHERE rank <= 3
ORDER BY profile, rank;

SELECT '' as blank;

-- =========================================================
-- PART 8: CATEGORY DIVERSITY ANALYSIS
-- =========================================================
-- Measure how specialized vs generalist parliamentarians are

SELECT '=========================================' as separator;
SELECT 'PART 8: SPECIALIZATION vs GENERALIZATION' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

WITH person_type_counts AS (
  SELECT 
    titel,
    aktivitaetsart,
    COUNT(*) as type_count
  FROM aktivitaet
  WHERE wahlperiode IN (13, 14, 15, 18, 19, 20, 21)
    AND titel LIKE '%MdB%'
  GROUP BY titel, aktivitaetsart
),
person_totals AS (
  SELECT 
    titel,
    SUM(type_count) as total_activities
  FROM person_type_counts
  GROUP BY titel
  HAVING total_activities >= 100
),
person_diversity AS (
  SELECT 
    ptc.titel as person_name,
    pt.total_activities,
    COUNT(DISTINCT ptc.aktivitaetsart) as activity_types_used
  FROM person_type_counts ptc
  JOIN person_totals pt ON ptc.titel = pt.titel
  GROUP BY ptc.titel, pt.total_activities
)
SELECT 
    CASE 
      WHEN activity_types_used <= 2 THEN 'Extreme Specialist (1-2 types)'
      WHEN activity_types_used <= 4 THEN 'Specialist (3-4 types)'
      WHEN activity_types_used <= 7 THEN 'Moderate (5-7 types)'
      WHEN activity_types_used <= 10 THEN 'Generalist (8-10 types)'
      ELSE 'Extreme Generalist (11+ types)'
    END as specialization_level,
    COUNT(*) as person_count,
    ROUND(AVG(total_activities), 1) as avg_activities,
    ROUND(AVG(activity_types_used), 1) as avg_types
FROM person_diversity
GROUP BY specialization_level
ORDER BY 
  CASE specialization_level
    WHEN 'Extreme Specialist (1-2 types)' THEN 1
    WHEN 'Specialist (3-4 types)' THEN 2
    WHEN 'Moderate (5-7 types)' THEN 3
    WHEN 'Generalist (8-10 types)' THEN 4
    ELSE 5
  END;

SELECT '' as blank;

-- =========================================================
-- PART 9: SUMMARY STATISTICS
-- =========================================================

SELECT '=========================================' as separator;
SELECT 'PART 9: OVERALL SUMMARY' as title;
SELECT '=========================================' as separator;
SELECT '' as blank;

SELECT 'Total aktivitäten: ' || COUNT(*) as stat FROM aktivitaet;
SELECT 'Unique activity types: ' || COUNT(DISTINCT aktivitaetsart) as stat FROM aktivitaet;
SELECT 'Wahlperioden covered: ' || GROUP_CONCAT(DISTINCT wahlperiode) as stat FROM aktivitaet WHERE wahlperiode IN (13,14,15,18,19,20,21);
SELECT 'Date range: ' || MIN(datum) || ' to ' || MAX(datum) as stat FROM aktivitaet WHERE wahlperiode IN (13,14,15,18,19,20,21);
SELECT 'Estimated unique persons (MdB): ' || COUNT(DISTINCT titel) as stat FROM aktivitaet WHERE titel LIKE '%MdB%';

SELECT '' as blank;
