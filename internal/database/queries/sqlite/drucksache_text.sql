-- name: GetDrucksacheText :one
SELECT 
    d.*,
    dt.text
FROM drucksache d
LEFT JOIN drucksache_text dt ON d.id = dt.id
WHERE d.id = ?;

-- name: GetLatestDrucksacheTextDatum :one
SELECT MIN(datum) as datum FROM drucksache_text;

-- name: ListDrucksacheTexte :many
SELECT 
    d.*,
    dt.text
FROM drucksache d
INNER JOIN drucksache_text dt ON d.id = dt.id
WHERE 
    (? IS NULL OR d.aktualisiert >= ?)
    AND (? IS NULL OR d.aktualisiert <= ?)
    AND (? IS NULL OR d.datum >= ?)
    AND (? IS NULL OR d.datum <= ?)
    AND (? IS NULL OR d.wahlperiode = ?)
    AND (? IS NULL OR d.dokumentnummer = ?)
    AND (? IS NULL OR d.drucksachetyp = ?)
ORDER BY d.aktualisiert DESC
LIMIT ? OFFSET ?;

-- name: CreateDrucksacheText :one
INSERT INTO drucksache_text (id, text)
VALUES (?, ?)
ON CONFLICT (id) DO UPDATE
SET text = excluded.text,
    updated_at = datetime('now')
RETURNING *;

-- name: UpdateDrucksacheText :one
UPDATE drucksache_text
SET text = ?, updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeleteDrucksacheText :exec
DELETE FROM drucksache_text WHERE id = ?;

-- name: CountDrucksacheTexte :one
SELECT COUNT(*) FROM drucksache d
INNER JOIN drucksache_text dt ON d.id = dt.id
WHERE 
    (? IS NULL OR d.aktualisiert >= ?)
    AND (? IS NULL OR d.aktualisiert <= ?)
    AND (? IS NULL OR d.datum >= ?)
    AND (? IS NULL OR d.datum <= ?)
    AND (? IS NULL OR d.wahlperiode = ?)
    AND (? IS NULL OR d.dokumentnummer = ?)
    AND (? IS NULL OR d.drucksachetyp = ?);
