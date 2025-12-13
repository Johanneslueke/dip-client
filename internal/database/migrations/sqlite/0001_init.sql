-- +goose Up
-- +goose StatementBegin
-- Core entity tables for German Bundestag DIP API data (SQLite version)
-- Normalized schema to reduce data duplication

-- Wahlperiode (Electoral period) - Reference table
CREATE TABLE wahlperiode (
    nummer INTEGER PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Bundesland (Federal state) - Reference table
CREATE TABLE bundesland (
    name TEXT PRIMARY KEY,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Person (Person master data)
CREATE TABLE person (
    id TEXT PRIMARY KEY,
    vorname TEXT NOT NULL,
    nachname TEXT NOT NULL,
    namenszusatz TEXT,
    titel TEXT NOT NULL,
    typ TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    basisdatum TEXT,
    datum TEXT,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- PersonRole (Person roles/functions)
CREATE TABLE person_role (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    person_id TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
    funktion TEXT NOT NULL,
    funktionszusatz TEXT,
    vorname TEXT NOT NULL,
    nachname TEXT NOT NULL,
    namenszusatz TEXT,
    fraktion TEXT,
    bundesland TEXT REFERENCES bundesland(name),
    ressort_titel TEXT,
    wahlkreiszusatz TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- PersonRole Wahlperiode junction table
CREATE TABLE person_role_wahlperiode (
    person_role_id INTEGER NOT NULL REFERENCES person_role(id) ON DELETE CASCADE,
    wahlperiode_nummer INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    PRIMARY KEY (person_role_id, wahlperiode_nummer)
);

-- Vorgang (Procedure/Process)
CREATE TABLE vorgang (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    typ TEXT NOT NULL,
    abstract TEXT,
    aktualisiert TEXT NOT NULL,
    archiv TEXT,
    beratungsstand TEXT,
    datum TEXT,
    gesta TEXT,
    kom TEXT,
    mitteilung TEXT,
    ratsdok TEXT,
    sek TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Vorgang arrays normalized
CREATE TABLE vorgang_initiative (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    initiative TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE vorgang_sachgebiet (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    sachgebiet TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE vorgang_zustimmungsbeduerftigkeit (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    zustimmungsbeduerftigkeit TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- VorgangDeskriptor
CREATE TABLE vorgang_deskriptor (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    typ TEXT NOT NULL,
    fundstelle INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (vorgang_id, name, typ)
);

-- Verkuendung
CREATE TABLE verkuendung (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    ausfertigungsdatum TEXT NOT NULL,
    verkuendungsdatum TEXT NOT NULL,
    einleitungstext TEXT NOT NULL,
    fundstelle TEXT NOT NULL,
    jahrgang TEXT NOT NULL,
    seite TEXT NOT NULL,
    heftnummer TEXT,
    pdf_url TEXT,
    rubrik_nr TEXT,
    titel TEXT,
    verkuendungsblatt_bezeichnung TEXT,
    verkuendungsblatt_kuerzel TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Inkrafttreten
CREATE TABLE inkrafttreten (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    datum TEXT NOT NULL,
    erlaeuterung TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- VorgangVerlinkung
CREATE TABLE vorgang_verlinkung (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    source_vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    target_vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    verweisung TEXT NOT NULL,
    gesta TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (source_vorgang_id, target_vorgang_id)
);

-- Ressort
CREATE TABLE ressort (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    titel TEXT NOT NULL UNIQUE,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Drucksache
CREATE TABLE drucksache (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    dokumentnummer TEXT NOT NULL,
    dokumentart TEXT NOT NULL,
    typ TEXT NOT NULL,
    drucksachetyp TEXT NOT NULL,
    herausgeber TEXT NOT NULL,
    datum TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    anlagen TEXT,
    autoren_anzahl INTEGER NOT NULL,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    pdf_hash TEXT,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum TEXT NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT,
    fundstelle_endquadrant TEXT,
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- DrucksacheText
CREATE TABLE drucksache_text (
    id TEXT PRIMARY KEY REFERENCES drucksache(id) ON DELETE CASCADE,
    text TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Drucksache Autoren Anzeige
CREATE TABLE drucksache_autor_anzeige (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    person_id TEXT NOT NULL REFERENCES person(id),
    autor_titel TEXT NOT NULL,
    title TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (drucksache_id, person_id)
);

-- Drucksache Ressort
CREATE TABLE drucksache_ressort (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    ressort_id INTEGER NOT NULL REFERENCES ressort(id),
    federfuehrend INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (drucksache_id, ressort_id)
);

-- Urheber
CREATE TABLE urheber (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    bezeichnung TEXT NOT NULL,
    titel TEXT NOT NULL,
    UNIQUE (bezeichnung, titel)
);

-- Drucksache Urheber
CREATE TABLE drucksache_urheber (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    urheber_id INTEGER NOT NULL REFERENCES urheber(id),
    rolle TEXT,
    einbringer INTEGER,
    PRIMARY KEY (drucksache_id, urheber_id)
);

-- Fundstelle Urheber
CREATE TABLE fundstelle_urheber (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT,
    urheber TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Plenarprotokoll
CREATE TABLE plenarprotokoll (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    dokumentnummer TEXT NOT NULL,
    dokumentart TEXT NOT NULL,
    typ TEXT NOT NULL,
    herausgeber TEXT NOT NULL,
    datum TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    pdf_hash TEXT,
    sitzungsbemerkung TEXT,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum TEXT NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT,
    fundstelle_endquadrant TEXT,
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- PlenarprotokollText
CREATE TABLE plenarprotokoll_text (
    id TEXT PRIMARY KEY REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    text TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Vorgangsposition
CREATE TABLE vorgangsposition (
    id TEXT PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    typ TEXT NOT NULL,
    dokumentart TEXT NOT NULL,
    datum TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    abstract TEXT,
    fortsetzung INTEGER NOT NULL,
    gang INTEGER NOT NULL,
    nachtrag INTEGER NOT NULL,
    aktivitaet_anzahl INTEGER NOT NULL,
    kom TEXT,
    ratsdok TEXT,
    sek TEXT,
    zuordnung TEXT NOT NULL,
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum TEXT NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT,
    fundstelle_endquadrant TEXT,
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Additional junction/relation tables
CREATE TABLE vorgangsposition_ressort (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    ressort_id INTEGER NOT NULL REFERENCES ressort(id),
    federfuehrend INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (vorgangsposition_id, ressort_id)
);

CREATE TABLE vorgangsposition_urheber (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    urheber_id INTEGER NOT NULL REFERENCES urheber(id),
    rolle TEXT,
    einbringer INTEGER,
    PRIMARY KEY (vorgangsposition_id, urheber_id)
);

CREATE TABLE ueberweisung (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    ausschuss TEXT NOT NULL,
    ausschuss_kuerzel TEXT NOT NULL,
    federfuehrung INTEGER NOT NULL,
    ueberweisungsart TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE beschlussfassung (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    beschlusstenor TEXT NOT NULL,
    abstimmungsart TEXT,
    mehrheit TEXT,
    abstimm_ergebnis_bemerkung TEXT,
    dokumentnummer TEXT,
    grundlage TEXT,
    seite TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE aktivitaet_anzeige (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    aktivitaetsart TEXT NOT NULL,
    titel TEXT NOT NULL,
    seite TEXT,
    pdf_url TEXT,
    display_order INTEGER NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE vorgangsposition_mitberaten (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    mitberaten_vorgang_id TEXT NOT NULL,
    mitberaten_titel TEXT NOT NULL,
    mitberaten_vorgangsposition TEXT NOT NULL,
    mitberaten_vorgangstyp TEXT NOT NULL,
    PRIMARY KEY (vorgangsposition_id, mitberaten_vorgang_id)
);

-- Aktivitaet
CREATE TABLE aktivitaet (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    aktivitaetsart TEXT NOT NULL,
    typ TEXT NOT NULL,
    dokumentart TEXT NOT NULL,
    datum TEXT NOT NULL,
    aktualisiert TEXT NOT NULL,
    abstract TEXT,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum TEXT NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT,
    fundstelle_endquadrant TEXT,
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum TEXT,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE aktivitaet_deskriptor (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    typ TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE (aktivitaet_id, name, typ)
);

CREATE TABLE aktivitaet_vorgangsbezug (
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (aktivitaet_id, vorgang_id, display_order)
);

CREATE TABLE drucksache_vorgangsbezug (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (drucksache_id, vorgang_id, display_order)
);

CREATE TABLE plenarprotokoll_vorgangsbezug (
    plenarprotokoll_id TEXT NOT NULL REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (plenarprotokoll_id, vorgang_id, display_order)
);

-- Indexes for common queries
CREATE INDEX idx_person_nachname ON person(nachname);
CREATE INDEX idx_person_wahlperiode ON person(wahlperiode);
CREATE INDEX idx_person_aktualisiert ON person(aktualisiert);

CREATE INDEX idx_vorgang_wahlperiode ON vorgang(wahlperiode);
CREATE INDEX idx_vorgang_vorgangstyp ON vorgang(vorgangstyp);
CREATE INDEX idx_vorgang_aktualisiert ON vorgang(aktualisiert);
CREATE INDEX idx_vorgang_datum ON vorgang(datum);
CREATE INDEX idx_vorgang_gesta ON vorgang(gesta);

CREATE INDEX idx_drucksache_datum ON drucksache(datum);
CREATE INDEX idx_drucksache_wahlperiode ON drucksache(wahlperiode);
CREATE INDEX idx_drucksache_dokumentnummer ON drucksache(dokumentnummer);
CREATE INDEX idx_drucksache_drucksachetyp ON drucksache(drucksachetyp);
CREATE INDEX idx_drucksache_aktualisiert ON drucksache(aktualisiert);

CREATE INDEX idx_plenarprotokoll_datum ON plenarprotokoll(datum);
CREATE INDEX idx_plenarprotokoll_wahlperiode ON plenarprotokoll(wahlperiode);
CREATE INDEX idx_plenarprotokoll_dokumentnummer ON plenarprotokoll(dokumentnummer);
CREATE INDEX idx_plenarprotokoll_aktualisiert ON plenarprotokoll(aktualisiert);

CREATE INDEX idx_vorgangsposition_vorgang_id ON vorgangsposition(vorgang_id);
CREATE INDEX idx_vorgangsposition_datum ON vorgangsposition(datum);
CREATE INDEX idx_vorgangsposition_aktualisiert ON vorgangsposition(aktualisiert);
CREATE INDEX idx_vorgangsposition_gang ON vorgangsposition(gang);

CREATE INDEX idx_aktivitaet_datum ON aktivitaet(datum);
CREATE INDEX idx_aktivitaet_wahlperiode ON aktivitaet(wahlperiode);
CREATE INDEX idx_aktivitaet_aktualisiert ON aktivitaet(aktualisiert);

CREATE INDEX idx_vorgang_deskriptor_vorgang_id ON vorgang_deskriptor(vorgang_id);
CREATE INDEX idx_vorgang_deskriptor_name ON vorgang_deskriptor(name);
CREATE INDEX idx_vorgang_deskriptor_fundstelle ON vorgang_deskriptor(fundstelle);

CREATE INDEX idx_aktivitaet_deskriptor_aktivitaet_id ON aktivitaet_deskriptor(aktivitaet_id);
CREATE INDEX idx_aktivitaet_deskriptor_name ON aktivitaet_deskriptor(name);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS aktivitaet_vorgangsbezug;
DROP TABLE IF EXISTS aktivitaet_deskriptor;
DROP TABLE IF EXISTS aktivitaet;
DROP TABLE IF EXISTS vorgangsposition_mitberaten;
DROP TABLE IF EXISTS aktivitaet_anzeige;
DROP TABLE IF EXISTS beschlussfassung;
DROP TABLE IF EXISTS ueberweisung;
DROP TABLE IF EXISTS vorgangsposition_urheber;
DROP TABLE IF EXISTS vorgangsposition_ressort;
DROP TABLE IF EXISTS vorgangsposition;
DROP TABLE IF EXISTS plenarprotokoll_vorgangsbezug;
DROP TABLE IF EXISTS plenarprotokoll_text;
DROP TABLE IF EXISTS plenarprotokoll;
DROP TABLE IF EXISTS fundstelle_urheber;
DROP TABLE IF EXISTS drucksache_vorgangsbezug;
DROP TABLE IF EXISTS drucksache_urheber;
DROP TABLE IF EXISTS urheber;
DROP TABLE IF EXISTS drucksache_ressort;
DROP TABLE IF EXISTS drucksache_autor_anzeige;
DROP TABLE IF EXISTS drucksache_text;
DROP TABLE IF EXISTS drucksache;
DROP TABLE IF EXISTS ressort;
DROP TABLE IF EXISTS vorgang_verlinkung;
DROP TABLE IF EXISTS inkrafttreten;
DROP TABLE IF EXISTS verkuendung;
DROP TABLE IF EXISTS vorgang_deskriptor;
DROP TABLE IF EXISTS vorgang_zustimmungsbeduerftigkeit;
DROP TABLE IF EXISTS vorgang_sachgebiet;
DROP TABLE IF EXISTS vorgang_initiative;
DROP TABLE IF EXISTS vorgang;
DROP TABLE IF EXISTS person_role_wahlperiode;
DROP TABLE IF EXISTS person_role;
DROP TABLE IF EXISTS person;
DROP TABLE IF EXISTS bundesland;
DROP TABLE IF EXISTS wahlperiode;
-- +goose StatementEnd
