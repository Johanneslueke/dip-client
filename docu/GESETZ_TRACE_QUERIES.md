-- Example Queries for Tracing a Gesetz (Law) Through Legislative Process
-- These queries demonstrate how to use the views created in migration 0005

-- =============================================================================
-- QUERY 1: Get overview of all Gesetze (laws) with summary statistics
-- =============================================================================
SELECT
vorgang_id,
gesetz_titel,
beratungsstand,
wahlperiode,
vorgang_datum,
verkuendungsdatum,
inkrafttreten_datum,
sachgebiete,
initiativen,
anzahl_vorgangspositionen,
anzahl_aktivitaeten,
anzahl_drucksachen,
anzahl_plenarprotokolle
FROM gesetz_trace
ORDER BY vorgang_datum DESC
LIMIT 100;

-- =============================================================================
-- QUERY 2: Get complete timeline for a specific Gesetz (chronological)
-- Replace 'VORGANG_ID' with actual vorgang ID
-- =============================================================================
SELECT
entity_type,
entity_id,
event_date,
event_title,
event_description,
status,
pdf_url
FROM gesetz_timeline
WHERE vorgang_id = 'VORGANG_ID'
ORDER BY event_date ASC;

-- =============================================================================
-- QUERY 3: Find recent Gesetze by Sachgebiet (subject area)
-- =============================================================================
SELECT
vorgang_id,
gesetz_titel,
beratungsstand,
sachgebiete,
vorgang_datum,
verkuendungsdatum
FROM gesetz_trace
WHERE sachgebiete LIKE '%Umwelt%' -- Replace with desired subject
ORDER BY vorgang_datum DESC
LIMIT 50;

-- =============================================================================
-- QUERY 4: Get all Vorgangspositionen for a specific Gesetz
-- =============================================================================
SELECT
id,
titel,
vorgangsposition,
dokumentart,
datum,
zuordnung,
ressorts,
urheber,
fundstelle_pdf_url
FROM vorgangsposition_overview
WHERE vorgang_id = 'VORGANG_ID'
ORDER BY datum ASC;

-- =============================================================================
-- QUERY 5: Get all Drucksachen (printed documents) for a specific Gesetz
-- =============================================================================
SELECT
d.id,
d.titel,
d.dokumentnummer,
d.drucksachetyp,
d.datum,
d.ressorts,
d.urheber,
d.fundstelle_pdf_url,
SUBSTR(d.volltext, 1, 500) as text_preview -- First 500 chars
FROM drucksache_overview d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
WHERE dv.vorgang_id = 'VORGANG_ID'
ORDER BY d.datum ASC;

-- =============================================================================
-- QUERY 6: Get all Aktivitäten for a specific Gesetz
-- =============================================================================
SELECT
a.id,
a.titel,
a.aktivitaetsart,
a.datum,
a.deskriptoren,
a.fundstelle_pdf_url
FROM aktivitaet_overview a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE av.vorgang_id = 'VORGANG_ID'
ORDER BY a.datum ASC;

-- =============================================================================
-- QUERY 7: Get all Plenarprotokolle (plenary debates) for a specific Gesetz
-- =============================================================================
SELECT
pp.id,
pp.titel,
pp.dokumentnummer,
pp.datum,
pp.sitzungsbemerkung,
pp.fundstelle_pdf_url,
SUBSTR(pp.volltext, 1, 500) as text_preview
FROM plenarprotokoll_overview pp
INNER JOIN plenarprotokoll_vorgangsbezug ppv ON pp.id = ppv.plenarprotokoll_id
WHERE ppv.vorgang_id = 'VORGANG_ID'
ORDER BY pp.datum ASC;

-- =============================================================================
-- QUERY 8: Complete trace from Verkündung back to initial draft
-- This query shows the full legislative journey in reverse chronological order
-- =============================================================================
SELECT
gt.vorgang_id,
gt.gesetz_titel,
gt.beratungsstand,

    -- Verkündung (Publication)
    gt.verkuendungsdatum,
    gt.verkuendung_fundstelle,

    -- Inkrafttreten (Entry into force)
    gt.inkrafttreten_datum,
    gt.inkrafttreten_erlaeuterung,

    -- Timeline of events (newest first)
    (SELECT GROUP_CONCAT(
        event_date || ': ' || event_type || ' - ' || event_title,
        CHAR(10)  -- newline separator
    )
    FROM gesetz_timeline
    WHERE vorgang_id = gt.vorgang_id
    ORDER BY event_date DESC
    ) as complete_timeline

FROM gesetz_trace gt
WHERE gt.vorgang_id = 'VORGANG_ID';

-- =============================================================================
-- QUERY 9: Find all Gesetze with a specific Beratungsstand (consultation status)
-- =============================================================================
SELECT
vorgang_id,
gesetz_titel,
beratungsstand,
vorgang_datum,
sachgebiete,
anzahl_vorgangspositionen,
anzahl_drucksachen
FROM gesetz_trace
WHERE beratungsstand = 'Verkündet' -- or 'Noch nicht beraten', 'Abgeschlossen', etc.
ORDER BY vorgang_datum DESC;

-- =============================================================================
-- QUERY 10: Statistical overview of Gesetze by Wahlperiode
-- =============================================================================
SELECT
wahlperiode,
COUNT(\*) as anzahl_gesetze,
COUNT(CASE WHEN beratungsstand = 'Verkündet' THEN 1 END) as verkuendet,
COUNT(CASE WHEN beratungsstand = 'Abgeschlossen' THEN 1 END) as abgeschlossen,
AVG(anzahl_vorgangspositionen) as avg_positionen,
AVG(anzahl_drucksachen) as avg_drucksachen,
AVG(anzahl_aktivitaeten) as avg_aktivitaeten
FROM gesetz_trace
GROUP BY wahlperiode
ORDER BY wahlperiode DESC;

-- =============================================================================
-- QUERY 11: Find related Gesetze (via Verlinkung table)
-- =============================================================================
SELECT
gt.vorgang_id,
gt.gesetz_titel,
gt.beratungsstand,
vv.verweisung as beziehung,
gt_related.vorgang_id as related_vorgang_id,
gt_related.gesetz_titel as related_titel,
gt_related.beratungsstand as related_beratungsstand
FROM gesetz_trace gt
INNER JOIN vorgang_verlinkung vv ON gt.vorgang_id = vv.source_vorgang_id
INNER JOIN gesetz_trace gt_related ON vv.target_vorgang_id = gt_related.vorgang_id
WHERE gt.vorgang_id = 'VORGANG_ID';

-- =============================================================================
-- QUERY 12: Full legislative journey with all details
-- This is the most comprehensive query showing everything
-- =============================================================================
SELECT
'GESETZ' as section,
g.vorgang_id as id,
g.gesetz_titel as titel,
g.beratungsstand as details,
g.vorgang_datum as datum,
NULL as pdf_url
FROM gesetz_trace g
WHERE g.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'INITIATIVE' as section,
NULL as id,
vi.initiative as titel,
'Initiator' as details,
NULL as datum,
NULL as pdf_url
FROM vorgang_initiative vi
WHERE vi.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'VORGANGSPOSITION' as section,
vp.id,
vp.titel,
vp.vorgangsposition || ' | ' || vp.dokumentart as details,
vp.datum,
vp.fundstelle_pdf_url
FROM vorgangsposition_overview vp
WHERE vp.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'DRUCKSACHE' as section,
d.id,
d.titel,
d.dokumentnummer || ' | ' || d.drucksachetyp as details,
d.datum,
d.fundstelle_pdf_url
FROM drucksache_overview d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
WHERE dv.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'AKTIVITAET' as section,
a.id,
a.titel,
a.aktivitaetsart as details,
a.datum,
a.fundstelle_pdf_url
FROM aktivitaet_overview a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
WHERE av.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'PLENARPROTOKOLL' as section,
pp.id,
pp.titel,
pp.dokumentnummer || ' | ' || COALESCE(pp.sitzungsbemerkung, '') as details,
pp.datum,
pp.fundstelle_pdf_url
FROM plenarprotokoll_overview pp
INNER JOIN plenarprotokoll_vorgangsbezug ppv ON pp.id = ppv.plenarprotokoll_id
WHERE ppv.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'VERKUENDUNG' as section,
CAST(vk.id as TEXT),
'Verkündung im ' || vk.verkuendungsblatt_kuerzel,
vk.fundstelle as details,
vk.verkuendungsdatum,
vk.pdf_url
FROM verkuendung vk
WHERE vk.vorgang_id = 'VORGANG_ID'

UNION ALL

SELECT
'INKRAFTTRETEN' as section,
CAST(ik.id as TEXT),
'Inkrafttreten',
ik.erlaeuterung as details,
ik.datum,
NULL as pdf_url
FROM inkrafttreten ik
WHERE ik.vorgang_id = 'VORGANG_ID'

ORDER BY
CASE section
WHEN 'GESETZ' THEN 1
WHEN 'INITIATIVE' THEN 2
WHEN 'VORGANGSPOSITION' THEN 3
WHEN 'DRUCKSACHE' THEN 4
WHEN 'AKTIVITAET' THEN 5
WHEN 'PLENARPROTOKOLL' THEN 6
WHEN 'VERKUENDUNG' THEN 7
WHEN 'INKRAFTTRETEN' THEN 8
END,
datum ASC;
