-- Examples for Health DB
-- Run:
--   sqlite3 data/health.db ".read docs/examples.sql"

PRAGMA foreign_keys = ON;

-- 1) create a person
INSERT INTO person (display_name, notes) VALUES ('me', 'primary profile');

-- 2) add a data source
INSERT INTO source (kind, name, version, identifier)
VALUES ('manual', 'cli', NULL, NULL);

-- helpers: get ids (copy results in your client)
-- SELECT id FROM person LIMIT 1;
-- SELECT id FROM source WHERE kind='manual' AND name='cli' LIMIT 1;
-- SELECT id FROM measurement_type WHERE code='weight_kg';

-- 3) insert some measurements (replace the SELECTs with actual ids in your client if needed)
INSERT INTO measurement (person_id, type_id, taken_at, value_num, source_id, notes)
SELECT
  (SELECT id FROM person ORDER BY created_at DESC LIMIT 1),
  (SELECT id FROM measurement_type WHERE code='weight_kg'),
  '2025-12-29T08:00:00.000Z',
  72.4,
  (SELECT id FROM source ORDER BY created_at DESC LIMIT 1),
  'morning'
;

INSERT INTO measurement (person_id, type_id, taken_at, value_num, source_id)
SELECT
  (SELECT id FROM person ORDER BY created_at DESC LIMIT 1),
  (SELECT id FROM measurement_type WHERE code='heart_rate_bpm'),
  '2025-12-29T08:01:00.000Z',
  62,
  (SELECT id FROM source ORDER BY created_at DESC LIMIT 1)
;

-- 4) query latest weight
SELECT
  m.taken_at,
  m.value_num AS weight,
  COALESCE(m.unit, mt.unit) AS unit
FROM measurement m
JOIN measurement_type mt ON mt.id = m.type_id
WHERE m.person_id = (SELECT id FROM person ORDER BY created_at DESC LIMIT 1)
  AND mt.code = 'weight_kg'
ORDER BY m.taken_at DESC
LIMIT 10;

-- 5) daily weight trend
SELECT
  date(m.taken_at) AS day,
  AVG(m.value_num) AS avg_weight_kg,
  MIN(m.value_num) AS min_weight_kg,
  MAX(m.value_num) AS max_weight_kg,
  COUNT(*) AS n
FROM measurement m
JOIN measurement_type mt ON mt.id = m.type_id
WHERE mt.code='weight_kg'
GROUP BY day
ORDER BY day DESC
LIMIT 30;

-- 6) 7-day activity calories
SELECT
  date(a.start_at) AS day,
  SUM(a.calories_kcal) AS kcal
FROM activity_session a
WHERE a.person_id = (SELECT id FROM person ORDER BY created_at DESC LIMIT 1)
  AND a.start_at >= datetime('now','-7 days')
GROUP BY day
ORDER BY day DESC;


