-- MdB Stammdaten Queries
-- Queries for importing and managing MdB biographical master data

-- ============================================================================
-- VERSION MANAGEMENT
-- ============================================================================

-- name: CreateMdbStammdatenVersion :one
INSERT INTO mdb_stammdaten_version (version, import_date, source_file)
VALUES (?, ?, ?)
RETURNING *;

-- name: GetLatestMdbStammdatenVersion :one
SELECT * FROM mdb_stammdaten_version
ORDER BY import_date DESC
LIMIT 1;

-- name: ListMdbStammdatenVersions :many
SELECT * FROM mdb_stammdaten_version
ORDER BY import_date DESC;

-- ============================================================================
-- PERSON MANAGEMENT
-- ============================================================================

-- name: CreateMdbPerson :exec
INSERT INTO mdb_person (id, created_at, updated_at)
VALUES (?, ?, ?);

-- name: GetMdbPerson :one
SELECT * FROM mdb_person WHERE id = ?;

-- name: ListMdbPersons :many
SELECT * FROM mdb_person
ORDER BY id
LIMIT ? OFFSET ?;

-- name: DeleteMdbPerson :exec
DELETE FROM mdb_person WHERE id = ?;

-- ============================================================================
-- NAME MANAGEMENT
-- ============================================================================

-- name: CreateMdbName :exec
INSERT INTO mdb_name (
    mdb_id, nachname, vorname, ortszusatz, adel, praefix,
    anrede_titel, akad_titel, historie_von, historie_bis,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- name: GetMdbNames :many
SELECT * FROM mdb_name
WHERE mdb_id = ?
ORDER BY 
    CASE WHEN historie_von IS NULL OR historie_von = '' THEN 0 ELSE 1 END,
    historie_von;

-- name: GetMdbCurrentName :one
SELECT * FROM mdb_name
WHERE mdb_id = ?
AND (historie_von IS NULL OR historie_von = '')
LIMIT 1;

-- name: DeleteMdbNames :exec
DELETE FROM mdb_name WHERE mdb_id = ?;

-- ============================================================================
-- BIOGRAPHICAL DATA MANAGEMENT
-- ============================================================================

-- name: CreateMdbBiographical :exec
INSERT INTO mdb_biographical (
    mdb_id, geburtsdatum, geburtsort, geburtsland, sterbedatum,
    geschlecht, familienstand, religion, beruf, vita_kurz,
    veroeffentlichungspflichtiges, partei_kurz,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- name: GetMdbBiographical :one
SELECT * FROM mdb_biographical WHERE mdb_id = ?;

-- name: UpdateMdbBiographical :exec
UPDATE mdb_biographical
SET 
    geburtsdatum = ?,
    geburtsort = ?,
    geburtsland = ?,
    sterbedatum = ?,
    geschlecht = ?,
    familienstand = ?,
    religion = ?,
    beruf = ?,
    vita_kurz = ?,
    veroeffentlichungspflichtiges = ?,
    partei_kurz = ?,
    updated_at = datetime('now')
WHERE mdb_id = ?;

-- name: DeleteMdbBiographical :exec
DELETE FROM mdb_biographical WHERE mdb_id = ?;

-- ============================================================================
-- WAHLPERIODE MEMBERSHIP MANAGEMENT
-- ============================================================================

-- name: CreateMdbWahlperiodeMembership :one
INSERT INTO mdb_wahlperiode_membership (
    mdb_id, wp, mdbwp_von, mdbwp_bis, wkr_nummer, wkr_name,
    wkr_land, liste, mandatsart,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
RETURNING id;

-- name: GetMdbWahlperiodeMemberships :many
SELECT * FROM mdb_wahlperiode_membership
WHERE mdb_id = ?
ORDER BY wp;

-- name: GetMdbWahlperiodeMembership :one
SELECT * FROM mdb_wahlperiode_membership
WHERE mdb_id = ? AND wp = ?;

-- name: DeleteMdbWahlperiodeMemberships :exec
DELETE FROM mdb_wahlperiode_membership WHERE mdb_id = ?;

-- ============================================================================
-- INSTITUTION MEMBERSHIP MANAGEMENT
-- ============================================================================

-- name: CreateMdbInstitutionMembership :exec
INSERT INTO mdb_institution_membership (
    mdb_wahlperiode_membership_id, insart_lang, ins_lang,
    mdbins_von, mdbins_bis, fkt_lang, fktins_von, fktins_bis,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);

-- name: GetMdbInstitutionMemberships :many
SELECT * FROM mdb_institution_membership
WHERE mdb_wahlperiode_membership_id = ?
ORDER BY mdbins_von;

-- name: GetMdbInstitutionMembershipsByMdbId :many
SELECT im.* 
FROM mdb_institution_membership im
JOIN mdb_wahlperiode_membership wm ON im.mdb_wahlperiode_membership_id = wm.id
WHERE wm.mdb_id = ?
ORDER BY wm.wp, im.mdbins_von;

-- name: DeleteMdbInstitutionMembershipsByWahlperiode :exec
DELETE FROM mdb_institution_membership
WHERE mdb_wahlperiode_membership_id = ?;

-- ============================================================================
-- VIEWS AND COMPLEX QUERIES
-- ============================================================================

-- name: GetMdbCurrentMembers :many
SELECT * FROM mdb_current_members
ORDER BY nachname, vorname;

-- name: GetMdbFullName :one
SELECT * FROM mdb_full_names
WHERE mdb_id = ?;

-- name: GetMdbCareerSummary :one
SELECT * FROM mdb_career_summary
WHERE mdb_id = ?;

-- name: GetMdbFraktionSummaryByWP :many
SELECT * FROM mdb_fraktion_summary
WHERE wahlperiode = ?
ORDER BY anzahl_mitglieder DESC;

-- name: GetMdbFraktionSummaryAll :many
SELECT * FROM mdb_fraktion_summary
ORDER BY wahlperiode DESC, anzahl_mitglieder DESC;

-- ============================================================================
-- SEARCH AND LOOKUP QUERIES
-- ============================================================================

-- name: SearchMdbByName :many
SELECT DISTINCT
    mp.id,
    mn.nachname,
    mn.vorname,
    mn.ortszusatz,
    mn.anrede_titel,
    mn.akad_titel,
    mb.partei_kurz,
    mb.geschlecht
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
WHERE 
    (? = '' OR LOWER(mn.nachname) LIKE LOWER('%' || ? || '%'))
    AND (? = '' OR LOWER(mn.vorname) LIKE LOWER('%' || ? || '%'))
ORDER BY mn.nachname, mn.vorname
LIMIT ? OFFSET ?;

-- name: GetMdbByPartei :many
SELECT DISTINCT
    mp.id,
    mn.nachname,
    mn.vorname,
    mb.partei_kurz
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
WHERE mb.partei_kurz = ?
AND (mn.historie_von IS NULL OR mn.historie_von = '')
ORDER BY mn.nachname, mn.vorname;

-- name: GetMdbByWahlperiode :many
SELECT 
    mp.id,
    mn.nachname,
    mn.vorname,
    mb.partei_kurz,
    mwm.wp,
    mwm.mandatsart
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
WHERE mwm.wp = ?
AND (mn.historie_von IS NULL OR mn.historie_von = '')
ORDER BY mn.nachname, mn.vorname;

-- name: GetMdbWithFullDetails :one
SELECT 
    mp.id,
    mn.nachname,
    mn.vorname,
    mn.ortszusatz,
    mn.adel,
    mn.praefix,
    mn.anrede_titel,
    mn.akad_titel,
    mb.geburtsdatum,
    mb.geburtsort,
    mb.geburtsland,
    mb.sterbedatum,
    mb.geschlecht,
    mb.familienstand,
    mb.religion,
    mb.beruf,
    mb.vita_kurz,
    mb.veroeffentlichungspflichtiges,
    mb.partei_kurz
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
WHERE mp.id = ?
AND (mn.historie_von IS NULL OR mn.historie_von = '');

-- ============================================================================
-- STATISTICS AND COUNTS
-- ============================================================================

-- name: CountMdbPersons :one
SELECT COUNT(*) FROM mdb_person;

-- name: CountMdbNames :one
SELECT COUNT(*) FROM mdb_name;

-- name: CountMdbBiographical :one
SELECT COUNT(*) FROM mdb_biographical;

-- name: CountMdbWahlperiodeMemberships :one
SELECT COUNT(*) FROM mdb_wahlperiode_membership;

-- name: CountMdbInstitutionMemberships :one
SELECT COUNT(*) FROM mdb_institution_membership;

-- name: GetMdbStatsByWahlperiode :many
SELECT 
    wp,
    COUNT(*) as anzahl_mitglieder,
    COUNT(DISTINCT CASE WHEN mandatsart = 'Direktmandat' THEN mdb_id END) as direktmandate,
    COUNT(DISTINCT CASE WHEN mandatsart = 'Landesliste' THEN mdb_id END) as listenmandate
FROM mdb_wahlperiode_membership
GROUP BY wp
ORDER BY wp;

-- name: GetMdbStatsByGeschlecht :one
SELECT 
    COUNT(CASE WHEN geschlecht = 'männlich' THEN 1 END) as maennlich,
    COUNT(CASE WHEN geschlecht = 'weiblich' THEN 1 END) as weiblich,
    COUNT(CASE WHEN geschlecht IS NULL OR geschlecht = '' THEN 1 END) as unbekannt
FROM mdb_biographical;

-- name: GetMdbStatsByPartei :many
SELECT 
    partei_kurz,
    COUNT(*) as anzahl
FROM mdb_biographical
WHERE partei_kurz IS NOT NULL AND partei_kurz != ''
GROUP BY partei_kurz
ORDER BY anzahl DESC;

-- ============================================================================
-- PERSON-MDB LINKING
-- ============================================================================

-- name: CreatePersonMdbLink :exec
INSERT INTO person_mdb_link (
    person_id, mdb_id, match_confidence, match_method,
    verified_by, verified_at, notes,
    created_at, updated_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);

-- name: GetPersonMdbLinks :many
SELECT 
    person_id, mdb_id, match_confidence, match_method,
    verified_by, verified_at, notes,
    created_at, updated_at
FROM person_mdb_link
WHERE person_id = ?;

-- name: GetMdbPersonLinks :many
SELECT 
    person_id, mdb_id, match_confidence, match_method,
    verified_by, verified_at, notes,
    created_at, updated_at
FROM person_mdb_link
WHERE mdb_id = ?;

-- name: GetPersonMdbLink :one
SELECT 
    person_id, mdb_id, match_confidence, match_method,
    verified_by, verified_at, notes,
    created_at, updated_at
FROM person_mdb_link
WHERE person_id = ? AND mdb_id = ?;

-- name: UpdatePersonMdbLinkConfidence :exec
UPDATE person_mdb_link
SET 
    match_confidence = ?,
    match_method = ?,
    updated_at = datetime('now')
WHERE person_id = ? AND mdb_id = ?;

-- name: VerifyPersonMdbLink :exec
UPDATE person_mdb_link
SET 
    match_confidence = 'manual',
    verified_by = ?,
    verified_at = ?,
    notes = ?,
    updated_at = datetime('now')
WHERE person_id = ? AND mdb_id = ?;

-- name: DeletePersonMdbLink :exec
DELETE FROM person_mdb_link
WHERE person_id = ? AND mdb_id = ?;

-- name: GetUnlinkedDIPPersons :many
SELECT p.id, p.vorname, p.nachname
FROM person p
WHERE NOT EXISTS (
    SELECT 1 FROM person_mdb_link WHERE person_id = p.id
)
ORDER BY p.nachname, p.vorname
LIMIT ? OFFSET ?;

-- name: GetUnlinkedMdBPersons :many
SELECT mp.id, mn.vorname, mn.nachname
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id
WHERE (mn.historie_bis IS NULL OR mn.historie_bis = '')
  AND NOT EXISTS (
      SELECT 1 FROM person_mdb_link WHERE mdb_id = mp.id
  )
ORDER BY mn.nachname, mn.vorname
LIMIT ? OFFSET ?;

-- name: GetLinksByConfidence :many
SELECT 
    person_id, mdb_id, match_confidence, match_method,
    verified_by, verified_at, notes,
    created_at, updated_at
FROM person_mdb_link
WHERE match_confidence = ?
ORDER BY created_at DESC;

-- name: GetLinkStats :one
SELECT 
    COUNT(*) as total_links,
    COUNT(CASE WHEN match_confidence = 'exact' THEN 1 END) as exact,
    COUNT(CASE WHEN match_confidence = 'high' THEN 1 END) as high,
    COUNT(CASE WHEN match_confidence = 'medium' THEN 1 END) as medium,
    COUNT(CASE WHEN match_confidence = 'low' THEN 1 END) as low,
    COUNT(CASE WHEN match_confidence = 'manual' THEN 1 END) as manual,
    COUNT(CASE WHEN verified_by IS NOT NULL THEN 1 END) as verified
FROM person_mdb_link;
