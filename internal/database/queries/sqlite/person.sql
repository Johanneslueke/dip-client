-- name: GetPerson :one
SELECT *
FROM person
WHERE id = ?;

-- name: GetPersonWithRoles :many
SELECT 
    p.*,
    pr.id as role_id,
    pr.funktion,
    pr.funktionszusatz,
    pr.vorname as role_vorname,
    pr.nachname as role_nachname,
    pr.namenszusatz as role_namenszusatz,
    pr.fraktion,
    pr.bundesland,
    pr.ressort_titel,
    pr.wahlkreiszusatz
FROM person p
LEFT JOIN person_role pr ON p.id = pr.person_id
WHERE p.id = ?;

-- name: ListPersonen :many
SELECT *
FROM person
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR basisdatum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR nachname LIKE '%' || ? || '%')
ORDER BY nachname, vorname
LIMIT ? OFFSET ?;

-- name: CreatePerson :one
INSERT INTO person (
    id, vorname, nachname, namenszusatz, titel, typ,
    aktualisiert, basisdatum, datum, wahlperiode
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: UpdatePerson :one
UPDATE person
SET 
    vorname = ?,
    nachname = ?,
    namenszusatz = ?,
    titel = ?,
    aktualisiert = ?,
    basisdatum = ?,
    datum = ?,
    wahlperiode = ?,
    updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeletePerson :exec
DELETE FROM person WHERE id = ?;

-- name: CreatePersonRole :one
INSERT INTO person_role (
    person_id, funktion, funktionszusatz, vorname, nachname, namenszusatz,
    fraktion, bundesland, ressort_titel, wahlkreiszusatz
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING *;

-- name: CreatePersonRoleWahlperiode :exec
INSERT INTO person_role_wahlperiode (person_role_id, wahlperiode_nummer)
VALUES (?, ?)
ON CONFLICT (person_role_id, wahlperiode_nummer) DO NOTHING;

-- name: CountPersonen :one
SELECT COUNT(*) FROM person
WHERE 
    (? IS NULL OR aktualisiert >= ?)
    AND (? IS NULL OR aktualisiert <= ?)
    AND (? IS NULL OR basisdatum >= ?)
    AND (? IS NULL OR datum <= ?)
    AND (? IS NULL OR wahlperiode = ?)
    AND (? IS NULL OR nachname LIKE '%' || ? || '%');
