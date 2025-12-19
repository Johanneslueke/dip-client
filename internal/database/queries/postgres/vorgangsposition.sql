-- name: GetVorgangsposition :one
SELECT 
    vp.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'titel', r.titel,
                'federfuehrend', vpr.federfuehrend
            )
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'
    ) AS ressort,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'bezeichnung', u.bezeichnung,
                'titel', u.titel,
                'rolle', vpu.rolle,
                'einbringer', vpu.einbringer
            )
        ) FILTER (WHERE u.id IS NOT NULL),
        '[]'
    ) AS urheber,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'ausschuss', ue.ausschuss,
                'ausschuss_kuerzel', ue.ausschuss_kuerzel,
                'federfuehrung', ue.federfuehrung,
                'ueberweisungsart', ue.ueberweisungsart
            )
        ) FILTER (WHERE ue.id IS NOT NULL),
        '[]'
    ) AS ueberweisung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'beschlusstenor', bf.beschlusstenor,
                'abstimmungsart', bf.abstimmungsart,
                'mehrheit', bf.mehrheit,
                'abstimm_ergebnis_bemerkung', bf.abstimm_ergebnis_bemerkung,
                'dokumentnummer', bf.dokumentnummer,
                'grundlage', bf.grundlage,
                'seite', bf.seite
            )
        ) FILTER (WHERE bf.id IS NOT NULL),
        '[]'
    ) AS beschlussfassung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'aktivitaetsart', aa.aktivitaetsart,
                'titel', aa.titel,
                'seite', aa.seite,
                'pdf_url', aa.pdf_url
            ) ORDER BY aa.display_order
        ) FILTER (WHERE aa.id IS NOT NULL),
        '[]'
    ) AS aktivitaet_anzeige,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', vpm.mitberaten_vorgang_id,
                'titel', vpm.mitberaten_titel,
                'vorgangsposition', vpm.mitberaten_vorgangsposition,
                'vorgangstyp', vpm.mitberaten_vorgangstyp
            )
        ) FILTER (WHERE vpm.mitberaten_vorgang_id IS NOT NULL),
        '[]'
    ) AS mitberaten
FROM vorgangsposition vp
LEFT JOIN vorgangsposition_ressort vpr ON vp.id = vpr.vorgangsposition_id
LEFT JOIN ressort r ON vpr.ressort_id = r.id
LEFT JOIN vorgangsposition_urheber vpu ON vp.id = vpu.vorgangsposition_id
LEFT JOIN urheber u ON vpu.urheber_id = u.id
LEFT JOIN ueberweisung ue ON vp.id = ue.vorgangsposition_id
LEFT JOIN beschlussfassung bf ON vp.id = bf.vorgangsposition_id
LEFT JOIN aktivitaet_anzeige aa ON vp.id = aa.vorgangsposition_id
LEFT JOIN vorgangsposition_mitberaten vpm ON vp.id = vpm.vorgangsposition_id
WHERE vp.id = $1
GROUP BY vp.id;

-- name: ListVorgangspositionen :many
SELECT 
    vp.*,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'titel', r.titel,
                'federfuehrend', vpr.federfuehrend
            )
        ) FILTER (WHERE r.id IS NOT NULL),
        '[]'
    ) AS ressort,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'bezeichnung', u.bezeichnung,
                'titel', u.titel,
                'rolle', vpu.rolle,
                'einbringer', vpu.einbringer
            )
        ) FILTER (WHERE u.id IS NOT NULL),
        '[]'
    ) AS urheber,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'ausschuss', ue.ausschuss,
                'ausschuss_kuerzel', ue.ausschuss_kuerzel,
                'federfuehrung', ue.federfuehrung,
                'ueberweisungsart', ue.ueberweisungsart
            )
        ) FILTER (WHERE ue.id IS NOT NULL),
        '[]'
    ) AS ueberweisung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'beschlusstenor', bf.beschlusstenor,
                'abstimmungsart', bf.abstimmungsart,
                'mehrheit', bf.mehrheit
            )
        ) FILTER (WHERE bf.id IS NOT NULL),
        '[]'
    ) AS beschlussfassung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'aktivitaetsart', aa.aktivitaetsart,
                'titel', aa.titel,
                'seite', aa.seite,
                'pdf_url', aa.pdf_url
            ) ORDER BY aa.display_order
        ) FILTER (WHERE aa.id IS NOT NULL),
        '[]'
    ) AS aktivitaet_anzeige
FROM vorgangsposition vp
LEFT JOIN vorgangsposition_ressort vpr ON vp.id = vpr.vorgangsposition_id
LEFT JOIN ressort r ON vpr.ressort_id = r.id
LEFT JOIN vorgangsposition_urheber vpu ON vp.id = vpu.vorgangsposition_id
LEFT JOIN urheber u ON vpu.urheber_id = u.id
LEFT JOIN ueberweisung ue ON vp.id = ue.vorgangsposition_id
LEFT JOIN beschlussfassung bf ON vp.id = bf.vorgangsposition_id
LEFT JOIN aktivitaet_anzeige aa ON vp.id = aa.vorgangsposition_id
WHERE 
    ($1::timestamptz IS NULL OR vp.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR vp.aktualisiert <= $2)
    AND ($3::date IS NULL OR vp.datum >= $3)
    AND ($4::date IS NULL OR vp.datum <= $4)
    AND ($5::text IS NULL OR vp.vorgang_id = $5)
    AND ($6::text IS NULL OR vp.dokumentart = $6)
    AND ($7::text IS NULL OR vp.fundstelle_dokumentnummer = $7)
    AND ($8::text IS NULL OR vp.zuordnung = $8)
GROUP BY vp.id
ORDER BY vp.datum DESC
LIMIT $9 OFFSET $10;

-- name: CreateVorgangsposition :one
INSERT INTO vorgangsposition (
    id, vorgang_id, titel, vorgangsposition, vorgangstyp, typ, dokumentart,
    datum, aktualisiert, abstract, fortsetzung, gang, nachtrag, aktivitaet_anzahl,
    kom, ratsdok, sek, zuordnung,
    fundstelle_dokumentnummer, fundstelle_datum, fundstelle_dokumentart,
    fundstelle_herausgeber, fundstelle_id, fundstelle_drucksachetyp,
    fundstelle_anlagen, fundstelle_anfangsseite, fundstelle_endseite,
    fundstelle_anfangsquadrant, fundstelle_endquadrant, fundstelle_seite,
    fundstelle_pdf_url, fundstelle_top, fundstelle_top_zusatz,
    fundstelle_frage_nummer, fundstelle_verteildatum
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
    $11, $12, $13, $14, $15, $16, $17, $18, $19, $20,
    $21, $22, $23, $24, $25, $26, $27, $28, $29, $30,
    $31, $32, $33, $34, $35
) RETURNING *;

-- name: UpdateVorgangsposition :one
UPDATE vorgangsposition
SET 
    titel = $2,
    aktualisiert = $3,
    abstract = $4,
    aktivitaet_anzahl = $5,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeleteVorgangsposition :exec
DELETE FROM vorgangsposition WHERE id = $1;

-- name: CreateVorgangspositionRessort :exec
INSERT INTO vorgangsposition_ressort (vorgangsposition_id, ressort_id, federfuehrend)
VALUES ($1, $2, $3)
ON CONFLICT (vorgangsposition_id, ressort_id) DO UPDATE
SET federfuehrend = EXCLUDED.federfuehrend;

-- name: CreateVorgangspositionUrheber :exec
INSERT INTO vorgangsposition_urheber (vorgangsposition_id, urheber_id, rolle, einbringer)
VALUES ($1, $2, $3, $4)
ON CONFLICT (vorgangsposition_id, urheber_id) DO UPDATE
SET rolle = EXCLUDED.rolle,
    einbringer = EXCLUDED.einbringer;

-- name: CreateUeberweisung :one
INSERT INTO ueberweisung (
    vorgangsposition_id, ausschuss, ausschuss_kuerzel, federfuehrung, ueberweisungsart
) VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: CreateBeschlussfassung :one
INSERT INTO beschlussfassung (
    vorgangsposition_id, beschlusstenor, abstimmungsart, mehrheit,
    abstimm_ergebnis_bemerkung, dokumentnummer, grundlage, seite
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: CreateAktivitaetAnzeige :one
INSERT INTO aktivitaet_anzeige (
    vorgangsposition_id, aktivitaetsart, titel, seite, pdf_url, display_order
) VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: CreateVorgangspositionMitberaten :exec
INSERT INTO vorgangsposition_mitberaten (
    vorgangsposition_id, mitberaten_vorgang_id, mitberaten_titel,
    mitberaten_vorgangsposition, mitberaten_vorgangstyp
) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (vorgangsposition_id, mitberaten_vorgang_id) DO UPDATE
SET mitberaten_titel = EXCLUDED.mitberaten_titel,
    mitberaten_vorgangsposition = EXCLUDED.mitberaten_vorgangsposition,
    mitberaten_vorgangstyp = EXCLUDED.mitberaten_vorgangstyp;

-- name: CountVorgangspositionen :one
SELECT COUNT(*) FROM vorgangsposition
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR datum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::text IS NULL OR vorgang_id = $5)
    AND ($6::text IS NULL OR dokumentart = $6)
    AND ($7::text IS NULL OR fundstelle_dokumentnummer = $7)
    AND ($8::text IS NULL OR zuordnung = $8);
