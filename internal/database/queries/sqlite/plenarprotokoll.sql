-- name: GetPlenarprotokoll :one
SELECT *
FROM plenarprotokoll
WHERE id = ?;

-- name: GetPlenarprotokollWithVorgangsbezug :many
SELECT 
    p.*,
    pvb.vorgang_id,
    pvb.titel as vorgangsbezug_titel,
    pvb.vorgangstyp as vorgangsbezug_typ,
    pvb.display_order
FROM plenarprotokoll p
LEFT JOIN plenarprotokoll_vorgangsbezug pvb ON p.id = pvb.plenarprotokoll_id
WHERE p.id = ?
ORDER BY pvb.display_order;

-- name: ListPlenarprotokolle :many
SELECT *
FROM plenarprotokoll
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentnummer = ?)
ORDER BY datum DESC
LIMIT ? OFFSET ?;

-- name: CreatePlenarprotokoll :one
INSERT INTO plenarprotokoll (
    id, titel, dokumentnummer, dokumentart, typ, herausgeber,
    datum, aktualisiert, pdf_hash, sitzungsbemerkung, vorgangsbezug_anzahl, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?
) RETURNING *;

-- name: UpdatePlenarprotokoll :one
UPDATE plenarprotokoll
SET 
    titel = ?,
    aktualisiert = ?,
    pdf_hash = ?,
    sitzungsbemerkung = ?,
    vorgangsbezug_anzahl = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeletePlenarprotokoll :exec
DELETE FROM plenarprotokoll WHERE id = ?;

-- name: CreatePlenarprotokollVorgangsbezug :exec
INSERT INTO plenarprotokoll_vorgangsbezug (
    plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT (plenarprotokoll_id, vorgang_id, display_order) DO NOTHING;

-- name: CountPlenarprotokolle :one
SELECT COUNT(*) FROM plenarprotokoll
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentnummer = ?);
