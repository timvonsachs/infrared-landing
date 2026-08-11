-- Resonance Data Layer — vollständiger Plattform-Spiegel in Supabase
-- Jede Tabelle spiegelt eine SQLite-Tabelle aus Resonance (~/Resonance/resonance.db)
-- Purpose: Labs-Analysen, Content↔Beziehungs-Kopplung, Perplexity-Zugriff

-- 1. TASTE PAIRS — Geschmacksurteile im DPO-Format
CREATE TABLE IF NOT EXISTS resonance_taste_pairs (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  kind TEXT,                    -- hook | skript | zeile
  kontext TEXT,                 -- Merkmals-Signatur, macht das Paar interpretierbar
  gewaehlt TEXT,                -- was Tim nahm
  verworfen JSONB,              -- JSON-Array der abgelehnten
  grund TEXT,                   -- Tims Begründung (der eigentliche Rohstoff)
  quelle TEXT DEFAULT 'forge'
);

-- 2. RETENTION CURVES — Sekunden-Urteile tausender Zuschauer
CREATE TABLE IF NOT EXISTS resonance_curves (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  post_id INTEGER,
  quelle TEXT DEFAULT 'screenshot',
  dauer_sec REAL,
  punkte_json JSONB,            -- Array von {sekunde, halt_pct}
  notiz TEXT
);

-- 3. PREDICTIONS — Maschinen-Vorhersagen MIT festgeschriebener z-Vorhersage
CREATE TABLE IF NOT EXISTS resonance_predictions (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  modus TEXT,                   -- EXPLOIT | EXPLORE
  thema TEXT,
  hook TEXT,
  text_hook TEXT,
  format TEXT,
  plattform TEXT,
  merkmal TEXT,                 -- tragendes Merkmal MIT Nenner
  begruendung TEXT,
  z_vorhersage REAL,            -- die festgeschriebene Behauptung
  genommen INTEGER DEFAULT 0    -- 1 = Tim hat es gedreht
);

-- 4. EXPERIMENTS — randomisierte Content-Experimente
CREATE TABLE IF NOT EXISTS resonance_experiments (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  faktor TEXT,                  -- was variiert wird (z.B. 'text_hook_typ')
  arme_json JSONB,              -- Stufen (z.B. ["zahl","frage"])
  frage TEXT,                   -- Forschungsfrage im Klartext
  status TEXT DEFAULT 'offen',  -- offen | entschieden | abgebrochen
  notiz TEXT
);

-- 5. EXPERIMENT ROLLS — Münzwürfe, BEVOR gepostet wurde
CREATE TABLE IF NOT EXISTS resonance_rolls (
  id INTEGER PRIMARY KEY,
  experiment_id INTEGER REFERENCES resonance_experiments(id),
  gewuerfelt_at TIMESTAMPTZ,
  arm TEXT,
  post_id INTEGER,              -- erst NACH dem Posten gesetzt
  eingeloest_at TIMESTAMPTZ,
  verfallen INTEGER DEFAULT 0
);

-- 6. FORGE RUNS — vollständige Schmiede-Läufe
CREATE TABLE IF NOT EXISTS resonance_forge_runs (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  thema TEXT,
  rohmaterial TEXT,
  dauer_sec INTEGER,
  hook TEXT,                    -- gewählter gesprochener Hook
  text_hook TEXT,               -- gewählter Overlay-Hook
  skript_json JSONB,            -- Zeilen des Schreibers
  urteile_json JSONB,           -- Urteile des Schlächters
  final_json JSONB,             -- überlebende Zeilen
  runden INTEGER DEFAULT 1,
  post_id INTEGER               -- gesetzt, sobald daraus ein Post wurde
);

-- 7. FINDINGS — Wissenschaftler-Befunde
CREATE TABLE IF NOT EXISTS resonance_findings (
  id INTEGER PRIMARY KEY,
  created_at TIMESTAMPTZ,
  kurzfassung TEXT,
  nichts_neues INTEGER DEFAULT 0,
  inhalt_json JSONB
);

-- 8. COMMENTS — Kommentare als offene Vorgänge
CREATE TABLE IF NOT EXISTS resonance_comments (
  id INTEGER PRIMARY KEY,
  extern_id TEXT UNIQUE,
  post_id INTEGER,
  autor TEXT,
  text TEXT,
  erstellt_at TIMESTAMPTZ,
  von_mir INTEGER DEFAULT 0,
  entwurf TEXT,
  wert TEXT,                   -- frage | gespraech | lob
  beantwortet INTEGER DEFAULT 0,
  beantwortet_at TIMESTAMPTZ,
  uebersprungen INTEGER DEFAULT 0
);

-- RLS: Anon kann lesen (für Perplexity, Labs), nur sync-Skript schreibt
ALTER TABLE resonance_taste_pairs ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_curves ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_predictions ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_experiments ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_rolls ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_forge_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_findings ENABLE ROW LEVEL SECURITY;
ALTER TABLE resonance_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anon can read resonance data" ON resonance_taste_pairs FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_curves FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_predictions FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_experiments FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_rolls FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_forge_runs FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_findings FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can read resonance data" ON resonance_comments FOR SELECT TO anon USING (true);

CREATE POLICY "Anon can insert resonance data" ON resonance_taste_pairs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_curves FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_predictions FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_experiments FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_rolls FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_forge_runs FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_findings FOR INSERT TO anon WITH CHECK (true);
CREATE POLICY "Anon can insert resonance data" ON resonance_comments FOR INSERT TO anon WITH CHECK (true);

-- INDICES
CREATE INDEX idx_taste_pairs_ts ON resonance_taste_pairs(created_at DESC);
CREATE INDEX idx_curves_ts ON resonance_curves(created_at DESC);
CREATE INDEX idx_predictions_ts ON resonance_predictions(created_at DESC);
CREATE INDEX idx_findings_ts ON resonance_findings(created_at DESC);
