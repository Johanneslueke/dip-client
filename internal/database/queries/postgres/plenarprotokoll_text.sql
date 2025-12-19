-- name: GetPlenarprotokollText :one
SELECT 
    p.*,
    pt.text,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', pvb.vorgang_id,
                'titel', pvb.titel,
                'vorgangstyp', pvb.vorgangstyp
            ) ORDER BY pvb.display_order
        ) FILTER (WHERE pvb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM plenarprotokoll p
LEFT JOIN plenarprotokoll_text pt ON p.id = pt.id
LEFT JOIN plenarprotokoll_vorgangsbezug pvb ON p.id = pvb.plenarprotokoll_id
WHERE p.id = $1
GROUP BY p.id, pt.id, pt.text;

-- name: ListPlenarprotokollTexte :many
SELECT 
    p.*,
    pt.text,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', pvb.vorgang_id,
                'titel', pvb.titel,
                'vorgangstyp', pvb.vorgangstyp
            ) ORDER BY pvb.display_order
        ) FILTER (WHERE pvb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM plenarprotokoll p
INNER JOIN plenarprotokoll_text pt ON p.id = pt.id
LEFT JOIN plenarprotokoll_vorgangsbezug pvb ON p.id = pvb.plenarprotokoll_id
WHERE 
    ($1::timestamptz IS NULL OR p.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR p.aktualisiert <= $2)
    AND ($3::date IS NULL OR p.datum >= $3)
    AND ($4::date IS NULL OR p.datum <= $4)
    AND ($5::int IS NULL OR p.wahlperiode = $5)
    AND ($6::text IS NULL OR p.dokumentnummer = $6)
GROUP BY p.id, pt.id, pt.text
ORDER BY p.datum DESC
LIMIT $7 OFFSET $8;

-- name: CreatePlenarprotokollText :one
INSERT INTO plenarprotokoll_text (id, text)
VALUES ($1, $2)
ON CONFLICT (id) DO UPDATE
SET text = EXCLUDED.text,
    updated_at = NOW()
RETURNING *;

-- name: UpdatePlenarprotokollText :one
UPDATE plenarprotokoll_text
SET text = $2, updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeletePlenarprotokollText :exec
DELETE FROM plenarprotokoll_text WHERE id = $1;

-- name: CountPlenarprotokollTexte :one
SELECT COUNT(*) FROM plenarprotokoll p
INNER JOIN plenarprotokoll_text pt ON p.id = pt.id
WHERE 
    ($1::timestamptz IS NULL OR p.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR p.aktualisiert <= $2)
    AND ($3::date IS NULL OR p.datum >= $3)
    AND ($4::date IS NULL OR p.datum <= $4)
    AND ($5::int IS NULL OR p.wahlperiode = $5)
    AND ($6::text IS NULL OR p.dokumentnummer = $6);
