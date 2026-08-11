#!/usr/bin/env python3
"""
Resonance → Supabase Bridge v2
Vollständige Datenhebung aller wissenschaftlich relevanten Tabellen.
Läuft als Cron (alle 6h) oder via n8n nach Sync-Trigger.

Tabellen:
  content_posts            — Posts + Metriken (v1, bestehend)
  resonance_taste_pairs    — Geschmacksurteile (DPO-Format)
  resonance_curves         — Retentionskurven (Sekunden-Urteile)
  resonance_predictions    — Maschinen-Vorhersagen
  resonance_experiments    — Randomisierte Experimente
  resonance_rolls          — Münzwürfe
  resonance_forge_runs     — Schmiede-Läufe
  resonance_findings       — Wissenschaftler-Befunde
  resonance_comments       — Kommentare als offene Vorgänge
"""
import sqlite3, requests, json, sys, os, uuid
from datetime import datetime, timezone

SUPABASE_URL = "https://vukzjrszplyzaiperdsj.supabase.co"
ANON_KEY = "sb_publishable_4zE5bvt8EPIA1UWX8fP6Ww_GIHjBdjE"
RESONANCE_DB = os.path.expanduser("~/Resonance/resonance.db")

hdrs_r = {"apikey": ANON_KEY, "Authorization": f"Bearer {ANON_KEY}"}
hdrs_w = {**hdrs_r, "Content-Type": "application/json", "Prefer": "return=minimal"}

def upsert(table, id_col, id_val, payload):
    """INSERT or UPDATE based on existence check."""
    r = requests.get(
        f"{SUPABASE_URL}/rest/v1/{table}?{id_col}=eq.{id_val}",
        headers=hdrs_r
    )
    if r.ok and len(r.json()) > 0:
        return requests.patch(
            f"{SUPABASE_URL}/rest/v1/{table}?{id_col}=eq.{id_val}",
            headers=hdrs_w, json=payload
        ).ok
    else:
        payload[id_col] = id_val
        return requests.post(
            f"{SUPABASE_URL}/rest/v1/{table}",
            headers=hdrs_w, json=payload
        ).ok

def sync():
    if not os.path.exists(RESONANCE_DB):
        print(f"✗ Resonance DB not found at {RESONANCE_DB}")
        return {}

    db = sqlite3.connect(RESONANCE_DB)
    db.row_factory = sqlite3.Row
    counts = {}

    # ---- 1. Posts + Metrics (v1) ----
    posts = db.execute("""
        SELECT p.id, p.platform, p.posted_at, p.hook, p.topic, p.format,
               p.gut_tip, p.tip_blind, p.duration_sec, p.energy,
               p.experiment_group, p.features_json, p.source,
               p.transcript, p.vorschlag_id,
               m.views, m.likes, m.comments, m.shares,
               m.hold3s_pct, m.follows,
               m.captured_at, m.horizon
        FROM posts p
        LEFT JOIN metrics m ON m.post_id = p.id
        WHERE p.dublette_von IS NULL AND p.platform IN ('instagram','tiktok')
        ORDER BY p.posted_at DESC LIMIT 50
    """).fetchall()

    synced_posts = 0
    for p in posts:
        slug = (p['hook'] or p['topic'] or f"post-{p['id']}")[:80]
        slug = slug.lower().replace(" ", "-").replace("'", "").replace('"', '').replace('?', '').replace('!', '')
        
        # Compute z_score locally via log10(views+1) EWMA
        payload = {
            "platform": p['platform'],
            "posted_at": p['posted_at'],
            "hook": p['hook'],
            "topic": p['topic'],
            "format": p['format'],
            "views_24h": p['views'],
            "properties": {
                "resonance_id": p['id'],
                "likes": p['likes'], "comments": p['comments'],
                "shares": p['shares'],
                "hold3s_pct": p['hold3s_pct'], "follows": p['follows'],
                "duration_sec": p['duration_sec'],
                "gut_tip": p['gut_tip'], "tip_blind": p['tip_blind'],
                "energy": p['energy'], "experiment_group": p['experiment_group'],
                "features_json": p['features_json'],
                "horizon": p['horizon'], "source": p['source'],
                "has_transcript": bool(p['transcript']),
                "vorschlag_id": p['vorschlag_id'],
            }
        }
        if upsert("content_posts", "id", slug, payload):
            synced_posts += 1
    counts["content_posts"] = synced_posts

    # ---- 2. Taste Pairs ----
    pairs = db.execute("""
        SELECT id, created_at, kind, kontext, gewaehlt, verworfen, grund, quelle
        FROM taste_pairs ORDER BY created_at DESC LIMIT 200
    """).fetchall()
    synced = 0
    for row in pairs:
        try:
            verworfen = json.loads(row['verworfen']) if isinstance(row['verworfen'], str) else row['verworfen']
        except:
            verworfen = []
        if upsert("resonance_taste_pairs", "id", row['id'], {
            "created_at": row['created_at'],
            "kind": row['kind'], "kontext": row['kontext'],
            "gewaehlt": row['gewaehlt'], "verworfen": verworfen,
            "grund": row['grund'], "quelle": row['quelle']
        }): synced += 1
    counts["resonance_taste_pairs"] = synced

    # ---- 3. Retention Curves ----
    curves = db.execute("""
        SELECT id, created_at, post_id, quelle, dauer_sec, punkte_json, notiz
        FROM retention_curves ORDER BY created_at DESC LIMIT 200
    """).fetchall()
    synced = 0
    for row in curves:
        try:
            punkte = json.loads(row['punkte_json']) if isinstance(row['punkte_json'], str) else row['punkte_json']
        except:
            punkte = []
        if upsert("resonance_curves", "id", row['id'], {
            "created_at": row['created_at'], "post_id": row['post_id'],
            "quelle": row['quelle'], "dauer_sec": row['dauer_sec'],
            "punkte_json": punkte, "notiz": row['notiz']
        }): synced += 1
    counts["resonance_curves"] = synced

    # ---- 4. Predictions (Vorschlaege) ----
    preds = db.execute("""
        SELECT id, created_at, modus, thema, hook, text_hook, format,
               plattform, merkmal, begruendung, z_vorhersage, genommen
        FROM vorschlaege ORDER BY created_at DESC LIMIT 100
    """).fetchall()
    synced = 0
    for row in preds:
        if upsert("resonance_predictions", "id", row['id'], {
            "created_at": row['created_at'], "modus": row['modus'],
            "thema": row['thema'], "hook": row['hook'],
            "text_hook": row['text_hook'], "format": row['format'],
            "plattform": row['plattform'], "merkmal": row['merkmal'],
            "begruendung": row['begruendung'],
            "z_vorhersage": row['z_vorhersage'],
            "genommen": row['genommen']
        }): synced += 1
    counts["resonance_predictions"] = synced

    # ---- 5. Experiments ----
    exps = db.execute("SELECT * FROM experimente ORDER BY created_at DESC LIMIT 50").fetchall()
    synced = 0
    for row in exps:
        try:
            arme = json.loads(row['arme_json']) if isinstance(row['arme_json'], str) else row['arme_json']
        except:
            arme = []
        if upsert("resonance_experiments", "id", row['id'], {
            "created_at": row['created_at'], "faktor": row['faktor'],
            "arme_json": arme, "frage": row['frage'] or '',
            "status": row['status'], "notiz": row['notiz'] or ''
        }): synced += 1
    counts["resonance_experiments"] = synced

    # ---- 6. Rolls ----
    rolls = db.execute("SELECT * FROM wuerfe ORDER BY gewuerfelt_at DESC LIMIT 100").fetchall()
    synced = 0
    for row in rolls:
        if upsert("resonance_rolls", "id", row['id'], {
            "experiment_id": row['experiment_id'],
            "gewuerfelt_at": row['gewuerfelt_at'], "arm": row['arm'],
            "post_id": row['post_id'], "eingeloest_at": row['eingeloest_at'],
            "verfallen": row['verfallen']
        }): synced += 1
    counts["resonance_rolls"] = synced

    # ---- 7. Forge Runs ----
    runs = db.execute("SELECT * FROM forge_runs ORDER BY created_at DESC LIMIT 100").fetchall()
    synced = 0
    for row in runs:
        try:
            skript = json.loads(row['skript_json']) if isinstance(row['skript_json'], str) else row['skript_json']
            urteile = json.loads(row['urteile_json']) if isinstance(row['urteile_json'], str) else row['urteile_json']
            final = json.loads(row['final_json']) if isinstance(row['final_json'], str) else row['final_json']
        except:
            skript, urteile, final = [], [], []
        if upsert("resonance_forge_runs", "id", row['id'], {
            "created_at": row['created_at'], "thema": row['thema'],
            "rohmaterial": row['rohmaterial'], "dauer_sec": row['dauer_sec'],
            "hook": row['hook'], "text_hook": row['text_hook'],
            "skript_json": skript, "urteile_json": urteile,
            "final_json": final, "runden": row['runden'],
            "post_id": row['post_id']
        }): synced += 1
    counts["resonance_forge_runs"] = synced

    # ---- 8. Findings ----
    finds = db.execute("SELECT * FROM befunde ORDER BY created_at DESC LIMIT 50").fetchall()
    synced = 0
    for row in finds:
        try:
            inhalt = json.loads(row['inhalt_json']) if isinstance(row['inhalt_json'], str) else row['inhalt_json']
        except:
            inhalt = {}
        if upsert("resonance_findings", "id", row['id'], {
            "created_at": row['created_at'],
            "kurzfassung": row['kurzfassung'],
            "nichts_neues": row['nichts_neues'],
            "inhalt_json": inhalt
        }): synced += 1
    counts["resonance_findings"] = synced

    # ---- 9. Comments ----
    comments = db.execute("""
        SELECT id, extern_id, post_id, autor, text, erstellt_at,
               von_mir, entwurf, wert, beantwortet, beantwortet_at, uebersprungen
        FROM kommentare ORDER BY erstellt_at DESC LIMIT 200
    """).fetchall()
    synced = 0
    for row in comments:
        if upsert("resonance_comments", "id", row['id'], {
            "extern_id": row['extern_id'], "post_id": row['post_id'],
            "autor": row['autor'], "text": row['text'],
            "erstellt_at": row['erstellt_at'], "von_mir": row['von_mir'],
            "entwurf": row['entwurf'], "wert": row['wert'],
            "beantwortet": row['beantwortet'],
            "beantwortet_at": row['beantwortet_at'],
            "uebersprungen": row['uebersprungen']
        }): synced += 1
    counts["resonance_comments"] = synced

    db.close()
    return counts

if __name__ == "__main__":
    counts = sync()
    total = sum(counts.values())
    print(f"Synced {total} records across {len(counts)} tables:")
    for table, n in counts.items():
        print(f"  {table}: {n}")
