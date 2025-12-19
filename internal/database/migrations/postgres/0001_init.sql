-- +goose Up
-- +goose StatementBegin
-- Core entity tables for German Bundestag DIP API data
-- Normalized schema to reduce data duplication

-- Wahlperiode (Electoral period) - Reference table
CREATE TABLE wahlperiode (
    nummer INTEGER PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bundesland (Federal state) - Reference table
CREATE TABLE bundesland (
    name TEXT PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Person (Person master data)
CREATE TABLE person (
    id TEXT PRIMARY KEY,
    vorname TEXT NOT NULL,
    nachname TEXT NOT NULL,
    namenszusatz TEXT,
    titel TEXT NOT NULL,
    typ TEXT NOT NULL,
    aktualisiert TIMESTAMPTZ NOT NULL,
    basisdatum DATE,
    datum DATE,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PersonRole (Person roles/functions)
CREATE TABLE person_role (
    id SERIAL PRIMARY KEY,
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PersonRole Wahlperiode junction table (many-to-many)
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
    aktualisiert TIMESTAMPTZ NOT NULL,
    archiv TEXT,
    beratungsstand TEXT,
    datum DATE,
    gesta TEXT,
    kom TEXT,
    mitteilung TEXT,
    ratsdok TEXT,
    sek TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgang initiative (array field normalized)
CREATE TABLE vorgang_initiative (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    initiative TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgang sachgebiet (array field normalized)
CREATE TABLE vorgang_sachgebiet (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    sachgebiet TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgang zustimmungsbeduerftigkeit (array field normalized)
CREATE TABLE vorgang_zustimmungsbeduerftigkeit (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    zustimmungsbeduerftigkeit TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- VorgangDeskriptor (Descriptors/Keywords for Vorgang)
CREATE TABLE vorgang_deskriptor (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    typ TEXT NOT NULL CHECK (typ IN ('Freier Deskriptor', 'Geograph. Begriffe', 'Institutionen', 'Personen', 'Rechtsmaterialien', 'Sachbegriffe')),
    fundstelle BOOLEAN NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (vorgang_id, name, typ)
);

-- Verkuendung (Publication/Promulgation)
CREATE TABLE verkuendung (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    ausfertigungsdatum DATE NOT NULL,
    verkuendungsdatum DATE NOT NULL,
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Inkrafttreten (Entry into force)
CREATE TABLE inkrafttreten (
    id SERIAL PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    datum DATE NOT NULL,
    erlaeuterung TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- VorgangVerlinkung (Vorgang cross-reference)
CREATE TABLE vorgang_verlinkung (
    id SERIAL PRIMARY KEY,
    source_vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    target_vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    verweisung TEXT NOT NULL,
    gesta TEXT,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_vorgang_id, target_vorgang_id)
);

-- Ressort (Ministry/Department)
CREATE TABLE ressort (
    id SERIAL PRIMARY KEY,
    titel TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Drucksache (Parliamentary document)
CREATE TABLE drucksache (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    dokumentnummer TEXT NOT NULL,
    dokumentart TEXT NOT NULL CHECK (dokumentart = 'Drucksache'),
    typ TEXT NOT NULL CHECK (typ = 'Dokument'),
    drucksachetyp TEXT NOT NULL,
    herausgeber TEXT NOT NULL CHECK (herausgeber IN ('BT', 'BR')),
    datum DATE NOT NULL,
    aktualisiert TIMESTAMPTZ NOT NULL,
    anlagen TEXT,
    autoren_anzahl INTEGER NOT NULL,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    pdf_hash TEXT,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    -- Fundstelle embedded (denormalized for performance)
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum DATE NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT CHECK (fundstelle_anfangsquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_endquadrant TEXT CHECK (fundstelle_endquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- DrucksacheText (Document with full text)
CREATE TABLE drucksache_text (
    id TEXT PRIMARY KEY REFERENCES drucksache(id) ON DELETE CASCADE,
    text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Drucksache Autoren Anzeige (Display authors - denormalized)
CREATE TABLE drucksache_autor_anzeige (
    id SERIAL PRIMARY KEY,
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    person_id TEXT NOT NULL REFERENCES person(id),
    autor_titel TEXT NOT NULL,
    title TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (drucksache_id, person_id)
);

-- Drucksache Ressort (many-to-many with leadership flag)
CREATE TABLE drucksache_ressort (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    ressort_id INTEGER NOT NULL REFERENCES ressort(id),
    federfuehrend BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (drucksache_id, ressort_id)
);

-- Urheber (Originator - corporate body)
CREATE TABLE urheber (
    id SERIAL PRIMARY KEY,
    bezeichnung TEXT NOT NULL,
    titel TEXT NOT NULL,
    UNIQUE (bezeichnung, titel)
);

-- Drucksache Urheber (many-to-many)
CREATE TABLE drucksache_urheber (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    urheber_id INTEGER NOT NULL REFERENCES urheber(id),
    rolle TEXT CHECK (rolle IN ('B', 'U')),
    einbringer BOOLEAN,
    PRIMARY KEY (drucksache_id, urheber_id)
);

-- Fundstelle Urheber (for denormalized fundstelle)
CREATE TABLE fundstelle_urheber (
    id SERIAL PRIMARY KEY,
    drucksache_id TEXT REFERENCES drucksache(id) ON DELETE CASCADE,
    plenarprotokoll_id TEXT,
    urheber TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Plenarprotokoll (Plenary protocol)
CREATE TABLE plenarprotokoll (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    dokumentnummer TEXT NOT NULL,
    dokumentart TEXT NOT NULL CHECK (dokumentart = 'Plenarprotokoll'),
    typ TEXT NOT NULL CHECK (typ = 'Dokument'),
    herausgeber TEXT NOT NULL CHECK (herausgeber IN ('BT', 'BR', 'BV', 'EK')),
    datum DATE NOT NULL,
    aktualisiert TIMESTAMPTZ NOT NULL,
    pdf_hash TEXT,
    sitzungsbemerkung TEXT,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    wahlperiode INTEGER REFERENCES wahlperiode(nummer),
    -- Fundstelle embedded (denormalized for performance)
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum DATE NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT CHECK (fundstelle_anfangsquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_endquadrant TEXT CHECK (fundstelle_endquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- PlenarprotokollText (Protocol with full text)
CREATE TABLE plenarprotokoll_text (
    id TEXT PRIMARY KEY REFERENCES plenarprotokoll(id) ON DELETE CASCADE,
    text TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgangsposition (Procedure step/position)
CREATE TABLE vorgangsposition (
    id TEXT PRIMARY KEY,
    vorgang_id TEXT NOT NULL REFERENCES vorgang(id) ON DELETE CASCADE,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    typ TEXT NOT NULL CHECK (typ = 'Vorgangsposition'),
    dokumentart TEXT NOT NULL CHECK (dokumentart IN ('Drucksache', 'Plenarprotokoll')),
    datum DATE NOT NULL,
    aktualisiert TIMESTAMPTZ NOT NULL,
    abstract TEXT,
    fortsetzung BOOLEAN NOT NULL,
    gang BOOLEAN NOT NULL,
    nachtrag BOOLEAN NOT NULL,
    aktivitaet_anzahl INTEGER NOT NULL,
    kom TEXT,
    ratsdok TEXT,
    sek TEXT,
    zuordnung TEXT NOT NULL CHECK (zuordnung IN ('BT', 'BR', 'BV', 'EK')),
    -- Fundstelle embedded (denormalized for performance)
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum DATE NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT CHECK (fundstelle_anfangsquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_endquadrant TEXT CHECK (fundstelle_endquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgangsposition Ressort (many-to-many)
CREATE TABLE vorgangsposition_ressort (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    ressort_id INTEGER NOT NULL REFERENCES ressort(id),
    federfuehrend BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (vorgangsposition_id, ressort_id)
);

-- Vorgangsposition Urheber (many-to-many)
CREATE TABLE vorgangsposition_urheber (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    urheber_id INTEGER NOT NULL REFERENCES urheber(id),
    rolle TEXT CHECK (rolle IN ('B', 'U')),
    einbringer BOOLEAN,
    PRIMARY KEY (vorgangsposition_id, urheber_id)
);

-- Ueberweisung (Committee referral)
CREATE TABLE ueberweisung (
    id SERIAL PRIMARY KEY,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    ausschuss TEXT NOT NULL,
    ausschuss_kuerzel TEXT NOT NULL,
    federfuehrung BOOLEAN NOT NULL,
    ueberweisungsart TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Beschlussfassung (Decision/Resolution)
CREATE TABLE beschlussfassung (
    id SERIAL PRIMARY KEY,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    beschlusstenor TEXT NOT NULL,
    abstimmungsart TEXT CHECK (abstimmungsart IN ('Abstimmung durch Aufruf der Länder', 'Geheime Wahl', 'Hammelsprung', 'Namentliche Abstimmung', 'Verhältniswahl')),
    mehrheit TEXT CHECK (mehrheit IN ('Absolute Mehrheit', 'Zweidrittelmehrheit')),
    abstimm_ergebnis_bemerkung TEXT,
    dokumentnummer TEXT,
    grundlage TEXT,
    seite TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- AktivitaetAnzeige (Display activities for Vorgangsposition)
CREATE TABLE aktivitaet_anzeige (
    id SERIAL PRIMARY KEY,
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    aktivitaetsart TEXT NOT NULL,
    titel TEXT NOT NULL,
    seite TEXT,
    pdf_url TEXT,
    display_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Vorgangsposition Mitberaten (cross-reference to other Vorgang)
CREATE TABLE vorgangsposition_mitberaten (
    vorgangsposition_id TEXT NOT NULL REFERENCES vorgangsposition(id) ON DELETE CASCADE,
    mitberaten_vorgang_id TEXT NOT NULL,
    mitberaten_titel TEXT NOT NULL,
    mitberaten_vorgangsposition TEXT NOT NULL,
    mitberaten_vorgangstyp TEXT NOT NULL,
    PRIMARY KEY (vorgangsposition_id, mitberaten_vorgang_id)
);

-- Aktivitaet (Activity)
CREATE TABLE aktivitaet (
    id TEXT PRIMARY KEY,
    titel TEXT NOT NULL,
    aktivitaetsart TEXT NOT NULL,
    typ TEXT NOT NULL CHECK (typ = 'Aktivität'),
    dokumentart TEXT NOT NULL CHECK (dokumentart IN ('Drucksache', 'Plenarprotokoll')),
    datum DATE NOT NULL,
    aktualisiert TIMESTAMPTZ NOT NULL,
    abstract TEXT,
    vorgangsbezug_anzahl INTEGER NOT NULL,
    wahlperiode INTEGER NOT NULL REFERENCES wahlperiode(nummer),
    -- Fundstelle embedded (denormalized for performance)
    fundstelle_dokumentnummer TEXT NOT NULL,
    fundstelle_datum DATE NOT NULL,
    fundstelle_dokumentart TEXT NOT NULL,
    fundstelle_herausgeber TEXT NOT NULL,
    fundstelle_id TEXT NOT NULL,
    fundstelle_drucksachetyp TEXT,
    fundstelle_anlagen TEXT,
    fundstelle_anfangsseite INTEGER,
    fundstelle_endseite INTEGER,
    fundstelle_anfangsquadrant TEXT CHECK (fundstelle_anfangsquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_endquadrant TEXT CHECK (fundstelle_endquadrant IN ('A', 'B', 'C', 'D')),
    fundstelle_seite TEXT,
    fundstelle_pdf_url TEXT,
    fundstelle_top INTEGER,
    fundstelle_top_zusatz TEXT,
    fundstelle_frage_nummer TEXT,
    fundstelle_verteildatum DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Deskriptor (Descriptors/Keywords for Aktivitaet)
CREATE TABLE aktivitaet_deskriptor (
    id SERIAL PRIMARY KEY,
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    typ TEXT NOT NULL CHECK (typ IN ('Freier Deskriptor', 'Geograph. Begriffe', 'Institutionen', 'Personen', 'Rechtsmaterialien', 'Sachbegriffe')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (aktivitaet_id, name, typ)
);

-- Aktivitaet Vorgangsbezug (references to first 4 related Vorgang)
CREATE TABLE aktivitaet_vorgangsbezug (
    aktivitaet_id TEXT NOT NULL REFERENCES aktivitaet(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangsposition TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (aktivitaet_id, vorgang_id, display_order)
);

-- Drucksache Vorgangsbezug (references to first 4 related Vorgang)
CREATE TABLE drucksache_vorgangsbezug (
    drucksache_id TEXT NOT NULL REFERENCES drucksache(id) ON DELETE CASCADE,
    vorgang_id TEXT NOT NULL,
    titel TEXT NOT NULL,
    vorgangstyp TEXT NOT NULL,
    display_order INTEGER NOT NULL,
    PRIMARY KEY (drucksache_id, vorgang_id, display_order)
);

-- Plenarprotokoll Vorgangsbezug (references to first 4 related Vorgang)
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
CREATE INDEX idx_vorgang_gesta ON vorgang(gesta) WHERE gesta IS NOT NULL;

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
CREATE INDEX idx_vorgangsposition_gang ON vorgangsposition(gang) WHERE gang = TRUE;

CREATE INDEX idx_aktivitaet_datum ON aktivitaet(datum);
CREATE INDEX idx_aktivitaet_wahlperiode ON aktivitaet(wahlperiode);
CREATE INDEX idx_aktivitaet_aktualisiert ON aktivitaet(aktualisiert);

CREATE INDEX idx_vorgang_deskriptor_vorgang_id ON vorgang_deskriptor(vorgang_id);
CREATE INDEX idx_vorgang_deskriptor_name ON vorgang_deskriptor(name);
CREATE INDEX idx_vorgang_deskriptor_fundstelle ON vorgang_deskriptor(fundstelle) WHERE fundstelle = TRUE;

CREATE INDEX idx_aktivitaet_deskriptor_aktivitaet_id ON aktivitaet_deskriptor(aktivitaet_id);
CREATE INDEX idx_aktivitaet_deskriptor_name ON aktivitaet_deskriptor(name);
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS aktivitaet_vorgangsbezug CASCADE;
DROP TABLE IF EXISTS aktivitaet_deskriptor CASCADE;
DROP TABLE IF EXISTS aktivitaet CASCADE;
DROP TABLE IF EXISTS vorgangsposition_mitberaten CASCADE;
DROP TABLE IF EXISTS aktivitaet_anzeige CASCADE;
DROP TABLE IF EXISTS beschlussfassung CASCADE;
DROP TABLE IF EXISTS ueberweisung CASCADE;
DROP TABLE IF EXISTS vorgangsposition_urheber CASCADE;
DROP TABLE IF EXISTS vorgangsposition_ressort CASCADE;
DROP TABLE IF EXISTS vorgangsposition CASCADE;
DROP TABLE IF EXISTS plenarprotokoll_vorgangsbezug CASCADE;
DROP TABLE IF EXISTS plenarprotokoll_text CASCADE;
DROP TABLE IF EXISTS plenarprotokoll CASCADE;
DROP TABLE IF EXISTS fundstelle_urheber CASCADE;
DROP TABLE IF EXISTS drucksache_vorgangsbezug CASCADE;
DROP TABLE IF EXISTS drucksache_urheber CASCADE;
DROP TABLE IF EXISTS urheber CASCADE;
DROP TABLE IF EXISTS drucksache_ressort CASCADE;
DROP TABLE IF EXISTS drucksache_autor_anzeige CASCADE;
DROP TABLE IF EXISTS drucksache_text CASCADE;
DROP TABLE IF EXISTS drucksache CASCADE;
DROP TABLE IF EXISTS ressort CASCADE;
DROP TABLE IF EXISTS vorgang_verlinkung CASCADE;
DROP TABLE IF EXISTS inkrafttreten CASCADE;
DROP TABLE IF EXISTS verkuendung CASCADE;
DROP TABLE IF EXISTS vorgang_deskriptor CASCADE;
DROP TABLE IF EXISTS vorgang_zustimmungsbeduerftigkeit CASCADE;
DROP TABLE IF EXISTS vorgang_sachgebiet CASCADE;
DROP TABLE IF EXISTS vorgang_initiative CASCADE;
DROP TABLE IF EXISTS vorgang CASCADE;
DROP TABLE IF EXISTS person_role_wahlperiode CASCADE;
DROP TABLE IF EXISTS person_role CASCADE;
DROP TABLE IF EXISTS person CASCADE;
DROP TABLE IF EXISTS bundesland CASCADE;
DROP TABLE IF EXISTS wahlperiode CASCADE;
-- +goose StatementEnd
