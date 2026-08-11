-- Content Funnel Tracking
CREATE TABLE IF NOT EXISTS content_funnel (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT now(),
  session_id TEXT,
  source TEXT,
  post_id TEXT,
  step TEXT,
  price_band TEXT,
  dm_band TEXT,
  est_leak TEXT,
  email TEXT,
  properties JSONB DEFAULT '{}'
);

ALTER TABLE content_funnel ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon can insert funnel" ON content_funnel FOR INSERT TO anon WITH CHECK (true);
CREATE INDEX idx_funnel_ts ON content_funnel(created_at DESC);
CREATE INDEX idx_funnel_source ON content_funnel(source);
CREATE INDEX idx_funnel_step ON content_funnel(step);

-- Funnel conversion view
CREATE OR REPLACE VIEW v_content_funnel AS
SELECT 
  DATE(created_at) as day,
  source,
  COUNT(DISTINCT CASE WHEN step='landing_load' THEN session_id END) as landing_visits,
  COUNT(DISTINCT CASE WHEN step='calculator_use' THEN session_id END) as calculator_uses,
  COUNT(DISTINCT CASE WHEN step='waitlist_submit' THEN session_id END) as waitlist_signups
FROM content_funnel
GROUP BY 1, 2
ORDER BY 1 DESC;
