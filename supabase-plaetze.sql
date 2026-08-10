-- ============================================
-- INFRARED — der Platz-Zähler
-- Ausführen im SQL Editor:
-- https://supabase.com/dashboard/project/vukzjrszplyzaiperdsj/sql
-- ============================================
--
-- WARUM NICHT AUS DER WARTELISTE GEZÄHLT WIRD. Naheliegend wäre
-- „frei = 5 − Anzahl Anmeldungen". Das wäre aus zwei Gründen falsch:
--
--   1. Eine Anmeldung ist kein Platz. Tim entscheidet nach dem Gespräch,
--      wen er nimmt — die Seite wüsste das nicht und würde Plätze als
--      vergeben melden, die es nicht sind.
--   2. Es wäre in zehn Sekunden manipulierbar. Fünf Anmeldungen mit
--      Wegwerf-Adressen, und die Seite behauptet, alles sei weg.
--
-- Deshalb setzt Tim die Zahl selbst — aber an EINER Stelle, ohne Deploy.
-- Änderung im Dashboard: Table Editor → plaetze → frei bearbeiten.

CREATE TABLE IF NOT EXISTS plaetze (
  id            SMALLINT PRIMARY KEY DEFAULT 1,
  gesamt        SMALLINT NOT NULL DEFAULT 5,
  frei          SMALLINT NOT NULL DEFAULT 5,
  aktualisiert  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT nur_eine_zeile CHECK (id = 1),
  CONSTRAINT frei_plausibel CHECK (frei >= 0 AND frei <= gesamt)
);

INSERT INTO plaetze (id, gesamt, frei) VALUES (1, 5, 5)
  ON CONFLICT (id) DO NOTHING;

-- LESEN JA, SCHREIBEN NEIN. Die Zeile enthält zwei Zahlen und nichts
-- Personenbezogenes — anon darf sie sehen. Ändern darf sie nur, wer im
-- Dashboard angemeldet ist (service_role umgeht RLS ohnehin).
ALTER TABLE plaetze ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anon darf lesen" ON plaetze;
CREATE POLICY "Anon darf lesen" ON plaetze FOR SELECT TO anon USING (true);

-- Zeitstempel automatisch mitführen, damit man sieht, wie alt die Zahl ist.
CREATE OR REPLACE FUNCTION plaetze_stempel() RETURNS trigger
  LANGUAGE plpgsql AS $$
BEGIN NEW.aktualisiert := now(); RETURN NEW; END $$;

DROP TRIGGER IF EXISTS trg_plaetze_stempel ON plaetze;
CREATE TRIGGER trg_plaetze_stempel BEFORE UPDATE ON plaetze
  FOR EACH ROW EXECUTE FUNCTION plaetze_stempel();


-- Gegenprobe nach dem Ausführen — muss die Zeile liefern:
--   curl "https://vukzjrszplyzaiperdsj.supabase.co/rest/v1/plaetze?select=gesamt,frei" \
--        -H "apikey: <publishable key>"
-- Und das hier muss scheitern (leeres Array = RLS greift):
--   curl -X PATCH ".../plaetze?id=eq.1" -d '{"frei":0}' -H "Prefer: return=representation"
