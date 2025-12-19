-- +goose Up
-- +goose StatementBegin
-- Fix views that reference old table names after FK migration
-- Migration 0011 renamed tables, but some views kept old references

-- Drop and recreate views with correct table references

DROP VIEW IF EXISTS mdb_current_members;
DROP VIEW IF EXISTS mdb_career_summary;
DROP VIEW IF EXISTS mdb_fraktion_summary;

-- View: Current MDB Members (latest wahlperiode)
CREATE VIEW mdb_current_members AS
SELECT 
    mp.id as mdb_id,
    mn.nachname,
    mn.vorname,
    mn.ortszusatz,
    mn.anrede_titel,
    mn.akad_titel,
    mb.partei_kurz,
    mb.geschlecht,
    mwm.wp as wahlperiode,
    mwm.mandatsart,
    mwm.wkr_name,
    mwm.wkr_land
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id AND mn.historie_bis IS NULL  -- Current name
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
WHERE mwm.wp = (SELECT MAX(wp) FROM mdb_wahlperiode_membership)  -- Latest wahlperiode
  AND mwm.mdbwp_bis IS NULL;  -- Still active

-- View: MDB Career Summary
CREATE VIEW mdb_career_summary AS
SELECT 
    mp.id as mdb_id,
    mn.nachname,
    mn.vorname,
    mb.partei_kurz,
    COUNT(DISTINCT mwm.wp) as anzahl_wahlperioden,
    MIN(mwm.wp) as erste_wahlperiode,
    MAX(mwm.wp) as letzte_wahlperiode,
    MIN(mwm.mdbwp_von) as mandat_beginn,
    MAX(CASE WHEN mwm.mdbwp_bis IS NULL THEN date('now') ELSE mwm.mdbwp_bis END) as mandat_ende,
    COUNT(DISTINCT mim.ins_lang) as anzahl_fraktionen
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id AND mn.historie_bis IS NULL
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
LEFT JOIN mdb_institution_membership mim ON mwm.id = mim.mdb_wahlperiode_membership_id 
    AND mim.insart_lang LIKE '%Fraktion%'
GROUP BY mp.id, mn.nachname, mn.vorname, mb.partei_kurz;

-- View: Fraktion Membership Summary
CREATE VIEW mdb_fraktion_summary AS
SELECT 
    mim.ins_lang as fraktion,
    mwm.wp as wahlperiode,
    COUNT(DISTINCT mp.id) as anzahl_mitglieder,
    COUNT(DISTINCT CASE WHEN mwm.mandatsart = 'Direktmandat' THEN mp.id END) as direktmandate,
    COUNT(DISTINCT CASE WHEN mwm.mandatsart = 'Landesliste' THEN mp.id END) as listenmandate
FROM mdb_person mp
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
JOIN mdb_institution_membership mim ON mwm.id = mim.mdb_wahlperiode_membership_id
WHERE mim.insart_lang LIKE '%Fraktion%'
GROUP BY mim.ins_lang, mwm.wp
ORDER BY mwm.wp DESC, anzahl_mitglieder DESC;

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin

-- Drop corrected views
DROP VIEW IF EXISTS mdb_fraktion_summary;
DROP VIEW IF EXISTS mdb_career_summary;
DROP VIEW IF EXISTS mdb_current_members;

-- Recreate with old references (for rollback)
CREATE VIEW mdb_current_members AS
SELECT 
    mp.id as mdb_id,
    mn.nachname,
    mn.vorname,
    mn.ortszusatz,
    mn.anrede_titel,
    mn.akad_titel,
    mb.partei_kurz,
    mb.geschlecht,
    mwm.wp as wahlperiode,
    mwm.mandatsart,
    mwm.wkr_name,
    mwm.wkr_land
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id AND mn.historie_bis IS NULL
JOIN mdb_biographical mb ON mp.id = mb.mdb_id
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
WHERE mwm.wp = (SELECT MAX(wp) FROM mdb_wahlperiode_membership)
  AND mwm.mdbwp_bis IS NULL;

CREATE VIEW mdb_career_summary AS
SELECT 
    mp.id as mdb_id,
    mn.nachname,
    mn.vorname,
    mb.partei_kurz,
    COUNT(DISTINCT mwm.wp) as anzahl_wahlperioden,
    MIN(mwm.wp) as erste_wahlperiode,
    MAX(mwm.wp) as letzte_wahlperiode,
    MIN(mwm.mdbwp_von) as mandat_beginn,
    MAX(CASE WHEN mwm.mdbwp_bis IS NULL THEN date('now') ELSE mwm.mdbwp_bis END) as mandat_ende,
    COUNT(DISTINCT mim.ins_lang) as anzahl_fraktionen
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id AND mn.historie_bis IS NULL
LEFT JOIN mdb_biographical mb ON mp.id = mb.mdb_id
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
LEFT JOIN mdb_institution_membership mim ON mwm.id = mim.mdb_wahlperiode_membership_id 
    AND mim.insart_lang LIKE '%Fraktion%'
GROUP BY mp.id, mn.nachname, mn.vorname, mb.partei_kurz;

CREATE VIEW mdb_fraktion_summary AS
SELECT 
    mim.ins_lang as fraktion,
    mwm.wp as wahlperiode,
    COUNT(DISTINCT mp.id) as anzahl_mitglieder,
    COUNT(DISTINCT CASE WHEN mwm.mandatsart = 'Direktmandat' THEN mp.id END) as direktmandate,
    COUNT(DISTINCT CASE WHEN mwm.mandatsart = 'Landesliste' THEN mp.id END) as listenmandate
FROM mdb_person mp
JOIN mdb_wahlperiode_membership mwm ON mp.id = mwm.mdb_id
JOIN mdb_institution_membership mim ON mwm.id = mim.mdb_wahlperiode_membership_id
WHERE mim.insart_lang LIKE '%Fraktion%'
GROUP BY mim.ins_lang, mwm.wp
ORDER BY mwm.wp DESC, anzahl_mitglieder DESC;

-- +goose StatementEnd
