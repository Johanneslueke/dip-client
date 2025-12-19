-- +goose Up
-- +goose StatementBegin
-- Migration for MdB Stammdaten (Master Data) from MDB_STAMMDATEN.XML
-- Based on DTD structure: MDB_STAMMDATEN.DTD
-- 
-- Data Structure:
-- - MDB (Mitglied des Bundestages) - Main person entity
-- - NAME+ (multiple names with history)
-- - BIOGRAFISCHE_ANGABEN (biographical data)
-- - WAHLPERIODE+ (multiple electoral period memberships)
-- - INSTITUTION* (multiple institution memberships per wahlperiode)

-- Document version tracking
CREATE TABLE mdb_stammdaten_version (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    version TEXT NOT NULL,
    import_date TEXT NOT NULL DEFAULT (datetime('now')),
    source_file TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- MDB Person - Main entity for Bundestag members
-- Maps to <MDB> element
CREATE TABLE mdb_person (
    id TEXT PRIMARY KEY,                    -- <ID> - 8-digit identifier
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- MDB Name - Name components with history
-- Maps to <NAME> element (can occur multiple times per person)
-- Tracks name changes during mandate (e.g., marriage)
CREATE TABLE mdb_name (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    nachname TEXT NOT NULL,                 -- <NACHNAME> - Last name
    vorname TEXT NOT NULL,                  -- <VORNAME> - First name
    ortszusatz TEXT,                        -- <ORTSZUSATZ> - Location suffix for disambiguation, e.g., (Berlin)
    adel TEXT,                              -- <ADEL> - Nobility title (Freiherr, Baron, etc.)
    praefix TEXT,                           -- <PRAEFIX> - Name prefix (von, van, etc.)
    anrede_titel TEXT,                      -- <ANREDE_TITEL> - Salutation title (Dr., Prof., etc.)
    akad_titel TEXT,                        -- <AKAD_TITEL> - Academic title (Dr.-Ing., Prof. Dr. h. c., etc.)
    historie_von TEXT,                      -- <HISTORIE_VON> - Valid from date (DD.MM.YYYY)
    historie_bis TEXT,                      -- <HISTORIE_BIS> - Valid until date (DD.MM.YYYY), NULL if current
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_mdb_name_mdb_id ON mdb_name(mdb_id);
CREATE INDEX idx_mdb_name_nachname ON mdb_name(nachname);
CREATE INDEX idx_mdb_name_vorname ON mdb_name(vorname);
CREATE INDEX idx_mdb_name_historie_von ON mdb_name(historie_von);

-- MDB Biographical Data
-- Maps to <BIOGRAFISCHE_ANGABEN> element (one per person)
-- All fields optional according to DTD
CREATE TABLE mdb_biographical (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_id TEXT NOT NULL UNIQUE REFERENCES mdb_person(id) ON DELETE CASCADE,
    geburtsdatum TEXT,                      -- <GEBURTSDATUM> - Birth date
    geburtsort TEXT,                        -- <GEBURTSORT> - Place of birth
    geburtsland TEXT,                       -- <GEBURTSLAND> - Country of birth
    sterbedatum TEXT,                       -- <STERBEDATUM> - Death date
    geschlecht TEXT,                        -- <GESCHLECHT> - Gender (männlich, weiblich, etc.)
    familienstand TEXT,                     -- <FAMILIENSTAND> - Marital status
    religion TEXT,                          -- <RELIGION> - Religion
    beruf TEXT,                             -- <BERUF> - Profession
    partei_kurz TEXT,                       -- <PARTEI_KURZ> - Party affiliation (short form)
    vita_kurz TEXT,                         -- <VITA_KURZ> - Short biography (only current wahlperiode)
    veroeffentlichungspflichtiges TEXT,     -- <VEROEFFENTLICHUNGSPFLICHTIGES> - Mandatory disclosures
                                            -- Categories per §1 VR (Verhaltensregeln):
                                            -- 1. Professional activity before Bundestag membership
                                            -- 2. Paid activities alongside mandate
                                            -- 3. Functions in companies
                                            -- 4. Functions in public law corporations
                                            -- 5. Functions in associations/foundations
                                            -- 6. Agreements on future activities/assets
                                            -- 7. Shareholdings in companies
                                            -- 8. Donations
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_mdb_biographical_mdb_id ON mdb_biographical(mdb_id);
CREATE INDEX idx_mdb_biographical_partei_kurz ON mdb_biographical(partei_kurz);
CREATE INDEX idx_mdb_biographical_geschlecht ON mdb_biographical(geschlecht);
CREATE INDEX idx_mdb_biographical_geburtsdatum ON mdb_biographical(geburtsdatum);

-- MDB Wahlperiode Membership
-- Maps to <WAHLPERIODE> element (multiple per person)
-- Records MDB's membership in specific electoral periods
CREATE TABLE mdb_wahlperiode_membership (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_id TEXT NOT NULL REFERENCES mdb_person(id) ON DELETE CASCADE,
    wp INTEGER NOT NULL,                    -- <WP> - Wahlperiode number (1-2 digits)
    mdbwp_von TEXT NOT NULL,                -- <MDBWP_VON> - Membership start date (DD.MM.YYYY)
    mdbwp_bis TEXT,                         -- <MDBWP_BIS> - Membership end date (DD.MM.YYYY), NULL if ongoing
    wkr_nummer TEXT,                        -- <WKR_NUMMER> - Electoral district number (1-3 digits)
    wkr_name TEXT,                          -- <WKR_NAME> - Electoral district name
    wkr_land TEXT,                          -- <WKR_LAND> - Federal state of electoral district
    liste TEXT,                             -- <LISTE> - List affiliation (normally: Bundesland abbreviation)
                                            -- Exceptions: * Saarland integration, ** Berlin West amendment, *** elected by Volkskammer
    mandatsart TEXT,                        -- <MANDATSART> - Type of mandate (Direktmandat, Landesliste, Volkskammer)
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (mdb_id, wp)                     -- One membership record per person per wahlperiode
);

CREATE INDEX idx_mdb_wahlperiode_membership_mdb_id ON mdb_wahlperiode_membership(mdb_id);
CREATE INDEX idx_mdb_wahlperiode_membership_wp ON mdb_wahlperiode_membership(wp);
CREATE INDEX idx_mdb_wahlperiode_membership_mandatsart ON mdb_wahlperiode_membership(mandatsart);
CREATE INDEX idx_mdb_wahlperiode_membership_wkr_land ON mdb_wahlperiode_membership(wkr_land);
CREATE INDEX idx_mdb_wahlperiode_membership_mdbwp_von ON mdb_wahlperiode_membership(mdbwp_von);

-- MDB Institution Membership
-- Maps to <INSTITUTION> element (multiple per wahlperiode, 0 or more)
-- Records MDB's membership in institutions (primarily fraktionen/groups)
-- Note: Only fraktion data for historical periods, full data for current wahlperiode
CREATE TABLE mdb_institution_membership (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    mdb_wahlperiode_membership_id INTEGER NOT NULL REFERENCES mdb_wahlperiode_membership(id) ON DELETE CASCADE,
    insart_lang TEXT NOT NULL,              -- <INSART_LANG> - Institution type (e.g., Fraktion, Ausschuss)
                                            -- Typically "Fraktion/Gruppe" for historical data
    ins_lang TEXT NOT NULL,                 -- <INS_LANG> - Institution name (e.g., Fraktion der CDU/CSU)
    mdbins_von TEXT,                        -- <MDBINS_VON> - Institution membership start (DD.MM.YYYY)
    mdbins_bis TEXT,                        -- <MDBINS_BIS> - Institution membership end (DD.MM.YYYY)
    fkt_lang TEXT,                          -- <FKT_LANG> - Function in institution
                                            -- (e.g., Ordentliches Mitglied, Vorsitzender, Stellvertreter)
    fktins_von TEXT,                        -- <FKTINS_VON> - Function start date (DD.MM.YYYY)
    fktins_bis TEXT,                        -- <FKTINS_BIS> - Function end date (DD.MM.YYYY)
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX idx_mdb_institution_membership_wahlperiode_id ON mdb_institution_membership(mdb_wahlperiode_membership_id);
CREATE INDEX idx_mdb_institution_membership_insart_lang ON mdb_institution_membership(insart_lang);
CREATE INDEX idx_mdb_institution_membership_ins_lang ON mdb_institution_membership(ins_lang);
CREATE INDEX idx_mdb_institution_membership_mdbins_von ON mdb_institution_membership(mdbins_von);

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

-- View: MDB Full Name with History
CREATE VIEW mdb_full_names AS
SELECT 
    mp.id as mdb_id,
    mn.id as name_id,
    CASE 
        WHEN mn.anrede_titel IS NOT NULL AND mn.anrede_titel != '' 
        THEN mn.anrede_titel || ' ' || mn.vorname || ' ' || mn.nachname
        ELSE mn.vorname || ' ' || mn.nachname
    END as display_name,
    CASE 
        WHEN mn.praefix IS NOT NULL AND mn.praefix != ''
        THEN mn.praefix || ' ' || mn.nachname
        ELSE mn.nachname
    END as full_nachname,
    mn.vorname,
    mn.nachname,
    mn.ortszusatz,
    mn.adel,
    mn.praefix,
    mn.anrede_titel,
    mn.akad_titel,
    mn.historie_von,
    mn.historie_bis,
    CASE 
        WHEN mn.historie_bis IS NULL THEN 1
        ELSE 0
    END as is_current
FROM mdb_person mp
JOIN mdb_name mn ON mp.id = mn.mdb_id;

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
DROP VIEW IF EXISTS mdb_fraktion_summary;
DROP VIEW IF EXISTS mdb_career_summary;
DROP VIEW IF EXISTS mdb_full_names;
DROP VIEW IF EXISTS mdb_current_members;

DROP TABLE IF EXISTS mdb_institution_membership;
DROP TABLE IF EXISTS mdb_wahlperiode_membership;
DROP TABLE IF EXISTS mdb_biographical;
DROP TABLE IF EXISTS mdb_name;
DROP TABLE IF EXISTS mdb_person;
DROP TABLE IF EXISTS mdb_stammdaten_version;
-- +goose StatementEnd
