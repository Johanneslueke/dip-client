-- name: GetOrCreateRessort :one
INSERT INTO ressort (titel)
VALUES ($1)
ON CONFLICT (titel) DO UPDATE
SET titel = EXCLUDED.titel
RETURNING *;

-- name: GetRessortByTitle :one
SELECT * FROM ressort
WHERE titel = $1;

-- name: ListRessorts :many
SELECT * FROM ressort
ORDER BY titel;

-- name: GetOrCreateUrheber :one
INSERT INTO urheber (bezeichnung, titel)
VALUES ($1, $2)
ON CONFLICT (bezeichnung, titel) DO UPDATE
SET bezeichnung = EXCLUDED.bezeichnung
RETURNING *;

-- name: GetUrheberByDesignationAndTitle :one
SELECT * FROM urheber
WHERE bezeichnung = $1 AND titel = $2;

-- name: ListUrheber :many
SELECT * FROM urheber
ORDER BY titel;

-- name: GetOrCreateWahlperiode :one
INSERT INTO wahlperiode (nummer)
VALUES ($1)
ON CONFLICT (nummer) DO UPDATE
SET updated_at = NOW()
RETURNING *;

-- name: ListWahlperioden :many
SELECT * FROM wahlperiode
ORDER BY nummer DESC;

-- name: GetOrCreateBundesland :one
INSERT INTO bundesland (name)
VALUES ($1)
ON CONFLICT (name) DO NOTHING
RETURNING *;

-- name: ListBundeslaender :many
SELECT * FROM bundesland
ORDER BY name;

-- name: CreateFundstelleUrheber :one
INSERT INTO fundstelle_urheber (drucksache_id, plenarprotokoll_id, urheber)
VALUES ($1, $2, $3)
RETURNING *;

-- name: GetFundstelleUrheberByDrucksache :many
SELECT * FROM fundstelle_urheber
WHERE drucksache_id = $1;

-- name: GetFundstelleUrheberByPlenarprotokoll :many
SELECT * FROM fundstelle_urheber
WHERE plenarprotokoll_id = $1;
