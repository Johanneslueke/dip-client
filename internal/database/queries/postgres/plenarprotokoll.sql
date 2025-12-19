-- name: GetPlenarprotokoll :one
SELECT 
    p.*,
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
LEFT JOIN plenarprotokoll_vorgangsbezug pvb ON p.id = pvb.plenarprotokoll_id
WHERE p.id = $1
GROUP BY p.id;

-- name: ListPlenarprotokolle :many
SELECT 
    p.*,
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
LEFT JOIN plenarprotokoll_vorgangsbezug pvb ON p.id = pvb.plenarprotokoll_id
WHERE 
    ($1::timestamptz IS NULL OR p.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR p.aktualisiert <= $2)
    AND ($3::date IS NULL OR p.datum >= $3)
    AND ($4::date IS NULL OR p.datum <= $4)
    AND ($5::int IS NULL OR p.wahlperiode = $5)
    AND ($6::text IS NULL OR p.dokumentnummer = $6)
GROUP BY p.id
ORDER BY p.datum DESC
LIMIT $7 OFFSET $8;

-- name: CreatePlenarprotokoll :one
INSERT INTO plenarprotokoll (
    id, titel, dokumentnummer, dokumentart, typ, herausgeber,
    datum, aktualisiert, pdf_hash, sitzungsbemerkung, vorgangsbezug_anzahl, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25
) RETURNING *;

-- name: UpdatePlenarprotokoll :one
UPDATE plenarprotokoll
SET 
    titel = $2,
    aktualisiert = $3,
    pdf_hash = $4,
    sitzungsbemerkung = $5,
    vorgangsbezug_anzahl = $6,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeletePlenarprotokoll :exec
DELETE FROM plenarprotokoll WHERE id = $1;

-- name: CreatePlenarprotokollVorgangsbezug :exec
INSERT INTO plenarprotokoll_vorgangsbezug (
    plenarprotokoll_id, vorgang_id, titel, vorgangstyp, display_order
) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (plenarprotokoll_id, vorgang_id, display_order) DO NOTHING;

-- name: CountPlenarprotokolle :one
SELECT COUNT(*) FROM plenarprotokoll
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR datum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::int IS NULL OR wahlperiode = $5)
    AND ($6::text IS NULL OR dokumentnummer = $6);
