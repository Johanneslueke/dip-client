-- name: GetVorgangsposition :one
SELECT *
FROM vorgangsposition
WHERE id = ?;

-- name: GetLatestVorgangspositionDatum :one
SELECT MIN(datum) as datum FROM vorgangsposition;

-- name: GetVorgangspositionWithRessort :many
SELECT 
    vp.*,
    r.titel as ressort_titel,
    vpr.federfuehrend as ressort_federfuehrend
FROM vorgangsposition vp
LEFT JOIN vorgangsposition_ressort vpr ON vp.id = vpr.vorgangsposition_id
LEFT JOIN ressort r ON vpr.ressort_id = r.id
WHERE vp.id = ?;

-- name: GetVorgangspositionWithUrheber :many
SELECT 
    vp.*,
    u.bezeichnung as urheber_bezeichnung,
    u.titel as urheber_titel,
    vpu.rolle as urheber_rolle,
    vpu.einbringer as urheber_einbringer
FROM vorgangsposition vp
LEFT JOIN vorgangsposition_urheber vpu ON vp.id = vpu.vorgangsposition_id
LEFT JOIN urheber u ON vpu.urheber_id = u.id
WHERE vp.id = ?;

-- name: GetVorgangspositionWithUeberweisung :many
SELECT 
    vp.*,
    ue.ausschuss,
    ue.ausschuss_kuerzel,
    ue.federfuehrung,
    ue.ueberweisungsart
FROM vorgangsposition vp
LEFT JOIN ueberweisung ue ON vp.id = ue.vorgangsposition_id
WHERE vp.id = ?;

-- name: GetVorgangspositionWithBeschlussfassung :many
SELECT 
    vp.*,
    bf.beschlusstenor,
    bf.abstimmungsart,
    bf.mehrheit,
    bf.abstimm_ergebnis_bemerkung,
    bf.dokumentnummer as beschluss_dokumentnummer,
    bf.grundlage,
    bf.seite as beschluss_seite
FROM vorgangsposition vp
LEFT JOIN beschlussfassung bf ON vp.id = bf.vorgangsposition_id
WHERE vp.id = ?;

-- name: GetVorgangspositionWithAktivitaet :many
SELECT 
    vp.*,
    aa.aktivitaetsart,
    aa.titel as aktivitaet_titel,
    aa.seite as aktivitaet_seite,
    aa.pdf_url as aktivitaet_pdf_url,
    aa.display_order
FROM vorgangsposition vp
LEFT JOIN aktivitaet_anzeige aa ON vp.id = aa.vorgangsposition_id
WHERE vp.id = ?
ORDER BY aa.display_order;

-- name: ListVorgangspositionen :many
SELECT *
FROM vorgangsposition
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR vorgang_id = ?)
    AND (? IS NULL OR dokumentart = ?)
    AND (? IS NULL OR fundstelle_dokumentnummer = ?)
    AND (? IS NULL OR zuordnung = ?)
ORDER BY datum DESC
LIMIT ? OFFSET ?;

-- name: CreateVorgangsposition :one
INSERT INTO vorgangsposition (
    id, vorgang_id, titel, vorgangsposition, vorgangstyp, typ, dokumentart,
    datum, aktualisiert, abstract, fortsetzung, gang, nachtrag, aktivitaet_anzahl,
    kom, ratsdok, sek, zuordnung,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
    ?, ?, ?, ?, ?
) RETURNING *;

-- name: UpdateVorgangsposition :one
UPDATE vorgangsposition
SET 
    titel = ?,
    aktualisiert = ?,
    abstract = ?,
    aktivitaet_anzahl = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeleteVorgangsposition :exec
DELETE FROM vorgangsposition WHERE id = ?;

-- name: CreateVorgangspositionRessort :exec
INSERT INTO vorgangsposition_ressort (vorgangsposition_id, ressort_id, federfuehrend)
VALUES (?, ?, ?)
ON CONFLICT (vorgangsposition_id, ressort_id) DO UPDATE
SET federfuehrend = excluded.federfuehrend;

-- name: CreateVorgangspositionUrheber :exec
INSERT INTO vorgangsposition_urheber (vorgangsposition_id, urheber_id, rolle, einbringer)
VALUES (?, ?, ?, ?)
ON CONFLICT (vorgangsposition_id, urheber_id) DO UPDATE
SET rolle = excluded.rolle,
    einbringer = excluded.einbringer;

-- name: CreateUeberweisung :one
INSERT INTO ueberweisung (
    vorgangsposition_id, ausschuss, ausschuss_kuerzel, federfuehrung, ueberweisungsart
) VALUES (?, ?, ?, ?, ?)
RETURNING *;

-- name: CreateBeschlussfassung :one
INSERT INTO beschlussfassung (
    vorgangsposition_id, beschlusstenor, abstimmungsart, mehrheit,
    abstimm_ergebnis_bemerkung, dokumentnummer, grundlage, seite
) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: CreateAktivitaetAnzeige :one
INSERT INTO aktivitaet_anzeige (
    vorgangsposition_id, aktivitaetsart, titel, seite, pdf_url, display_order
) VALUES (?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: CreateVorgangspositionMitberaten :exec
INSERT INTO vorgangsposition_mitberaten (
    vorgangsposition_id, mitberaten_vorgang_id, mitberaten_titel,
    mitberaten_vorgangsposition, mitberaten_vorgangstyp
) VALUES (?, ?, ?, ?, ?)
ON CONFLICT (vorgangsposition_id, mitberaten_vorgang_id) DO UPDATE
SET mitberaten_titel = excluded.mitberaten_titel,
    mitberaten_vorgangsposition = excluded.mitberaten_vorgangsposition,
    mitberaten_vorgangstyp = excluded.mitberaten_vorgangstyp;

-- name: CountVorgangspositionen :one
SELECT COUNT(*) FROM vorgangsposition
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR vorgang_id = ?)
    AND (? IS NULL OR dokumentart = ?)
    AND (? IS NULL OR fundstelle_dokumentnummer = ?)
    AND (? IS NULL OR zuordnung = ?);
