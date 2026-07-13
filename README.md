# SubTrack

An installable **PWA** for tracking subscriptions and never missing a cancellation
window. ZAR-first, mobile-first, **vanilla JS — no framework, no build step.**

## Features

- **Home** — total monthly spend (ZAR primary, other currencies as `+ X/mo`),
  yearly equivalent, and active subs sorted by days-until-next-charge. Each row
  has a brand-coloured initial, price, `in N days · cycle`, and a "fuse" bar that
  fills through the billing cycle and turns red within 3 days.
- **Roll-forward** — any past charge date is advanced by its cycle on load.
- **Detail sheet** — monthly/yearly equivalents, countdown, one-tap deep-link to
  the real cancellation page, mark-as-cancelled, `.ics` reminder download
  (`RRULE` by cycle + `VALARM` 2 days before), edit, delete-with-confirm.
- **Cancelled** — collapsed list with a running "saving R X/mo" tally; reactivate
  rolls the date forward.
- **Add** — 18 presets (Netflix, Spotify, YouTube Premium, Showmax, DStv, Apple,
  Google Play, Google One, Disney+, Prime, Microsoft 365, Xbox Game Pass,
  PlayStation Plus, Claude, ChatGPT, Canva, Adobe, Audible) with brand colours and
  real cancellation URLs, plus a custom option with a colour picker.
- **Offline** — `manifest.webmanifest` + `sw.js` (cache-first app shell). All PWA
  wiring is wrapped so a failure can never break the app.

Data is stored in `localStorage` under `subtrack-v1`.

## Files

| File | Purpose |
|------|---------|
| `index.html` | The whole app — markup, styles, and logic. |
| `manifest.webmanifest` | PWA manifest with embedded PNG icons. |
| `sw.js` | Service worker (cache-first app shell). |
| `icon-192.png`, `icon-512.png` | App icons (also embedded in the manifest). |
| `scripts/` | Dev tooling (icon generation, smoke test, screenshots). |

## Develop / test

```bash
npm install          # jsdom + playwright (dev only)
npm test             # jsdom smoke test — must pass with zero console errors
npm run icons        # regenerate icons + manifest
npm run shot         # render screenshots via Chromium
```

## Install to your phone

- **Android (Chrome):** open the site → **⋮** menu → **Add to Home screen** → **Install**.
- **iOS (Safari):** open the site → **Share** (□↑) → **Add to Home Screen** → **Add**.
