-- name: GetDrucksache :one
SELECT *
FROM drucksache
WHERE id = ?;

-- name: GetDrucksacheWithRelations :many
SELECT 
    d.*,
    daa.person_id as autor_person_id,
    daa.autor_titel,
    daa.title as autor_title,
    daa.display_order as autor_display_order,
    r.titel as ressort_titel,
    dr.federfuehrend as ressort_federfuehrend,
    u.bezeichnung as urheber_bezeichnung,
    u.titel as urheber_titel,
    du.rolle as urheber_rolle,
    du.einbringer as urheber_einbringer
FROM drucksache d
LEFT JOIN drucksache_autor_anzeige daa ON d.id = daa.drucksache_id
LEFT JOIN drucksache_ressort dr ON d.id = dr.drucksache_id
LEFT JOIN ressort r ON dr.ressort_id = r.id
LEFT JOIN drucksache_urheber du ON d.id = du.drucksache_id
LEFT JOIN urheber u ON du.urheber_id = u.id
WHERE d.id = ?;

-- name: ListDrucksachen :many
SELECT *
FROM drucksache
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentnummer = ?)
    AND (? IS NULL OR drucksachetyp = ?)
ORDER BY aktualisiert DESC
LIMIT ? OFFSET ?;

-- name: CreateDrucksache :one
INSERT INTO drucksache (
    id, titel, dokumentnummer, dokumentart, typ, drucksachetyp, herausgeber,
    datum, aktualisiert, anlagen, autoren_anzahl, vorgangsbezug_anzahl,
    pdf_hash, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
) RETURNING *;

-- name: UpdateDrucksache :one
UPDATE drucksache
SET 
    titel = ?,
    aktualisiert = ?,
    anlagen = ?,
    autoren_anzahl = ?,
    vorgangsbezug_anzahl = ?,
    pdf_hash = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeleteDrucksache :exec
DELETE FROM drucksache WHERE id = ?;

-- name: CreateDrucksacheAutorAnzeige :one
INSERT INTO drucksache_autor_anzeige (
    drucksache_id, person_id, autor_titel, title, display_order
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT (drucksache_id, person_id) DO UPDATE
SET autor_titel = excluded.autor_titel,
    title = excluded.title,
    display_order = excluded.display_order
RETURNING *;

-- name: CreateDrucksacheRessort :exec
INSERT INTO drucksache_ressort (drucksache_id, ressort_id, federfuehrend)
VALUES (?, ?, ?)
ON CONFLICT (drucksache_id, ressort_id) DO UPDATE
SET federfuehrend = excluded.federfuehrend;

-- name: CreateDrucksacheUrheber :exec
INSERT INTO drucksache_urheber (drucksache_id, urheber_id, rolle, einbringer)
VALUES (?, ?, ?, ?)
ON CONFLICT (drucksache_id, urheber_id) DO UPDATE
SET rolle = excluded.rolle,
    einbringer = excluded.einbringer;

-- name: CreateDrucksacheVorgangsbezug :exec
INSERT INTO drucksache_vorgangsbezug (
    drucksache_id, vorgang_id, titel, vorgangstyp, display_order
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT (drucksache_id, vorgang_id, display_order) DO NOTHING;

-- name: CountDrucksachen :one
SELECT COUNT(*) FROM drucksache
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentnummer = ?)
    AND (? IS NULL OR drucksachetyp = ?);
