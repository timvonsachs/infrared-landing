#!/usr/bin/env python3
"""
Resonance → Supabase Bridge
Synct neue Posts mit Metriken aus Resonance (SQLite) nach Supabase content_posts.
Läuft als Cron (z.B. alle 6h) oder wird von n8n nach einem Sync getriggert.
"""
import sqlite3, requests, json, sys, os
from datetime import datetime, timezone

SUPABASE_URL = "https://vukzjrszplyzaiperdsj.supabase.co"
ANON_KEY = "sb_publishable_4zE5bvt8EPIA1UWX8fP6Ww_GIHjBdjE"
RESONANCE_DB = os.path.expanduser("~/Resonance/resonance.db")

hdrs = {
    "apikey": ANON_KEY,
    "Authorization": f"Bearer {ANON_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

def sync():
    if not os.path.exists(RESONANCE_DB):
        print(f"Resonance DB not found at {RESONANCE_DB}")
        return

    db = sqlite3.connect(RESONANCE_DB)
    db.row_factory = sqlite3.Row

    # Get posts with metrics from Resonance
    posts = db.execute("""
        SELECT p.id, p.platform, p.posted_at, p.hook, p.topic, p.format,
               p.gut_tip, p.tip_blind, p.duration_sec,
               m.views, m.likes, m.comments, m.shares, m.saved,
               m.hold3s_pct, m.follows, m.reach,
               m.captured_at, m.horizon
        FROM posts p
        LEFT JOIN metrics m ON m.post_id = p.id
        WHERE p.dublette_von IS NULL
          AND p.platform IN ('instagram', 'tiktok')
        ORDER BY p.posted_at DESC
        LIMIT 30
    """).fetchall()

    synced = 0
    for p in posts:
        # Generate a clean post_id slug from hook or topic
        slug = (p['hook'] or p['topic'] or f"post-{p['id']}")[:80]
        slug = slug.lower().replace(" ", "-").replace("'", "").replace('"', '')

        # Check if already synced
        r = requests.get(
            f"{SUPABASE_URL}/rest/v1/content_posts?id=eq.{slug}",
            headers={"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"}
        )
        if r.status_code == 200 and len(r.json()) > 0:
            # Update existing
            existing = r.json()[0]
            payload = {
                "platform": p['platform'],
                "z_score": existing.get('z_score'),  # computed by Resonance engine
                "views_24h": p['views'],
                "properties": {
                    "likes": p['likes'], "comments": p['comments'],
                    "shares": p['shares'], "saved": p['saved'],
                    "hold3s_pct": p['hold3s_pct'],
                    "follows": p['follows'],
                    "duration_sec": p['duration_sec'],
                    "gut_tip": p['gut_tip'],
                    "horizon": p['horizon'],
                }
            }
            r2 = requests.patch(
                f"{SUPABASE_URL}/rest/v1/content_posts?id=eq.{slug}",
                headers=hdrs, json=payload
            )
            if r2.ok:
                synced += 1
        else:
            # Insert new
            payload = {
                "id": slug,
                "platform": p['platform'],
                "posted_at": p['posted_at'],
                "hook": p['hook'],
                "topic": p['topic'],
                "format": p['format'],
                "views_24h": p['views'],
                "properties": {
                    "likes": p['likes'], "comments": p['comments'],
                    "shares": p['shares'], "saved": p['saved'],
                    "hold3s_pct": p['hold3s_pct'],
                    "follows": p['follows'],
                    "duration_sec": p['duration_sec'],
                    "gut_tip": p['gut_tip'],
                    "horizon": p['horizon'],
                }
            }
            r2 = requests.post(
                f"{SUPABASE_URL}/rest/v1/content_posts",
                headers=hdrs, json=payload
            )
            if r2.ok:
                synced += 1

    db.close()
    print(f"Synced {synced}/{len(posts)} posts to Supabase")
    return synced

if __name__ == "__main__":
    sync()
