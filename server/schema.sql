-- MétéoCarnet Mali — schéma PostgreSQL
-- À exécuter une fois dans pgAdmin (ou psql) sur la base cible.

CREATE TABLE IF NOT EXISTS stations (
  id     TEXT PRIMARY KEY,
  name   TEXT NOT NULL,
  lat    TEXT DEFAULT '',
  lon    TEXT DEFAULT '',
  alt    TEXT DEFAULT '',
  active BOOLEAN NOT NULL DEFAULT true
);

-- Si vous avez déjà créé la table "stations" avant cette mise à jour, ces lignes
-- la mettent à niveau sans perdre vos données (sans effet si déjà à jour) :
ALTER TABLE stations ADD COLUMN IF NOT EXISTS active BOOLEAN NOT NULL DEFAULT true;
-- Champs d'en-tête de la page 1 du TCM officiel (identité de la station et de son équipement) :
ALTER TABLE stations ADD COLUMN IF NOT EXISTS chef_station TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS etat TEXT DEFAULT 'MALI';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS heures_ouverture_debut TEXT DEFAULT '0000TU';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS heures_ouverture_fin TEXT DEFAULT '2400TU';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS altitude_capteur_baro TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS cor_inst TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS cor_gravite TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS hauteur_capteur_vent TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS type_capteur_vent TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS nature_girouette TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS nature_pluvio TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS cylindre TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS nature_helio TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS nature_evapo TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS nature_actino TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS renseignements_equipement TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS fuseau_horaire TEXT DEFAULT '';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS heure_midi_tu TEXT DEFAULT '1200';
ALTER TABLE stations ADD COLUMN IF NOT EXISTS heure_midi_legale TEXT DEFAULT '1200';

CREATE TABLE IF NOT EXISTS carnet_days (
  station_id             TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  date                   DATE NOT NULL,
  hours                  JSONB NOT NULL DEFAULT '{}'::jsonb,
  extras                 JSONB NOT NULL DEFAULT '{}'::jsonb,
  grains_orages          JSONB NOT NULL DEFAULT '[]'::jsonb,
  observations_speciales JSONB NOT NULL DEFAULT '[]'::jsonb,
  troubles_visibilite    JSONB NOT NULL DEFAULT '[]'::jsonb,
  precip_evenements      JSONB NOT NULL DEFAULT '[]'::jsonb,
  meta                   JSONB,
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (station_id, date)
);
-- Si la table existait déjà avant cette mise à jour, ces lignes la mettent à niveau
-- sans perdre vos données (sans effet si déjà à jour) :
ALTER TABLE carnet_days ADD COLUMN IF NOT EXISTS meta JSONB;
ALTER TABLE carnet_days ADD COLUMN IF NOT EXISTS troubles_visibilite JSONB NOT NULL DEFAULT '[]'::jsonb;
ALTER TABLE carnet_days ADD COLUMN IF NOT EXISTS precip_evenements JSONB NOT NULL DEFAULT '[]'::jsonb;

CREATE TABLE IF NOT EXISTS mensuel (
  station_id     TEXT NOT NULL REFERENCES stations(id) ON DELETE CASCADE,
  year           INT NOT NULL,
  month          INT NOT NULL,
  days           JSONB NOT NULL DEFAULT '[]'::jsonb,
  dominant_text  TEXT,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (station_id, year, month)
);

CREATE INDEX IF NOT EXISTS idx_carnet_days_station ON carnet_days(station_id, date);
CREATE INDEX IF NOT EXISTS idx_mensuel_station ON mensuel(station_id, year, month);

CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'observateur' CHECK (role IN ('admin','observateur')),
  station_id    TEXT REFERENCES stations(id) ON DELETE SET NULL,
  full_name     TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Si la table "users" existait déjà avant cette mise à jour (comptes par station),
-- ces deux lignes la mettent à niveau sans perdre vos données (sans effet si déjà à jour) :
ALTER TABLE users ADD COLUMN IF NOT EXISTS station_id TEXT REFERENCES stations(id) ON DELETE SET NULL;
ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name TEXT;

-- Table utilisée par connect-pg-simple pour stocker les sessions de connexion
-- (garde tout le monde connecté même après un redémarrage du serveur).
CREATE TABLE IF NOT EXISTS "session" (
  "sid" varchar NOT NULL COLLATE "default",
  "sess" json NOT NULL,
  "expire" timestamp(6) NOT NULL
) WITH (OIDS=FALSE);
ALTER TABLE "session" DROP CONSTRAINT IF EXISTS "session_pkey";
ALTER TABLE "session" ADD CONSTRAINT "session_pkey" PRIMARY KEY ("sid") NOT DEFERRABLE INITIALLY IMMEDIATE;
CREATE INDEX IF NOT EXISTS "IDX_session_expire" ON "session" ("expire");
