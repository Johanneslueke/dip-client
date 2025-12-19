-- name: GetDrucksache :one
SELECT 
    d.*,
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
LEFT JOIN drucksache_autor_anzeige daa ON d.id = daa.drucksache_id
LEFT JOIN drucksache_ressort dr ON d.id = dr.drucksache_id
LEFT JOIN ressort r ON dr.ressort_id = r.id
LEFT JOIN drucksache_urheber du ON d.id = du.drucksache_id
LEFT JOIN urheber u ON du.urheber_id = u.id
LEFT JOIN drucksache_vorgangsbezug dvb ON d.id = dvb.drucksache_id
WHERE d.id = $1
GROUP BY d.id;

-- name: ListDrucksachen :many
SELECT 
    d.*,
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
GROUP BY d.id
ORDER BY d.aktualisiert DESC
LIMIT $8 OFFSET $9;

-- name: CreateDrucksache :one
INSERT INTO drucksache (
    id, titel, dokumentnummer, dokumentart, typ, drucksachetyp, herausgeber,
    datum, aktualisiert, anlagen, autoren_anzahl, vorgangsbezug_anzahl,
    pdf_hash, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25, $26, $27, $28, $29, $30, $31
) RETURNING *;

-- name: UpdateDrucksache :one
UPDATE drucksache
SET 
    titel = $2,
    aktualisiert = $3,
    anlagen = $4,
    autoren_anzahl = $5,
    vorgangsbezug_anzahl = $6,
    pdf_hash = $7,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeleteDrucksache :exec
DELETE FROM drucksache WHERE id = $1;

-- name: CreateDrucksacheAutorAnzeige :one
INSERT INTO drucksache_autor_anzeige (
    drucksache_id, person_id, autor_titel, title, display_order
) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (drucksache_id, person_id) DO UPDATE
SET autor_titel = EXCLUDED.autor_titel,
    title = EXCLUDED.title,
    display_order = EXCLUDED.display_order
RETURNING *;

-- name: CreateDrucksacheRessort :exec
INSERT INTO drucksache_ressort (drucksache_id, ressort_id, federfuehrend)
VALUES ($1, $2, $3)
ON CONFLICT (drucksache_id, ressort_id) DO UPDATE
SET federfuehrend = EXCLUDED.federfuehrend;

-- name: CreateDrucksacheUrheber :exec
INSERT INTO drucksache_urheber (drucksache_id, urheber_id, rolle, einbringer)
VALUES ($1, $2, $3, $4)
ON CONFLICT (drucksache_id, urheber_id) DO UPDATE
SET rolle = EXCLUDED.rolle,
    einbringer = EXCLUDED.einbringer;

-- name: CreateDrucksacheVorgangsbezug :exec
INSERT INTO drucksache_vorgangsbezug (
    drucksache_id, vorgang_id, titel, vorgangstyp, display_order
) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (drucksache_id, vorgang_id, display_order) DO NOTHING;

-- name: CountDrucksachen :one
SELECT COUNT(*) FROM drucksache
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR datum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::int IS NULL OR wahlperiode = $5)
    AND ($6::text IS NULL OR dokumentnummer = $6)
    AND ($7::text IS NULL OR drucksachetyp = $7);
