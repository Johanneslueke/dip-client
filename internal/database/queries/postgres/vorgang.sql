-- name: GetVorgang :one
SELECT 
    v.*,
    COALESCE(
        json_agg(DISTINCT vi.initiative) FILTER (WHERE vi.id IS NOT NULL),
        '[]'
    ) AS initiative,
    COALESCE(
        json_agg(DISTINCT vs.sachgebiet) FILTER (WHERE vs.id IS NOT NULL),
        '[]'
    ) AS sachgebiet,
    COALESCE(
        json_agg(DISTINCT vz.zustimmungsbeduerftigkeit) FILTER (WHERE vz.id IS NOT NULL),
        '[]'
    ) AS zustimmungsbeduerftigkeit,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'name', vd.name,
                'typ', vd.typ,
                'fundstelle', vd.fundstelle
            )
        ) FILTER (WHERE vd.id IS NOT NULL),
        '[]'
    ) AS deskriptor,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'ausfertigungsdatum', vk.ausfertigungsdatum,
                'verkuendungsdatum', vk.verkuendungsdatum,
                'einleitungstext', vk.einleitungstext,
                'fundstelle', vk.fundstelle,
                'jahrgang', vk.jahrgang,
                'seite', vk.seite,
                'heftnummer', vk.heftnummer,
                'pdf_url', vk.pdf_url,
                'rubrik_nr', vk.rubrik_nr,
                'titel', vk.titel,
                'verkuendungsblatt_bezeichnung', vk.verkuendungsblatt_bezeichnung,
                'verkuendungsblatt_kuerzel', vk.verkuendungsblatt_kuerzel
            )
        ) FILTER (WHERE vk.id IS NOT NULL),
        '[]'
    ) AS verkuendung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'datum', ik.datum,
                'erlaeuterung', ik.erlaeuterung
            )
        ) FILTER (WHERE ik.id IS NOT NULL),
        '[]'
    ) AS inkrafttreten,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'id', vvl.target_vorgang_id,
                'titel', vvl.titel,
                'verweisung', vvl.verweisung,
                'gesta', vvl.gesta,
                'wahlperiode', vvl.wahlperiode
            )
        ) FILTER (WHERE vvl.id IS NOT NULL),
        '[]'
    ) AS vorgang_verlinkung
FROM vorgang v
LEFT JOIN vorgang_initiative vi ON v.id = vi.vorgang_id
LEFT JOIN vorgang_sachgebiet vs ON v.id = vs.vorgang_id
LEFT JOIN vorgang_zustimmungsbeduerftigkeit vz ON v.id = vz.vorgang_id
LEFT JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
LEFT JOIN verkuendung vk ON v.id = vk.vorgang_id
LEFT JOIN inkrafttreten ik ON v.id = ik.vorgang_id
LEFT JOIN vorgang_verlinkung vvl ON v.id = vvl.source_vorgang_id
WHERE v.id = $1
GROUP BY v.id;

-- name: ListVorgaenge :many
SELECT 
    v.*,
    COALESCE(
        json_agg(DISTINCT vi.initiative) FILTER (WHERE vi.id IS NOT NULL),
        '[]'
    ) AS initiative,
    COALESCE(
        json_agg(DISTINCT vs.sachgebiet) FILTER (WHERE vs.id IS NOT NULL),
        '[]'
    ) AS sachgebiet,
    COALESCE(
        json_agg(DISTINCT vz.zustimmungsbeduerftigkeit) FILTER (WHERE vz.id IS NOT NULL),
        '[]'
    ) AS zustimmungsbeduerftigkeit,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'name', vd.name,
                'typ', vd.typ,
                'fundstelle', vd.fundstelle
            )
        ) FILTER (WHERE vd.id IS NOT NULL),
        '[]'
    ) AS deskriptor,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'ausfertigungsdatum', vk.ausfertigungsdatum,
                'verkuendungsdatum', vk.verkuendungsdatum,
                'einleitungstext', vk.einleitungstext,
                'fundstelle', vk.fundstelle,
                'jahrgang', vk.jahrgang,
                'seite', vk.seite
            )
        ) FILTER (WHERE vk.id IS NOT NULL),
        '[]'
    ) AS verkuendung,
    COALESCE(
        json_agg(
            DISTINCT jsonb_build_object(
                'datum', ik.datum,
                'erlaeuterung', ik.erlaeuterung
            )
        ) FILTER (WHERE ik.id IS NOT NULL),
        '[]'
    ) AS inkrafttreten
FROM vorgang v
LEFT JOIN vorgang_initiative vi ON v.id = vi.vorgang_id
LEFT JOIN vorgang_sachgebiet vs ON v.id = vs.vorgang_id
LEFT JOIN vorgang_zustimmungsbeduerftigkeit vz ON v.id = vz.vorgang_id
LEFT JOIN vorgang_deskriptor vd ON v.id = vd.vorgang_id
LEFT JOIN verkuendung vk ON v.id = vk.vorgang_id
LEFT JOIN inkrafttreten ik ON v.id = ik.vorgang_id
WHERE 
    ($1::timestamptz IS NULL OR v.aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR v.aktualisiert <= $2)
    AND ($3::date IS NULL OR v.datum >= $3)
    AND ($4::date IS NULL OR v.datum <= $4)
    AND ($5::int IS NULL OR v.wahlperiode = $5)
    AND ($6::text IS NULL OR v.vorgangstyp = $6)
    AND ($7::text IS NULL OR v.gesta = $7)
GROUP BY v.id
ORDER BY v.aktualisiert DESC
LIMIT $8 OFFSET $9;

-- name: CreateVorgang :one
INSERT INTO vorgang (
    id, titel, vorgangstyp, typ, abstract, aktualisiert,
    archiv, beratungsstand, datum, gesta, kom, mitteilung,
    ratsdok, sek, wahlperiode
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
RETURNING *;

-- name: UpdateVorgang :one
UPDATE vorgang
SET 
    titel = $2,
    abstract = $3,
    aktualisiert = $4,
    beratungsstand = $5,
    datum = $6,
    mitteilung = $7,
    updated_at = NOW()
WHERE id = $1
RETURNING *;

-- name: DeleteVorgang :exec
DELETE FROM vorgang WHERE id = $1;

-- name: CreateVorgangInitiative :exec
INSERT INTO vorgang_initiative (vorgang_id, initiative)
VALUES ($1, $2);

-- name: CreateVorgangSachgebiet :exec
INSERT INTO vorgang_sachgebiet (vorgang_id, sachgebiet)
VALUES ($1, $2);

-- name: CreateVorgangZustimmungsbeduerftigkeit :exec
INSERT INTO vorgang_zustimmungsbeduerftigkeit (vorgang_id, zustimmungsbeduerftigkeit)
VALUES ($1, $2);

-- name: CreateVorgangDeskriptor :one
INSERT INTO vorgang_deskriptor (vorgang_id, name, typ, fundstelle)
VALUES ($1, $2, $3, $4)
ON CONFLICT (vorgang_id, name, typ) DO UPDATE
SET fundstelle = EXCLUDED.fundstelle
RETURNING *;

-- name: CreateVerkuendung :one
INSERT INTO verkuendung (
    vorgang_id, ausfertigungsdatum, verkuendungsdatum, einleitungstext,
    fundstelle, jahrgang, seite, heftnummer, pdf_url, rubrik_nr,
    titel, verkuendungsblatt_bezeichnung, verkuendungsblatt_kuerzel
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
RETURNING *;

-- name: CreateInkrafttreten :one
INSERT INTO inkrafttreten (vorgang_id, datum, erlaeuterung)
VALUES ($1, $2, $3)
RETURNING *;

-- name: CreateVorgangVerlinkung :one
INSERT INTO vorgang_verlinkung (
    source_vorgang_id, target_vorgang_id, titel, verweisung, gesta, wahlperiode
) VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (source_vorgang_id, target_vorgang_id) DO UPDATE
SET titel = EXCLUDED.titel,
    verweisung = EXCLUDED.verweisung,
    gesta = EXCLUDED.gesta,
    wahlperiode = EXCLUDED.wahlperiode
RETURNING *;

-- name: CountVorgaenge :one
SELECT COUNT(*) FROM vorgang
WHERE 
    ($1::timestamptz IS NULL OR aktualisiert >= $1)
    AND ($2::timestamptz IS NULL OR aktualisiert <= $2)
    AND ($3::date IS NULL OR datum >= $3)
    AND ($4::date IS NULL OR datum <= $4)
    AND ($5::int IS NULL OR wahlperiode = $5)
    AND ($6::text IS NULL OR vorgangstyp = $6)
    AND ($7::text IS NULL OR gesta = $7);
