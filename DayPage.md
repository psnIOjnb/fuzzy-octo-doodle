# DayPage

**Offline iOS app: events, reminders and a daily note, all on one page.**

One screen per day. The agenda splits into untimed items on the left and timed
items on the right; underneath it sits a Markdown note for that day. There is no
account, no sync and no network code anywhere in the target — everything is a
local SwiftData store.

| | |
|---|---|
| **Language** | Swift 6 |
| **UI** | SwiftUI (`@Observable`, `@Query`) |
| **Persistence** | SwiftData (100% on-device) |
| **Minimum OS** | iOS 17.0 |
| **Dependencies** | None — pure Apple frameworks |
| **Xcode project** | `DayPage.xcodeproj` |

## Features

- **The day page** — serif date headline, a `Yesterday · Today · Tomorrow`
  picker that turns into real dates once you travel further out, and a
  horizontal flick to move a day at a time.
- **Agenda card** — two columns (`ALL DAY + NO TIME` / `TIMED`). Reminders carry
  a tappable checkbox, events a clock. Collapse the card to a one-line summary
  ("2 events · 3 to do · 1 overdue").
- **Overdue roll-forward** — unfinished reminders from earlier days keep
  appearing on today's page, flagged in red, until they're ticked or moved.
- **Quick add** — one field that reads plain English: *"Coffee with Sam tomorrow
  at 9:30"*, *"Standup every weekday 9am"*, *"Renew passport friday"*. The sheet
  shows the day, time and repeat rule it understood **before** saving, and
  "More options" hands the half-parsed entry to the full editor. Parsing is
  `NSDataDetector` — on-device, no service call.
- **Repeats** — daily, weekdays, weekly, fortnightly, monthly, yearly.
  Occurrences are materialised 120 days ahead, so a single day can be ticked,
  edited, moved or deleted without touching the rest of the series (deleting one
  day is remembered as an exception rather than regenerated).
- **Daily note** — Markdown, monospaced, auto-growing with the text. The **A**
  button toggles between writing and a rendered view (headings, bullets,
  numbered lists, quotes, inline emphasis and links). Saves on a short debounce.
- **Calendar & search** — month grid with a dot on every day that has agenda
  items, a note, or something overdue; full-text search across every item title,
  item note and daily note in the archive.
- **Local alerts** — optional notifications for timed items at a configurable
  lead time, plus a nightly nudge to write the note. Scheduled by the device, so
  they fire in airplane mode.
- **Export** — a day or the whole archive as Markdown, through the system share
  sheet. No upload path exists.
- **Light and dark** — one palette defined light-first, with dark counterparts
  resolved per colour; the app follows the system appearance.

## Project layout

```
DayPage.xcodeproj/           Xcode 16 project (filesystem-synchronized)
DayPage/
├── DayPageApp.swift         Entry point: ModelContainer, DayStore, AppSettings
├── Models/
│   ├── AgendaItem.swift     Event/reminder row + ItemKind, Recurrence, DayKey
│   └── DailyNote.swift      One Markdown note per day (unique by day key)
├── Data/
│   ├── DayStore.swift       Selected day, navigation, calendar maths, formatters
│   ├── AppSettings.swift    UserDefaults-backed preferences (@Observable)
│   ├── RecurrenceEngine.swift  Materialises, propagates and prunes series
│   ├── QuickAddParser.swift    Natural-language entry (NSDataDetector)
│   └── WelcomeContent.swift    First-launch page; also the erase helper
├── Services/
│   ├── NotificationScheduler.swift  Local alerts, rebuilt from the store
│   └── DayExporter.swift            Day / archive → Markdown
├── Theme/                   Colour + type tokens, card and chip furniture
├── Views/
│   ├── DayView.swift        The screen; owns the day-scoped queries
│   ├── QuickAddSheet.swift  Natural-language add
│   ├── ItemEditorView.swift Full editor + ItemDraft value type
│   ├── CalendarSheet.swift  Month grid and search
│   ├── SettingsView.swift   Preferences, storage stats, export, erase
│   └── Components/          Header bar, agenda card/row, daily note card
└── Assets.xcassets          App icon slot + accent colour
```

## Run it

1. Install **Xcode 16 or newer** (the project uses the folder-synchronized
   format and the Swift 6 toolchain).
2. Open `DayPage.xcodeproj`.
3. Pick the **DayPage** scheme and any iPhone simulator running iOS 17+.
4. Press **⌘R**.

First launch writes a short welcome page (a few items and a note explaining the
app). Settings can erase everything or put the welcome page back.

To install on a real iPhone with a free Apple ID, follow the same sideloading
steps as the other app in this repository — see the "Install on a real iPhone"
section of [`README.md`](README.md), substituting the `DayPage` target and a
unique bundle identifier in place of `com.daypage.app`.

## Design notes

- **Why materialised repeats.** Computing occurrences on the fly would mean
  every screen needs a bespoke merge of stored rows and virtual ones. Writing
  real rows ahead of time keeps each screen a plain `@Query`, and makes
  per-occurrence state (completed, moved, deleted) free.
- **Why one `@Query` owner.** `DayPageContent` builds all three day-scoped
  predicates in its initialiser and passes plain arrays down. Child views stay
  dumb, and there is exactly one place where "which day am I showing" turns into
  a fetch.
- **Why the hidden twin in the note editor.** `TextEditor` inside a `ScrollView`
  either fights the outer scroll or clips. An invisible `Text` holding the same
  string sets the height, the editor's own scrolling is disabled, and the page
  scrolls as a single document.
- **Settings storage.** `AppSettings` exposes computed properties over
  `UserDefaults` and drives SwiftUI updates from one `revision` counter, so the
  defaults store stays the single source of truth rather than being shadowed by
  a second copy in memory.
