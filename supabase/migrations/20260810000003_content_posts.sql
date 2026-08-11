-- Content Posts — Resonance-Supabase Bridge
-- Jeder Post aus Resonance bekommt hier eine Zeile, damit Waitlist-Signups
-- per JOIN einem Post zugeordnet werden können.
CREATE TABLE IF NOT EXISTS content_posts (
  id TEXT PRIMARY KEY,               -- resonance post slug (z.B. 'baeker-analogie')
  platform TEXT DEFAULT 'instagram',
  posted_at TIMESTAMPTZ,
  hook TEXT,
  topic TEXT,
  format TEXT,
  z_score FLOAT,                     -- aus Resonance engine.js: z gegen eigene Baseline
  views_24h INTEGER,
  created_at TIMESTAMPTZ DEFAULT now(),
  properties JSONB DEFAULT '{}'
);

ALTER TABLE content_posts ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anon can read posts" ON content_posts FOR SELECT TO anon USING (true);
CREATE POLICY "Anon can insert posts" ON content_posts FOR INSERT TO anon WITH CHECK (true);
CREATE INDEX idx_posts_posted ON content_posts(posted_at DESC);

-- Content→Revenue View: JOIN waitlist via utm (enthält ?p=...)
CREATE OR REPLACE VIEW v_post_attribution AS
SELECT 
  p.id as post_id,
  p.hook,
  p.platform,
  p.z_score,
  p.views_24h,
  COUNT(w.id) as signups,
  COUNT(DISTINCT w.id) as unique_emails
FROM content_posts p
LEFT JOIN waitlist w ON w.utm LIKE '%p=' || p.id || '%'
GROUP BY p.id, p.hook, p.platform, p.z_score, p.views_24h
ORDER BY signups DESC;
