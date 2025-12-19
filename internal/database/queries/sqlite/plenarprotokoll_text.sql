-- name: GetPlenarprotokollText :one
SELECT 
    p.*,
    pt.text
FROM plenarprotokoll p
LEFT JOIN plenarprotokoll_text pt ON p.id = pt.id
WHERE p.id = ?;

-- name: ListPlenarprotokollTexte :many
SELECT 
    p.*,
    pt.text
FROM plenarprotokoll p
INNER JOIN plenarprotokoll_text pt ON p.id = pt.id
WHERE 
    (? IS NULL OR p.aktualisiert >= ?)
    AND (? IS NULL OR p.aktualisiert <= ?)
    AND (? IS NULL OR p.datum >= ?)
    AND (? IS NULL OR p.datum <= ?)
    AND (? IS NULL OR p.wahlperiode = ?)
    AND (? IS NULL OR p.dokumentnummer = ?)
ORDER BY p.datum DESC
LIMIT ? OFFSET ?;

-- name: CreatePlenarprotokollText :one
INSERT INTO plenarprotokoll_text (id, text)
VALUES (?, ?)
ON CONFLICT (id) DO UPDATE
SET text = excluded.text,
    updated_at = datetime('now')
RETURNING *;

-- name: UpdatePlenarprotokollText :one
UPDATE plenarprotokoll_text
SET text = ?, updated_at = datetime('now')
WHERE id = ?
RETURNING *;

-- name: DeletePlenarprotokollText :exec
DELETE FROM plenarprotokoll_text WHERE id = ?;

-- name: CountPlenarprotokollTexte :one
SELECT COUNT(*) FROM plenarprotokoll p
INNER JOIN plenarprotokoll_text pt ON p.id = pt.id
WHERE 
    (? IS NULL OR p.aktualisiert >= ?)
    AND (? IS NULL OR p.aktualisiert <= ?)
    AND (? IS NULL OR p.datum >= ?)
    AND (? IS NULL OR p.datum <= ?)
    AND (? IS NULL OR p.wahlperiode = ?)
    AND (? IS NULL OR p.dokumentnummer = ?);
