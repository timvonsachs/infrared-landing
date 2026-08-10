# infrared-landing

Infrared — Konversationsgedächtnis für Coaches & Berater, die über DMs verkaufen.

## Was das ist

Landingpage + Warteliste für **Infrared v0**: den Erstbefund — eine einmalige, zitierbare Bestandsaufnahme offener Zusagen in deinen Instagram/WhatsApp-Chats der letzten 90 Tage.

**Kein Auto-Send. Jede Nachricht schreibt der Mensch selbst.**

## Stack

- Static HTML/CSS/JS (kein Framework)
- Supabase (Postgres + REST API)
- Keine Cookies, kein Tracking-Drittanbieter

## Analytics (First-Party, via Supabase)

Getrackt wird:
- `page_view` — Seitenaufruf
- `scroll_depth` — wie weit gescrollt
- `slider_move` — Thermogramm-Slider-Interaktion
- `leak_calculator` — Leck-Rechner benutzt
- `zettel_open` — Beispiel-Befund ausgeklappt
- `waitlist_submit` — Warteliste-Eintrag

Keine externen Analytics-Dienste. Alle Daten landen in Supabase.

## Supabase Setup

1. Öffne das Supabase Dashboard
2. Kopiere `supabase-setup.sql` in den SQL Editor
3. Ausführen

Tabellen:
- `waitlist` — E-Mail + Price/DM-Band + Leakage-Schätzung
- `analytics_events` — Engagement-Events (anonymisiert)
- `waitlist_attribution` — UTM/Referrer-Attribution pro Signup

## Deployment

Statische Dateien → GitHub Pages, Netlify, Vercel oder eigener Server.

```
.
├── index.html             # Landingpage (alles in einer Datei)
├── supabase-setup.sql     # Datenbank-Schema
└── README.md
```

## Deploy auf GitHub Pages

```bash
gh repo create infrared-landing --public
git push -u origin main
# Settings → Pages → Source: main branch, / (root) → Save
```

## Autor

Tim von Sachs — [@timfromsachs](https://instagram.com/timfromsachs)
