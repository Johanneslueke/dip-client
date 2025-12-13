-- name: GetPerson :one
SELECT 
    p.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'funktion', pr.funktion,
                'funktionszusatz', pr.funktionszusatz,
                'vorname', pr.vorname,
                'nachname', pr.nachname,
                'namenszusatz', pr.namenszusatz,
                'fraktion', pr.fraktion,
                'bundesland', pr.bundesland,
                'ressort_titel', pr.ressort_titel,
                'wahlkreiszusatz', pr.wahlkreiszusatz,
                'wahlperiode_nummer', (
                    SELECT json_agg(prw.wahlperiode_nummer ORDER BY prw.wahlperiode_nummer)
                    FROM person_role_wahlperiode prw
                    WHERE prw.person_role_id = pr.id
                )
            )
        ) FILTER (WHERE pr.id IS NOT NULL),
        '[]'
    ) AS person_roles
FROM person p
LEFT JOIN person_role pr ON p.id = pr.person_id
WHERE p.id = $1
GROUP BY p.id;

-- name: ListPersonen :many
SELECT 
    p.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'funktion', pr.funktion,
                'funktionszusatz', pr.funktionszusatz,
                'vorname', pr.vorname,
                'nachname', pr.nachname,
                'namenszusatz', pr.namenszusatz,
                'fraktion', pr.fraktion,
                'bundesland', pr.bundesland,
                'ressort_titel', pr.ressort_titel,
                'wahlkreiszusatz', pr.wahlkreiszusatz,
                'wahlperiode_nummer', (
                    SELECT json_agg(prw.wahlperiode_nummer ORDER BY prw.wahlperiode_nummer)
                    FROM person_role_wahlperiode prw
                    WHERE prw.person_role_id = pr.id
                )
            )
        ) FILTER (WHERE pr.id IS NOT NULL),
        '[]'
    ) AS person_roles
FROM person p
LEFT JOIN person_role pr ON p.id = pr.person_id
WHERE 
    ($1::timestamptz IS NULL OR p.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR p.aktualisiert <= $2)
    AND ($3::date IS NULL OR p.basisdatum >= $3)
    AND ($4::date IS NULL OR p.datum <= $4)
    AND ($5::int IS NULL OR p.wahlperiode = $5)
    AND ($6::text IS NULL OR p.nachname ILIKE '%' || $6 || '%')
GROUP BY p.id
ORDER BY p.nachname, p.vorname
LIMIT $7 OFFSET $8;

-- name: CreatePerson :one
INSERT INTO person (
    id, vorname, nachname, namenszusatz, titel, typ,
    aktualisiert, basisdatum, datum, wahlperiode
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: UpdatePerson :one
UPDATE person
SET 
    vorname = $2,
    nachname = $3,
    namenszusatz = $4,
    titel = $5,
    aktualisiert = $6,
    basisdatum = $7,
    datum = $8,
    wahlperiode = $9,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeletePerson :exec
DELETE FROM person WHERE id = $1;

-- name: CreatePersonRole :one
INSERT INTO person_role (
    person_id, funktion, funktionszusatz, vorname, nachname, namenszusatz,
    fraktion, bundesland, ressort_titel, wahlkreiszusatz
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: CreatePersonRoleWahlperiode :exec
INSERT INTO person_role_wahlperiode (person_role_id, wahlperiode_nummer)
VALUES ($1, $2)
ON CONFLICT (person_role_id, wahlperiode_nummer) DO NOTHING;

-- name: CountPersonen :one
SELECT COUNT(*) FROM person
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR basisdatum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::int IS NULL OR wahlperiode = $5)
    AND ($6::text IS NULL OR nachname ILIKE '%' || $6 || '%');
