-- ============================================
-- INFRARED — RLS-Reparatur
-- Geprüft am 10.08.2026 gegen die laufende Datenbank.
-- Ausführen im SQL Editor:
-- https://supabase.com/dashboard/project/vukzjrszplyzaiperdsj/sql
-- ============================================
--
-- BEFUND. Die Tabellen sind dicht: anon kann weder lesen noch ändern noch
-- löschen (empirisch geprüft, nicht nur aus dem Schema gelesen).
--
-- Die VIEWS sind es nicht. Views laufen in Postgres standardmäßig mit den
-- Rechten ihres Erstellers und umgehen damit die RLS der Tabellen, aus denen
-- sie lesen. Beide Views waren mit dem öffentlichen Key im Browser abrufbar:
--
--   v_event_summary  -> 585 Slider-Bewegungen, 33 Seitenaufrufe, 30 Sitzungen
--   v_daily_stats    -> Anmeldungen pro Tag
--
-- Keine E-Mail-Adressen, aber der komplette Traffic und die Conversion in
-- Echtzeit — für jeden lesbar, der den Key aus dem Quelltext kopiert.


-- 1 · DEN ZUGRIFF ENTZIEHEN ------------------------------------------------
-- Die Views sind für ein Dashboard gedacht. Das läuft mit dem service_role
-- key und braucht die anon-Rolle nicht.

REVOKE ALL ON v_daily_stats   FROM anon, authenticated;
REVOKE ALL ON v_event_summary FROM anon, authenticated;


-- 2 · UND ZUSÄTZLICH DIE URSACHE BESEITIGEN --------------------------------
-- security_invoker lässt die View mit den Rechten des AUFRUFERS laufen.
-- Damit greift die RLS der Tabellen auch dann, wenn jemand später
-- versehentlich wieder GRANT vergibt. Zwei Schlösser statt einem.
-- (Postgres 15+; Supabase liegt darüber.)

ALTER VIEW v_daily_stats   SET (security_invoker = on);
ALTER VIEW v_event_summary SET (security_invoker = on);


-- 3 · DOPPELTE ANMELDUNGEN VERHINDERN --------------------------------------
-- waitlist hatte keinen UNIQUE-Index. Wer zweimal auf „Platz sichern"
-- drückt, steht zweimal drin — bei fünf Plätzen ist das nicht egal.
-- Vorher aufräumen, sonst schlägt der Index fehl.

DELETE FROM waitlist a USING waitlist b
  WHERE a.id > b.id AND lower(a.email) = lower(b.email);

CREATE UNIQUE INDEX IF NOT EXISTS idx_waitlist_email_unique
  ON waitlist (lower(email));


-- 4 · TESTDATEN ENTFERNEN --------------------------------------------------
-- Beim Sicherheitstest ist eine Zeile entstanden, und die headless-Läufe
-- beim Bauen der Seite haben echte Analytics-Events geschrieben. Beides
-- gehört nicht in die Auswertung.

DELETE FROM waitlist
  WHERE email = 'pruefung-loeschen@example.invalid' OR source = 'security_check';

DELETE FROM analytics_events
  WHERE event = 'test'
     OR created_at < '2026-08-10 23:59:59+02'::timestamptz;   -- alles von heute


-- 5 · GEGENPROBE -----------------------------------------------------------
-- Nach dem Ausführen muss dieser Aufruf ein leeres Array liefern:
--
--   curl "https://vukzjrszplyzaiperdsj.supabase.co/rest/v1/v_event_summary?select=*" \
--        -H "apikey: <publishable key>"
--
-- Kommen weiterhin Zahlen: Schritt 1 hat nicht gegriffen.
