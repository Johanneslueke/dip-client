-- name: GetDrucksacheText :one
SELECT 
    d.*,
    dt.text,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', daa.person_id,
                'autor_titel', daa.autor_titel,
                'title', daa.title
            ) ORDER BY daa.display_order
        ) FILTER (WHERE daa.id IS NOT NULL),
        '[]'
    ) AS autoren_anzeige,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'titel', r.titel,
                'federfuehrend', dr.federfuehrend
            )
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'
    ) AS ressort,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'bezeichnung', u.bezeichnung,
                'titel', u.titel,
                'rolle', du.rolle,
                'einbringer', du.einbringer
            )
        ) FILTER (WHERE u.id IS NOT NULL),
        '[]'
    ) AS urheber,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', dvb.vorgang_id,
                'titel', dvb.titel,
                'vorgangstyp', dvb.vorgangstyp
            ) ORDER BY dvb.display_order
        ) FILTER (WHERE dvb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM drucksache d
LEFT JOIN drucksache_text dt ON d.id = dt.id
LEFT JOIN drucksache_autor_anzeige daa ON d.id = daa.drucksache_id
LEFT JOIN drucksache_ressort dr ON d.id = dr.drucksache_id
LEFT JOIN ressort r ON dr.ressort_id = r.id
LEFT JOIN drucksache_urheber du ON d.id = du.drucksache_id
LEFT JOIN urheber u ON du.urheber_id = u.id
LEFT JOIN drucksache_vorgangsbezug dvb ON d.id = dvb.drucksache_id
WHERE d.id = $1
GROUP BY d.id, dt.id, dt.text;

-- name: ListDrucksacheTexte :many
SELECT 
    d.*,
    dt.text,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', daa.person_id,
                'autor_titel', daa.autor_titel,
                'title', daa.title
            ) ORDER BY daa.display_order
        ) FILTER (WHERE daa.id IS NOT NULL),
        '[]'
    ) AS autoren_anzeige,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'titel', r.titel,
                'federfuehrend', dr.federfuehrend
            )
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'
    ) AS ressort,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'bezeichnung', u.bezeichnung,
                'titel', u.titel,
                'rolle', du.rolle,
                'einbringer', du.einbringer
            )
        ) FILTER (WHERE u.id IS NOT NULL),
        '[]'
    ) AS urheber,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', dvb.vorgang_id,
                'titel', dvb.titel,
                'vorgangstyp', dvb.vorgangstyp
            ) ORDER BY dvb.display_order
        ) FILTER (WHERE dvb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM drucksache d
INNER JOIN drucksache_text dt ON d.id = dt.id
LEFT JOIN drucksache_autor_anzeige daa ON d.id = daa.drucksache_id
LEFT JOIN drucksache_ressort dr ON d.id = dr.drucksache_id
LEFT JOIN ressort r ON dr.ressort_id = r.id
LEFT JOIN drucksache_urheber du ON d.id = du.drucksache_id
LEFT JOIN urheber u ON du.urheber_id = u.id
LEFT JOIN drucksache_vorgangsbezug dvb ON d.id = dvb.drucksache_id
WHERE 
    ($1::timestamptz IS NULL OR d.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR d.aktualisiert <= $2)
    AND ($3::date IS NULL OR d.datum >= $3)
    AND ($4::date IS NULL OR d.datum <= $4)
    AND ($5::int IS NULL OR d.wahlperiode = $5)
    AND ($6::text IS NULL OR d.dokumentnummer = $6)
    AND ($7::text IS NULL OR d.drucksachetyp = $7)
GROUP BY d.id, dt.id, dt.text
ORDER BY d.aktualisiert DESC
LIMIT $8 OFFSET $9;

-- name: CreateDrucksacheText :one
INSERT INTO drucksache_text (id, text)
VALUES ($1, $2)
ON CONFLICT (id) DO UPDATE
SET text = EXCLUDED.text,
    updated_at = NOW()
RETURNING *;

-- name: UpdateDrucksacheText :one
UPDATE drucksache_text
SET text = $2, updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeleteDrucksacheText :exec
DELETE FROM drucksache_text WHERE id = $1;

-- name: CountDrucksacheTexte :one
SELECT COUNT(*) FROM drucksache d
INNER JOIN drucksache_text dt ON d.id = dt.id
WHERE 
    ($1::timestamptz IS NULL OR d.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR d.aktualisiert <= $2)
    AND ($3::date IS NULL OR d.datum >= $3)
    AND ($4::date IS NULL OR d.datum <= $4)
    AND ($5::int IS NULL OR d.wahlperiode = $5)
    AND ($6::text IS NULL OR d.dokumentnummer = $6)
    AND ($7::text IS NULL OR d.drucksachetyp = $7);
