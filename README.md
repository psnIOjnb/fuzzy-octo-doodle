# OTC Pulse

**Offline-first iOS intelligence app for OTC derivatives regulation.**

A daily 24-hour feed of publications from global financial regulators (CFTC, ESMA, FCA, MAS, FSB, IOSCO, ASIC, BCBS, …) is downloaded once per day, merged into a permanent on-device archive, and stays fully searchable with zero connectivity. Dark navy + electric cyan, glassmorphic cards, Bloomberg-meets-intelligence-dashboard aesthetic.

| | |
|---|---|
| **Language** | Swift 6 |
| **UI** | SwiftUI (`@Observable`, `@Query`) |
| **Persistence** | SwiftData (100% on-device) |
| **Minimum OS** | iOS 17.0 |
| **Dependencies** | None — pure Apple frameworks |

## Features

- **Global** — daily stats strip, animated world heatmap (pure SwiftUI `Canvas`), today's publication cards, pull-to-refresh, PDF export of the daily snapshot.
- **Regions** — Americas / Europe / Asia-Pacific / MEA / International Bodies with filtered stats, mini heatmap and cards.
- **Regulators** — searchable directory of 27 regulators; tap through to any regulator's full historical archive.
- **Topics** — pre-defined taxonomy (Margin, CCP Risk, Trade Reporting, Trading Venues, Capital Requirements, Cross-border, …) merged with dynamic tags from the feed.
- **High Impact** — everything scoring ≥ 7.5, all-time.
- **Deadlines** — extracted consultation-close / effective / compliance dates bucketed into Overdue, Next 7 Days, Next 30 Days, Later.
- **Search** — full-text over the entire accumulated history (title, summary, regulator, tags) with filters: date range, region, regulator, topic, minimum impact score.
- **Library** — browse the permanent archive by month/day; open and PDF-export any past daily snapshot.
- **Watchlist** — save publications, attach personal notes; local notifications when new high-impact items are ingested.
- **Settings** — feed URL, manual refresh, notification opt-in, storage stats, erase/regenerate data, about.

> The bottom tab bar exposes all ten sections; iOS automatically hosts the ones beyond the first four under the system **More** tab.

## Project layout

```
OTCPulse.xcodeproj/          Xcode 16 project (filesystem-synchronized — files on disk ARE the project)
OTCPulse/
├── OTCPulseApp.swift        App entry: ModelContainer + DataService injection
├── Models/                  SwiftData @Model classes + Region/Topic taxonomy
│   ├── Publication.swift    (also AppConfig constants)
│   ├── Regulator.swift
│   ├── DailySnapshot.swift
│   ├── WatchlistItem.swift
│   └── Region.swift
├── Data/
│   ├── FeedDTO.swift        Codable wire format of the daily JSON
│   ├── DataService.swift    Download → decode → merge/dedupe → snapshot → notify
│   ├── MockDataGenerator.swift  Realistic sample feeds (today + 30-day history)
│   └── RegulatorCatalog.swift   27 regulators with HQ coordinates (heatmap)
├── Services/
│   ├── NotificationManager.swift  Local high-impact alerts (UserNotifications)
│   └── PDFExporter.swift          Daily snapshot → dark-branded PDF
├── Theme/                   Design tokens + glassmorphic card modifier
├── Views/                   One file per tab + shared components
└── Resources/sample-daily.json    Worked example of the feed format
```

## Run in the Simulator

1. Install **Xcode 16 or newer** (the project uses the modern folder-synchronized format; Swift 6 toolchain required).
2. Open `OTCPulse.xcodeproj`.
3. Select the **OTCPulse** scheme and any iPhone simulator (iOS 17+).
4. Press **⌘R**.

First launch seeds the regulator catalog and pulls the live cloud feed (see **Live data pipeline** below). Real OTC-derivatives regulatory flow is sparse — expect a handful of publications per week, with quiet days in between; the archive grows permanently with every refresh.

## Install on a real iPhone

### With a free Apple ID (sideloading, no paid account)

1. Connect your iPhone via cable and trust the computer.
2. In Xcode: **Settings → Accounts → +** and sign in with your Apple ID (a free "Personal Team" is created automatically).
3. Select the project in the navigator → **OTCPulse** target → **Signing & Capabilities**:
   - Check **Automatically manage signing**.
   - Choose your **Personal Team**.
   - If the bundle ID collides, change `com.otcpulse.app` to something unique like `com.yourname.otcpulse`.
4. Select your iPhone as the run destination and press **⌘R**.
5. On the phone: **Settings → General → VPN & Device Management** → trust your developer certificate.
6. On iOS 16+: enable **Settings → Privacy & Security → Developer Mode** and reboot when prompted.

Free-account caveats: the app expires after **7 days** (re-run from Xcode to renew), max 3 sideloaded apps at once. A paid Apple Developer Program membership ($99/yr) removes both limits and allows TestFlight distribution.

## Live data pipeline (zero configuration)

The repo contains a fully automated feed generator — the app needs no setup at all:

- **`feedgen/sources.json`** — 11 verified official regulator RSS feeds (CFTC, SEC, Federal Reserve, OSFI, ESMA, EBA, FCA, Bank of England, FINMA, FSB, BCBS). Add a source by appending an entry; nothing else changes.
- **`feedgen/generate_feed.py`** — fetches every source, keeps items relevant to OTC derivatives (CFTC passes wholesale via `"relevance": "all"`; broad regulators go through a keyword gate), infers document type and topics, scores impact, extracts deadlines, and emits `daily.json` in the exact `DailyFeedDTO` wire format. IDs are UUIDv5 of the item URL, so re-runs are stable and the app's dedup makes overlapping windows harmless.
- **`.github/workflows/daily-feed.yml`** — GitHub Action running daily at 20:30 UTC (plus a manual **Run workflow** button). Publishes `daily.json` and a dated copy under `history/` to the **`feed`** branch.
- The app's built-in default feed URL points at that branch:
  `https://raw.githubusercontent.com/psnIOjnb/fuzzy-octo-doodle/refs/heads/feed/daily.json`
  Settings → Daily Feed stays empty unless you want to override it with your own endpoint.

One-time requirements for the pipeline to serve the app:

1. **The repository must be public** — `raw.githubusercontent.com` URLs of private repos require authentication the app doesn't have. (GitHub → repo **Settings → General → Danger Zone → Change visibility**.)
2. **The workflow must be on the default branch** (`main`) — GitHub only runs scheduled workflows from there.
3. Optionally trigger the first run manually: **Actions → Daily OTC Pulse feed → Run workflow** — this creates the `feed` branch immediately instead of waiting for the nightly cron.

Data-volume expectation: OTC derivatives regulation is a low-volume domain. A typical day yields 0–3 relevant publications globally; consultations and final rules cluster around quarter-ends. Quiet days are correct behavior, not a bug.

## Feed hosting alternatives

Any static host works if you'd rather not use the GitHub pipeline — put a JSON document in the format below at a public HTTPS URL and paste it into **Settings → Daily Feed**. Merging is idempotent: records are deduplicated by `url` (when present) or `id`, so overlapping or re-downloaded feeds never create duplicates. Everything ingested accumulates permanently and remains available offline.

### Feed format (`DailyFeedDTO`)

```json
{
  "date": "2026-08-01",
  "generatedAt": "2026-08-01T05:00:00Z",
  "publications": [
    {
      "id": "6E2A1C1E-0001-4A61-9E2B-2B1B4E9A0001",
      "title": "Margin Requirements for Uncleared Swaps: Threshold Recalibration",
      "summary": "One-paragraph abstract of the document…",
      "regulatorCode": "CFTC",
      "regulatorName": "Commodity Futures Trading Commission",
      "region": "Americas",
      "publicationDate": "2026-08-01T13:30:00Z",
      "documentType": "Final Rule",
      "impactScore": 8.7,
      "url": "https://www.cftc.gov/…",
      "tags": ["Margin", "UMR", "Swap Dealers"],
      "fullText": null,
      "deadline": { "date": "2026-11-02T00:00:00Z", "label": "Compliance deadline" }
    }
  ]
}
```

Field notes:

- `id` — stable UUID per publication (dedupe key together with `url`).
- `region` — one of `Americas`, `Europe`, `Asia-Pacific`, `MEA`, `International Bodies` (unknown values fall back to International Bodies).
- `impactScore` — 0.0–10.0; ≥ 7.5 is flagged high-impact and can trigger a local notification.
- `deadline` — optional extracted compliance/consultation/effective date; feeds the Deadlines tab.
- Dates are ISO 8601.
- To surface a new regulator on the heatmap, add it to `RegulatorCatalog.swift` (code, name, region, HQ coordinates).

## Notes & extension points

- **Notifications** are local-only and opt-in (Settings → High-impact alerts).
- **Background refresh**: the app auto-refreshes when foregrounded if data is > 6h old; wiring up `BGAppRefreshTask` is a straightforward extension in `DataService`.
- **Storage**: everything lives in SwiftData; Settings shows record counts and offers full erase / sample regeneration.
