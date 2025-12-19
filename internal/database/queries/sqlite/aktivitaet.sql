-- name: GetAktivitaet :one
-- SQLite version - uses json_object instead of jsonb_build_object, no FILTER clause
SELECT 
    a.*
FROM aktivitaet a
WHERE a.id = ?;

-- name: GetLatestAktivitaetDatum :one
SELECT MIN(datum) as datum FROM aktivitaet;

-- name: GetAktivitaetWithDeskriptor :many
SELECT 
    a.id,
    a.titel,
    a.aktivitaetsart,
    a.typ,
    a.dokumentart,
    a.datum,
    a.aktualisiert,
    a.abstract,
    a.vorgangsbezug_anzahl,
    a.wahlperiode,
    ad.name as deskriptor_name,
    ad.typ as deskriptor_typ
FROM aktivitaet a
LEFT JOIN aktivitaet_deskriptor ad ON a.id = ad.aktivitaet_id
WHERE a.id = ?;

-- name: ListAktivitaeten :many
SELECT *
FROM aktivitaet
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentart = ?)
    AND (? IS NULL OR fundstelle_dokumentnummer = ?)
ORDER BY aktualisiert DESC
LIMIT ? OFFSET ?;

-- name: CreateAktivitaet :one
INSERT INTO aktivitaet (
    id, titel, aktivitaetsart, typ, dokumentart, datum, aktualisiert,
    abstract, vorgangsbezug_anzahl, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?
) RETURNING *;

-- name: UpdateAktivitaet :one
UPDATE aktivitaet
SET 
    titel = ?,
    aktivitaetsart = ?,
    aktualisiert = ?,
    abstract = ?,
    vorgangsbezug_anzahl = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeleteAktivitaet :exec
DELETE FROM aktivitaet WHERE id = ?;

-- name: CreateAktivitaetDeskriptor :one
INSERT INTO aktivitaet_deskriptor (aktivitaet_id, name, typ)
VALUES (?, ?, ?)
ON CONFLICT (aktivitaet_id, name, typ) DO NOTHING
RETURNING *;

-- name: CreateAktivitaetVorgangsbezug :exec
INSERT INTO aktivitaet_vorgangsbezug (
    aktivitaet_id, vorgang_id, titel, vorgangsposition, vorgangstyp, display_order
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT (aktivitaet_id, vorgang_id, display_order) DO NOTHING;

-- name: CountAktivitaeten :one
SELECT COUNT(*) FROM aktivitaet
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR dokumentart = ?)
    AND (? IS NULL OR fundstelle_dokumentnummer = ?);
