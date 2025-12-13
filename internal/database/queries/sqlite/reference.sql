-- name: GetOrCreateRessort :one
INSERT INTO ressort (titel)
VALUES (?)
ON CONFLICT (titel) DO UPDATE
SET titel = excluded.titel
RETURNING *;

-- name: GetRessortByTitle :one
SELECT * FROM ressort
WHERE titel = ?;

-- name: ListRessorts :many
SELECT * FROM ressort
ORDER BY titel;

-- name: GetOrCreateUrheber :one
INSERT INTO urheber (bezeichnung, titel)
VALUES (?, ?)
ON CONFLICT (bezeichnung, titel) DO UPDATE
SET bezeichnung = excluded.bezeichnung
RETURNING *;

-- name: GetUrheberByDesignationAndTitle :one
SELECT * FROM urheber
WHERE bezeichnung = ? AND titel = ?;

-- name: ListUrheber :many
SELECT * FROM urheber
ORDER BY titel;

-- name: GetOrCreateWahlperiode :one
INSERT INTO wahlperiode (nummer)
VALUES (?)
ON CONFLICT (nummer) DO UPDATE
SET updated_at = datetime('now')
RETURNING *;

-- name: ListWahlperioden :many
SELECT * FROM wahlperiode
ORDER BY nummer DESC;

-- name: GetOrCreateBundesland :one
INSERT INTO bundesland (name)
VALUES (?)
ON CONFLICT (name) DO NOTHING
RETURNING *;

-- name: ListBundeslaender :many
SELECT * FROM bundesland
ORDER BY name;

-- name: CreateFundstelleUrheber :one
INSERT INTO fundstelle_urheber (drucksache_id, plenarprotokoll_id, urheber)
VALUES (?, ?, ?)
RETURNING *;

-- name: GetFundstelleUrheberByDrucksache :many
SELECT * FROM fundstelle_urheber
WHERE drucksache_id = ?;

-- name: GetFundstelleUrheberByPlenarprotokoll :many
SELECT * FROM fundstelle_urheber
WHERE plenarprotokoll_id = ?;
