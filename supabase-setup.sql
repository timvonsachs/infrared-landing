-- ============================================
-- INFRARED — Supabase Datenbank-Setup
-- Ausführen im SQL Editor:
-- https://vukzjrszplyzaiperdsj.supabase.co/project/default/sql
-- ============================================

-- 1. WAITLIST TABLE
CREATE TABLE IF NOT EXISTS waitlist (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  email TEXT NOT NULL,
  price_band TEXT,          -- '1000','2500','5000','10000'
  dm_band TEXT,             -- '2','6','18','40'
  est_leak TEXT,            -- berechneter Leakage-Wert (z.B. "3.200 €")
  utm TEXT,                 -- URL-Parameter
  source TEXT,              -- 'landing_page', 'instagram_bio', etc.
  status TEXT DEFAULT 'new' -- 'new','contacted','converted','unqualified'
);

-- RLS: Anon kann nur INSERT, nicht SELECT
ALTER TABLE waitlist ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon can insert" ON waitlist FOR INSERT TO anon WITH CHECK (true);

-- Eine E-Mail nur einmal auf der Liste.
CREATE UNIQUE INDEX IF NOT EXISTS idx_waitlist_email_unique ON waitlist (lower(email));

-- Index für schnelle Status-Abfragen
CREATE INDEX idx_waitlist_status ON waitlist(status);
CREATE INDEX idx_waitlist_created ON waitlist(created_at DESC);


-- 2. ANALYTICS TABLE
CREATE TABLE IF NOT EXISTS analytics_events (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  event TEXT NOT NULL,           -- 'page_view','leak_calculator','slider_move','zettel_open','waitlist_submit','scroll_depth'
  category TEXT DEFAULT 'engagement', -- 'engagement','conversion','navigation'
  label TEXT,                    -- z.B. 'hero_slider_dragged_left'
  value FLOAT,                   -- numerischer Wert (z.B. Leakage-€, Slider-Position)
  
  -- Session + Browser
  session_id TEXT,
  user_agent TEXT,
  
  -- Page context
  page TEXT DEFAULT 'landing',
  referrer TEXT,
  
  -- Extra properties (JSON für flexible Felder)
  properties JSONB DEFAULT '{}',
  
  -- IP/Herkunft (anonymisiert)
  ip_hash TEXT
);

ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon can insert analytics" ON analytics_events FOR INSERT TO anon WITH CHECK (true);

CREATE INDEX idx_analytics_event ON analytics_events(event);
CREATE INDEX idx_analytics_ts ON analytics_events(created_at DESC);
CREATE INDEX idx_analytics_session ON analytics_events(session_id);


-- 3. WAITLIST METADATA TABLE (UTM Tracking, Campaign Attribution)
CREATE TABLE IF NOT EXISTS waitlist_attribution (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  waitlist_id BIGINT REFERENCES waitlist(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  utm_source TEXT,
  utm_medium TEXT,
  utm_campaign TEXT,
  utm_content TEXT,
  utm_term TEXT,
  landing_url TEXT,
  referrer_url TEXT,
  time_on_page_sec INTEGER,
  calculator_used BOOLEAN DEFAULT false,
  calculator_value_eur FLOAT,
  slider_interacted BOOLEAN DEFAULT false
);

ALTER TABLE waitlist_attribution ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon can insert attribution" ON waitlist_attribution FOR INSERT TO anon WITH CHECK (true);


-- ============================================
-- VIEWS (für Dashboard)
--
-- ACHTUNG: Views umgehen die RLS der zugrundeliegenden Tabellen, weil sie
-- mit den Rechten ihres Erstellers laufen. Ohne REVOKE + security_invoker
-- sind sie mit dem oeffentlichen Key aus dem Browser lesbar — siehe
-- supabase-fix-rls.sql. Das war hier der Fall.
-- ============================================

-- Daily Stats
CREATE OR REPLACE VIEW v_daily_stats WITH (security_invoker = on) AS
SELECT 
  DATE(created_at) as day,
  COUNT(*) as signups,
  COUNT(CASE WHEN calculator_used THEN 1 END) as calculator_engaged,
  ROUND(AVG(calculator_value_eur)) as avg_leak_eur
FROM waitlist_attribution
GROUP BY DATE(created_at)
ORDER BY day DESC;

-- Event Summary (letzte 30 Tage)
CREATE OR REPLACE VIEW v_event_summary WITH (security_invoker = on) AS
SELECT 
  event,
  COUNT(*) as total,
  COUNT(DISTINCT session_id) as unique_sessions
FROM analytics_events
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY event
ORDER BY total DESC;
