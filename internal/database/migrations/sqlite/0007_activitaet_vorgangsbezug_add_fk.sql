-- +goose Up
-- +goose StatementBegin

-- Create new table with foreign key constraint
DROP VIEW IF EXISTS gesetz_timeline;
DROP VIEW IF EXISTS gesetz_trace;
DROP VIEW IF EXISTS plenarprotokoll_overview;
DROP VIEW IF EXISTS drucksache_overview;
DROP VIEW IF EXISTS aktivitaet_overview;
DROP VIEW IF EXISTS vorgangsposition_overview;

CREATE TABLE aktivitaet_vorgangsbezug_new (
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (aktivitaet_id, vorgang_id, display_order)
);

-- Copy data from old table
INSERT INTO aktivitaet_vorgangsbezug_new
SELECT * FROM aktivitaet_vorgangsbezug;

-- Drop old table
DROP TABLE aktivitaet_vorgangsbezug;

-- Rename new table
ALTER TABLE aktivitaet_vorgangsbezug_new RENAME TO aktivitaet_vorgangsbezug;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Recreate table without foreign key on vorgang_id
CREATE TABLE aktivitaet_vorgangsbezug_old (
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (aktivitaet_id, vorgang_id, display_order)
);

-- Copy data back
INSERT INTO aktivitaet_vorgangsbezug_old
SELECT * FROM aktivitaet_vorgangsbezug;

-- Drop new table
DROP TABLE aktivitaet_vorgangsbezug;

-- Rename old table
ALTER TABLE aktivitaet_vorgangsbezug_old RENAME TO aktivitaet_vorgangsbezug;

-- View 1: Aggregate all Vorgangspositionen with their key details
CREATE VIEW IF NOT EXISTS vorgangsposition_overview AS
SELECT 
    vp.id,
    vp.vorgang_id,
    vp.titel,
    vp.vorgangsposition,
    vp.vorgangstyp,
    vp.dokumentart,
    vp.datum,
    vp.aktualisiert,
    vp.abstract,
    vp.zuordnung,
    vp.fundstelle_dokumentnummer,
    vp.fundstelle_datum,
    vp.fundstelle_pdf_url,
    -- Aggregate related ressorts
    GROUP_CONCAT(DISTINCT r.titel) as ressorts,
    -- Aggregate related urhebers
    GROUP_CONCAT(DISTINCT u.bezeichnung) as urheber,
    vp.created_at,
    vp.updated_at
FROM vorgangsposition vp
LEFT JOIN vorgangsposition_ressort vpr ON vp.id = vpr.vorgangsposition_id
LEFT JOIN ressort r ON vpr.ressort_id = r.id
LEFT JOIN vorgangsposition_urheber vpu ON vp.id = vpu.vorgangsposition_id
LEFT JOIN urheber u ON vpu.urheber_id = u.id
GROUP BY vp.id;

-- View 2: Aggregate all Aktivitäten with their relationships
CREATE VIEW IF NOT EXISTS aktivitaet_overview AS
SELECT 
    a.id,
    a.titel,
    a.aktivitaetsart,
    a.dokumentart,
    a.datum,
    a.aktualisiert,
    a.abstract,
    a.wahlperiode,
    a.fundstelle_dokumentnummer,
    a.fundstelle_datum,
    a.fundstelle_pdf_url,
    -- Aggregate deskriptors
    GROUP_CONCAT(DISTINCT ad.name) as deskriptoren,
    -- Aggregate related vorgänge
    GROUP_CONCAT(DISTINCT av.vorgang_id) as vorgaenge,
    a.created_at,
    a.updated_at
FROM aktivitaet a
LEFT JOIN aktivitaet_deskriptor ad ON a.id = ad.aktivitaet_id
LEFT JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
GROUP BY a.id;

-- View 3: Aggregate all Drucksachen with their relationships
CREATE VIEW IF NOT EXISTS drucksache_overview AS
SELECT 
    d.id,
    d.titel,
    d.dokumentnummer,
    d.dokumentart,
    d.drucksachetyp,
    d.herausgeber,
    d.datum,
    d.aktualisiert,
    d.wahlperiode,
    d.fundstelle_pdf_url,
    dt.text as volltext,
    -- Aggregate autoren
    GROUP_CONCAT(DISTINCT p.nachname) as autoren,
    -- Aggregate ressorts
    GROUP_CONCAT(DISTINCT r.titel) as ressorts,
    -- Aggregate urheber
    GROUP_CONCAT(DISTINCT u.bezeichnung) as urheber,
    -- Aggregate vorgangsbezug
    GROUP_CONCAT(DISTINCT dv.vorgang_id) as vorgaenge,
    d.created_at,
    d.updated_at
FROM drucksache d
LEFT JOIN drucksache_text dt ON d.id = dt.id
LEFT JOIN drucksache_autor_anzeige daa ON d.id = daa.drucksache_id
LEFT JOIN person p ON daa.person_id = p.id
LEFT JOIN drucksache_ressort dr ON d.id = dr.drucksache_id
LEFT JOIN ressort r ON dr.ressort_id = r.id
LEFT JOIN drucksache_urheber du ON d.id = du.drucksache_id
LEFT JOIN urheber u ON du.urheber_id = u.id
LEFT JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
GROUP BY d.id;

-- View 4: Aggregate all Plenarprotokolle with their relationships
CREATE VIEW IF NOT EXISTS plenarprotokoll_overview AS
SELECT 
    pp.id,
    pp.titel,
    pp.dokumentnummer,
    pp.dokumentart,
    pp.herausgeber,
    pp.datum,
    pp.aktualisiert,
    pp.sitzungsbemerkung,
    pp.wahlperiode,
    pp.fundstelle_pdf_url,
    ppt.text as volltext,
    -- Aggregate vorgangsbezug
    GROUP_CONCAT(DISTINCT ppv.vorgang_id) as vorgaenge,
    pp.created_at,
    pp.updated_at
FROM plenarprotokoll pp
LEFT JOIN plenarprotokoll_text ppt ON pp.id = ppt.id
LEFT JOIN plenarprotokoll_vorgangsbezug ppv ON pp.id = ppv.plenarprotokoll_id
GROUP BY pp.id;

-- View 5: Complete Gesetz trace - Main view combining all related entities
CREATE VIEW IF NOT EXISTS gesetz_trace AS
SELECT 
    v.id as vorgang_id,
    v.titel as gesetz_titel,
    v.vorgangstyp,
    v.beratungsstand,
    v.datum as vorgang_datum,
    v.aktualisiert as vorgang_aktualisiert,
    v.wahlperiode,
    v.gesta,
    -- Aggregate sachgebiete
    GROUP_CONCAT(DISTINCT vs.sachgebiet) as sachgebiete,
    -- Aggregate initiativen
    GROUP_CONCAT(DISTINCT vi.initiative) as initiativen,
    -- Aggregate deskriptoren
    GROUP_CONCAT(DISTINCT vd.name) as deskriptoren,
    -- Verkündung information
    vk.ausfertigungsdatum,
    vk.verkuendungsdatum,
    vk.fundstelle as verkuendung_fundstelle,
    vk.pdf_url as verkuendung_pdf_url,
    -- Inkrafttreten information
    ik.datum as inkrafttreten_datum,
    ik.erlaeuterung as inkrafttreten_erlaeuterung,
    -- Count related entities
    (SELECT COUNT(*) FROM vorgangsposition WHERE vorgang_id = v.id) as anzahl_vorgangspositionen,
    (SELECT COUNT(DISTINCT av.aktivitaet_id) FROM aktivitaet_vorgangsbezug av WHERE av.vorgang_id = v.id) as anzahl_aktivitaeten,
    (SELECT COUNT(DISTINCT dv.drucksache_id) FROM drucksache_vorgangsbezug dv WHERE dv.vorgang_id = v.id) as anzahl_drucksachen,
    (SELECT COUNT(DISTINCT ppv.plenarprotokoll_id) FROM plenarprotokoll_vorgangsbezug ppv WHERE ppv.vorgang_id = v.id) as anzahl_plenarprotokolle,
    v.created_at,
    v.updated_at
FROM vorgang v
LEFT JOIN vorgang_sachgebiet vs ON v.id = vs.vorgang_id
LEFT JOIN vorgang_initiative vi ON v.id = vi.vorgang_id
LEFT JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
LEFT JOIN verkuendung vk ON v.id = vk.vorgang_id
LEFT JOIN inkrafttreten ik ON v.id = ik.vorgang_id
WHERE v.vorgangstyp = 'Gesetzgebung'
GROUP BY v.id;

-- View 6: Detailed timeline for a specific Gesetz (chronological order)
CREATE VIEW IF NOT EXISTS gesetz_timeline AS
SELECT 
    'vorgang' as entity_type,
    v.id as entity_id,
    v.datum as event_date,
    v.titel as event_title,
    'Vorgang erstellt' as event_description,
    v.beratungsstand as status,
    NULL as pdf_url,
    v.id as vorgang_id
FROM vorgang v
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'vorgangsposition' as entity_type,
    vp.id as entity_id,
    vp.datum as event_date,
    vp.titel as event_title,
    vp.vorgangsposition || ' - ' || vp.dokumentart as event_description,
    vp.zuordnung as status,
    vp.fundstelle_pdf_url as pdf_url,
    vp.vorgang_id
FROM vorgangsposition vp
INNER JOIN vorgang v ON vp.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'aktivitaet' as entity_type,
    a.id as entity_id,
    a.datum as event_date,
    a.titel as event_title,
    a.aktivitaetsart || ' - ' || a.dokumentart as event_description,
    NULL as status,
    a.fundstelle_pdf_url as pdf_url,
    av.vorgang_id
FROM aktivitaet a
INNER JOIN aktivitaet_vorgangsbezug av ON a.id = av.aktivitaet_id
INNER JOIN vorgang v ON av.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'drucksache' as entity_type,
    d.id as entity_id,
    d.datum as event_date,
    d.titel as event_title,
    d.dokumentnummer || ' - ' || d.drucksachetyp as event_description,
    NULL as status,
    d.fundstelle_pdf_url as pdf_url,
    dv.vorgang_id
FROM drucksache d
INNER JOIN drucksache_vorgangsbezug dv ON d.id = dv.drucksache_id
INNER JOIN vorgang v ON dv.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'plenarprotokoll' as entity_type,
    pp.id as entity_id,
    pp.datum as event_date,
    pp.titel as event_title,
    pp.dokumentnummer || ' - Plenardebatte' as event_description,
    pp.sitzungsbemerkung as status,
    pp.fundstelle_pdf_url as pdf_url,
    ppv.vorgang_id
FROM plenarprotokoll pp
INNER JOIN plenarprotokoll_vorgangsbezug ppv ON pp.id = ppv.plenarprotokoll_id
INNER JOIN vorgang v ON ppv.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'verkuendung' as entity_type,
    vk.id as entity_id,
    vk.verkuendungsdatum as event_date,
    'Verkündung im ' || vk.verkuendungsblatt_kuerzel as event_title,
    vk.fundstelle || ' - ' || vk.einleitungstext as event_description,
    'Verkündet' as status,
    vk.pdf_url,
    vk.vorgang_id
FROM verkuendung vk
INNER JOIN vorgang v ON vk.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

UNION ALL

SELECT 
    'inkrafttreten' as entity_type,
    ik.id as entity_id,
    ik.datum as event_date,
    'Inkrafttreten' as event_title,
    COALESCE(ik.erlaeuterung, 'Gesetz tritt in Kraft') as event_description,
    'In Kraft' as status,
    NULL as pdf_url,
    ik.vorgang_id
FROM inkrafttreten ik
INNER JOIN vorgang v ON ik.vorgang_id = v.id
WHERE v.vorgangstyp = 'Gesetzgebung'

ORDER BY event_date DESC;

-- +goose StatementEnd
