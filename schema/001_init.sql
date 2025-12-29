-- Health DB (SQLite) - initial schema
-- Usage (sqlite3):
--   sqlite3 data/health.db ".read schema/001_init.sql"
--
-- Notes:
-- - `PRAGMA foreign_keys=ON` is connection-level; keep it ON in your app.
-- - Timestamps are stored as ISO-8601 UTC text, e.g. 2025-12-29T12:34:56.789Z

PRAGMA foreign_keys = ON;

BEGIN;

-- ---------- core ----------

CREATE TABLE IF NOT EXISTS person (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  display_name TEXT,
  notes       TEXT
);

-- Demographics / relatively static profile fields
CREATE TABLE IF NOT EXISTS person_profile (
  person_id   TEXT PRIMARY KEY NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  birth_date  TEXT, -- YYYY-MM-DD
  sex         TEXT CHECK (sex IN ('female','male','intersex','unknown') OR sex IS NULL),
  height_cm   REAL CHECK (height_cm > 0 OR height_cm IS NULL),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

-- Data source: device/app/manual input
CREATE TABLE IF NOT EXISTS source (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  kind        TEXT NOT NULL CHECK (kind IN ('device','app','manual','import')),
  name        TEXT NOT NULL,
  version     TEXT,
  identifier  TEXT -- e.g. bundle id / device model
  -- uniqueness is enforced via expression index (see below)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_source_identity
  ON source(kind, name, COALESCE(version,''), COALESCE(identifier,''));

-- Generic measurement dictionary (extensible)
CREATE TABLE IF NOT EXISTS measurement_type (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  code        TEXT NOT NULL UNIQUE,  -- stable machine code, e.g. 'weight_kg'
  display_name TEXT NOT NULL,        -- human-readable
  category    TEXT NOT NULL CHECK (category IN ('body','vital','activity','sleep','nutrition','lab','other')),
  unit        TEXT,                  -- e.g. 'kg', 'bpm', 'mmHg'
  value_kind  TEXT NOT NULL CHECK (value_kind IN ('number','text','json')),
  min_num     REAL,
  max_num     REAL,
  notes       TEXT
);

-- Single point for time-series health measurements
CREATE TABLE IF NOT EXISTS measurement (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  type_id     TEXT NOT NULL REFERENCES measurement_type(id),
  taken_at    TEXT NOT NULL, -- ISO-8601 UTC
  value_num   REAL,
  value_text  TEXT,
  value_json  TEXT, -- JSON string (optional)
  unit        TEXT, -- override unit for this row (otherwise use measurement_type.unit)
  source_id   TEXT REFERENCES source(id),
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (
    (value_num IS NOT NULL AND value_text IS NULL AND value_json IS NULL)
    OR (value_num IS NULL AND value_text IS NOT NULL AND value_json IS NULL)
    OR (value_num IS NULL AND value_text IS NULL AND value_json IS NOT NULL)
  )
);

CREATE INDEX IF NOT EXISTS idx_measurement_person_time
  ON measurement(person_id, taken_at DESC);

CREATE INDEX IF NOT EXISTS idx_measurement_person_type_time
  ON measurement(person_id, type_id, taken_at DESC);

-- ---------- activity / sleep ----------

CREATE TABLE IF NOT EXISTS activity_session (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  activity_type TEXT NOT NULL, -- free text: running / cycling / strength / ...
  start_at    TEXT NOT NULL,
  end_at      TEXT,
  duration_min REAL CHECK (duration_min >= 0 OR duration_min IS NULL),
  distance_m  REAL CHECK (distance_m >= 0 OR distance_m IS NULL),
  steps       INTEGER CHECK (steps >= 0 OR steps IS NULL),
  calories_kcal REAL CHECK (calories_kcal >= 0 OR calories_kcal IS NULL),
  avg_hr_bpm  REAL CHECK (avg_hr_bpm >= 0 OR avg_hr_bpm IS NULL),
  source_id   TEXT REFERENCES source(id),
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (end_at IS NULL OR end_at >= start_at)
);

CREATE INDEX IF NOT EXISTS idx_activity_person_start
  ON activity_session(person_id, start_at DESC);

CREATE TABLE IF NOT EXISTS sleep_session (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  start_at    TEXT NOT NULL,
  end_at      TEXT NOT NULL,
  quality     INTEGER CHECK (quality BETWEEN 1 AND 5 OR quality IS NULL),
  source_id   TEXT REFERENCES source(id),
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (end_at > start_at)
);

CREATE INDEX IF NOT EXISTS idx_sleep_person_start
  ON sleep_session(person_id, start_at DESC);

-- ---------- nutrition ----------

CREATE TABLE IF NOT EXISTS food_item (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  name        TEXT NOT NULL,
  brand       TEXT,
  barcode     TEXT,
  -- per 100g nutrition (optional)
  kcal_per_100g     REAL CHECK (kcal_per_100g >= 0 OR kcal_per_100g IS NULL),
  protein_g_per_100g REAL CHECK (protein_g_per_100g >= 0 OR protein_g_per_100g IS NULL),
  carbs_g_per_100g   REAL CHECK (carbs_g_per_100g >= 0 OR carbs_g_per_100g IS NULL),
  fat_g_per_100g     REAL CHECK (fat_g_per_100g >= 0 OR fat_g_per_100g IS NULL),
  fiber_g_per_100g   REAL CHECK (fiber_g_per_100g >= 0 OR fiber_g_per_100g IS NULL),
  sugar_g_per_100g   REAL CHECK (sugar_g_per_100g >= 0 OR sugar_g_per_100g IS NULL),
  sodium_mg_per_100g REAL CHECK (sodium_mg_per_100g >= 0 OR sodium_mg_per_100g IS NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_food_item_identity
  ON food_item(COALESCE(barcode,''), name, COALESCE(brand,''));

CREATE TABLE IF NOT EXISTS nutrition_intake (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  eaten_at    TEXT NOT NULL,
  food_item_id TEXT REFERENCES food_item(id),
  description TEXT, -- manual description if no food_item
  amount_g    REAL CHECK (amount_g > 0 OR amount_g IS NULL),
  -- computed / provided totals for this intake
  kcal        REAL CHECK (kcal >= 0 OR kcal IS NULL),
  protein_g   REAL CHECK (protein_g >= 0 OR protein_g IS NULL),
  carbs_g     REAL CHECK (carbs_g >= 0 OR carbs_g IS NULL),
  fat_g       REAL CHECK (fat_g >= 0 OR fat_g IS NULL),
  fiber_g     REAL CHECK (fiber_g >= 0 OR fiber_g IS NULL),
  sugar_g     REAL CHECK (sugar_g >= 0 OR sugar_g IS NULL),
  sodium_mg   REAL CHECK (sodium_mg >= 0 OR sodium_mg IS NULL),
  source_id   TEXT REFERENCES source(id),
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (food_item_id IS NOT NULL OR description IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_nutrition_person_time
  ON nutrition_intake(person_id, eaten_at DESC);

-- ---------- meds / conditions / symptoms ----------

CREATE TABLE IF NOT EXISTS medication (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  dose        REAL CHECK (dose > 0 OR dose IS NULL),
  dose_unit   TEXT,
  route       TEXT, -- oral / injection / ...
  frequency   TEXT, -- free text
  start_date  TEXT, -- YYYY-MM-DD
  end_date    TEXT, -- YYYY-MM-DD
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_medication_person
  ON medication(person_id, name);

CREATE TABLE IF NOT EXISTS medication_intake (
  id            TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  medication_id TEXT NOT NULL REFERENCES medication(id) ON DELETE CASCADE,
  taken_at      TEXT NOT NULL,
  dose          REAL CHECK (dose > 0 OR dose IS NULL),
  dose_unit     TEXT,
  status        TEXT NOT NULL DEFAULT 'taken' CHECK (status IN ('planned','taken','skipped')),
  notes         TEXT,
  created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_med_intake_time
  ON medication_intake(medication_id, taken_at DESC);

CREATE TABLE IF NOT EXISTS condition (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  onset_date  TEXT,
  resolved_date TEXT,
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (resolved_date IS NULL OR onset_date IS NULL OR resolved_date >= onset_date)
);

CREATE INDEX IF NOT EXISTS idx_condition_person
  ON condition(person_id, name);

CREATE TABLE IF NOT EXISTS symptom (
  id          TEXT PRIMARY KEY NOT NULL DEFAULT (lower(hex(randomblob(16)))),
  person_id   TEXT NOT NULL REFERENCES person(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  started_at  TEXT NOT NULL,
  ended_at    TEXT,
  severity    INTEGER CHECK (severity BETWEEN 0 AND 10 OR severity IS NULL),
  notes       TEXT,
  created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  CHECK (ended_at IS NULL OR ended_at >= started_at)
);

CREATE INDEX IF NOT EXISTS idx_symptom_person_start
  ON symptom(person_id, started_at DESC);

-- ---------- seed measurement types ----------

INSERT OR IGNORE INTO measurement_type (code, display_name, category, unit, value_kind, min_num, max_num, notes)
VALUES
  ('weight_kg',          '体重',           'body',     'kg',    'number', 0,   500, NULL),
  ('height_cm',          '身高',           'body',     'cm',    'number', 0,   300, NULL),
  ('bmi',                'BMI',            'body',     NULL,    'number', 0,   200, '可由体重/身高计算'),
  ('body_fat_pct',       '体脂率',         'body',     '%',     'number', 0,   100, NULL),
  ('heart_rate_bpm',     '心率',           'vital',    'bpm',   'number', 0,   300, NULL),
  ('systolic_mmhg',      '收缩压',         'vital',    'mmHg',  'number', 0,   300, NULL),
  ('diastolic_mmhg',     '舒张压',         'vital',    'mmHg',  'number', 0,   200, NULL),
  ('spo2_pct',           '血氧饱和度',     'vital',    '%',     'number', 0,   100, NULL),
  ('body_temp_c',        '体温',           'vital',    '°C',    'number', 25,   45, NULL),
  ('blood_glucose_mmolL','血糖',           'lab',      'mmol/L','number', 0,   60,  NULL),
  ('steps_count',        '步数',           'activity', 'count', 'number', 0,   NULL, NULL),
  ('active_energy_kcal', '活动消耗热量',   'activity', 'kcal',  'number', 0,   NULL, NULL),
  ('sleep_duration_min', '睡眠时长',       'sleep',    'min',   'number', 0,   2000, NULL),
  ('water_ml',           '饮水量',         'nutrition','ml',    'number', 0,   10000, NULL);

COMMIT;


