-- name: GetVorgang :one
SELECT *
FROM vorgang
WHERE id = ?;

-- name: GetLatestVorgangDatum :one
SELECT MIN(datum) as datum FROM vorgang;

-- name: GetVorgangWithInitiative :many
SELECT 
    v.*,
    vi.initiative
FROM vorgang v
LEFT JOIN vorgang_initiative vi ON v.id = vi.vorgang_id
WHERE v.id = ?;

-- name: GetVorgangWithSachgebiet :many
SELECT 
    v.*,
    vs.sachgebiet
FROM vorgang v
LEFT JOIN vorgang_sachgebiet vs ON v.id = vs.vorgang_id
WHERE v.id = ?;

-- name: GetVorgangWithDeskriptor :many
SELECT 
    v.*,
    vd.name as deskriptor_name,
    vd.typ as deskriptor_typ,
    vd.fundstelle as deskriptor_fundstelle
FROM vorgang v
LEFT JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
WHERE v.id = ?;

-- name: ListVorgaenge :many
SELECT *
FROM vorgang
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR vorgangstyp = ?)
    AND (? IS NULL OR gesta = ?)
ORDER BY aktualisiert DESC
LIMIT ? OFFSET ?;

-- name: CreateVorgang :one
INSERT INTO vorgang (
    id, titel, vorgangstyp, typ, abstract, aktualisiert,
    archiv, beratungsstand, datum, gesta, kom, mitteilung,
    ratsdok, sek, wahlperiode
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: UpdateVorgang :one
UPDATE vorgang
SET 
    titel = ?,
    abstract = ?,
    aktualisiert = ?,
    beratungsstand = ?,
    datum = ?,
    mitteilung = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeleteVorgang :exec
DELETE FROM vorgang WHERE id = ?;

-- name: CreateVorgangInitiative :exec
INSERT INTO vorgang_initiative (vorgang_id, initiative)
VALUES (?, ?);

-- name: CreateVorgangSachgebiet :exec
INSERT INTO vorgang_sachgebiet (vorgang_id, sachgebiet)
VALUES (?, ?);

-- name: CreateVorgangZustimmungsbeduerftigkeit :exec
INSERT INTO vorgang_zustimmungsbeduerftigkeit (vorgang_id, zustimmungsbeduerftigkeit)
VALUES (?, ?);

-- name: CreateVorgangDeskriptor :one
INSERT INTO vorgang_deskriptor (vorgang_id, name, typ, fundstelle)
VALUES (?, ?, ?, ?)
ON CONFLICT (vorgang_id, name, typ) DO UPDATE
SET fundstelle = excluded.fundstelle
RETURNING *;

-- name: CreateVerkuendung :one
INSERT INTO verkuendung (
    vorgang_id, ausfertigungsdatum, verkuendungsdatum, einleitungstext,
    fundstelle, jahrgang, seite, heftnummer, pdf_url, rubrik_nr,
    titel, verkuendungsblatt_bezeichnung, verkuendungsblatt_kuerzel
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: CreateInkrafttreten :one
INSERT INTO inkrafttreten (vorgang_id, datum, erlaeuterung)
VALUES (?, ?, ?)
RETURNING *;

-- name: CreateVorgangVerlinkung :one
INSERT INTO vorgang_verlinkung (
    source_vorgang_id, target_vorgang_id, titel, verweisung, gesta, wahlperiode
) VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT (source_vorgang_id, target_vorgang_id) DO UPDATE
SET titel = excluded.titel,
    verweisung = excluded.verweisung,
    gesta = excluded.gesta,
    wahlperiode = excluded.wahlperiode
RETURNING *;

-- name: CountVorgaenge :one
SELECT COUNT(*) FROM vorgang
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR datum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR vorgangstyp = ?)
    AND (? IS NULL OR gesta = ?);
