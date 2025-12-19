-- name: GetAktivitaet :one
SELECT 
    a.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'name', ad.name,
                'typ', ad.typ)
        ) FILTER (WHERE ad.id IS NOT NULL),
        '[]'
    ) AS deskriptor,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', avb.vorgang_id,
                'titel', avb.titel,
                'vorgangsposition', avb.vorgangsposition,
                'vorgangstyp', avb.vorgangstyp
            ) ORDER BY avb.display_order
        ) FILTER (WHERE avb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM aktivitaet a
LEFT JOIN aktivitaet_deskriptor ad ON a.id = ad.aktivitaet_id
LEFT JOIN aktivitaet_vorgangsbezug avb ON a.id = avb.aktivitaet_id
WHERE a.id = $1
GROUP BY a.id;

-- name: ListAktivitaeten :many
SELECT 
    a.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'name', ad.name,
                'typ', ad.typ
            )
        ) FILTER (WHERE ad.id IS NOT NULL),
        '[]'
    ) AS deskriptor,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', avb.vorgang_id,
                'titel', avb.titel,
                'vorgangsposition', avb.vorgangsposition,
                'vorgangstyp', avb.vorgangstyp ) ORDER BY avb.display_order
        ) FILTER (WHERE avb.vorgang_id IS NOT NULL),
        '[]'
    ) AS vorgangsbezug
FROM aktivitaet a
LEFT JOIN aktivitaet_deskriptor ad ON a.id = ad.aktivitaet_id
LEFT JOIN aktivitaet_vorgangsbezug avb ON a.id = avb.aktivitaet_id
WHERE 
    ($1::timestamptz IS NULL OR a.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR a.aktualisiert <= $2)
    AND ($3::date IS NULL OR a.datum >= $3)
    AND ($4::date IS NULL OR a.datum <= $4)
    AND ($5::int IS NULL OR a.wahlperiode = $5)
    AND ($6::text IS NULL OR a.dokumentart = $6)
    AND ($7::text IS NULL OR a.fundstelle_dokumentnummer = $7)
GROUP BY a.id
ORDER BY a.aktualisiert DESC
LIMIT $8 OFFSET $9;

-- name: CreateAktivitaet :one
INSERT INTO aktivitaet (
    id, titel, aktivitaetsart, typ, dokumentart, datum, aktualisiert,
    abstract, vorgangsbezug_anzahl, wahlperiode,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25, $26, $27
) RETURNING *;

-- name: UpdateAktivitaet :one
UPDATE aktivitaet
SET 
    titel = $2,
    aktivitaetsart = $3,
    aktualisiert = $4,
    abstract = $5,
    vorgangsbezug_anzahl = $6,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeleteAktivitaet :exec
DELETE FROM aktivitaet WHERE id = $1;

-- name: CreateAktivitaetDeskriptor :one
INSERT INTO aktivitaet_deskriptor (aktivitaet_id, name, typ)
VALUES ($1, $2, $3)
ON CONFLICT (aktivitaet_id, name, typ) DO NOTHING
RETURNING *;

-- name: CreateAktivitaetVorgangsbezug :exec
INSERT INTO aktivitaet_vorgangsbezug (
    aktivitaet_id, vorgang_id, titel, vorgangsposition, vorgangstyp, display_order
) VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (aktivitaet_id, vorgang_id, display_order) DO NOTHING;

-- name: CountAktivitaeten :one
SELECT COUNT(*) FROM aktivitaet
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR datum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::int IS NULL OR wahlperiode = $5)
    AND ($6::text IS NULL OR dokumentart = $6)
    AND ($7::text IS NULL OR fundstelle_dokumentnummer = $7);
