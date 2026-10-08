# NowNext — ADHD-friendly planner (iPhone)

**Brain dump → pick 3 for Now → focus with a visual timer.**
Native SwiftUI + SwiftData, iOS 17+, iPhone, portrait, dark mode only. Offline, no accounts, no analytics, no third-party SDKs.
Visual style: the "in Progress" brand (same system as *Gains in Progress*): black, signal red, white outlines, yellow for highlights only. See [Design system](#design-system).

> This code was written without access to Xcode, so it has **not been compiled yet**. It uses stable, documented APIs; if Xcode reports errors, paste them back and they'll be fixed.

## Features (v1.0)

| Feature | Where |
|---|---|
| **Brain Dump**: paste or type, one line = one task; bullets/numbers stripped | `Features/BrainDump` |
| **Now / Next / Later**: Now is capped (default 3, adjustable 1–5) | `Features/Today`, `Services/PlannerLogic.swift` |
| **Tiny steps**: break tasks down in the task bottom sheet; focus screen shows only the next step | `Features/TaskDetail` |
| **Time guesses vs. actual**: fight time blindness | `TaskItem.estimateMinutes` / `trackedSeconds` |
| **Visual focus timer**: shrinking disk, pause, +5 min, end early (time still counts), survives app kill | `Features/Focus`, `Services/FocusClock.swift`, `Services/FocusController.swift` |
| **Live Activity**: Lock Screen and Dynamic Island countdown | `NowNextWidgets/FocusLiveActivity.swift` |
| **Home Screen / Lock Screen widget**: Now list with tap-to-complete | `NowNextWidgets/NowWidget.swift`, `Shared/CompleteTaskIntent.swift` |
| **Siri / Shortcuts**: "Brain dump in NowNext" | `Intents/AppShortcuts.swift` |
| **Local notifications**: timer end, optional daily "pick your Now" reminder (permission asked in context) | `Services/NotificationService.swift` |
| **NowNext Pro** (one-time IAP): Insights and time-sense calibration | `Services/PurchaseManager.swift`, `Features/Paywall`, `Features/Insights` |
| Onboarding, empty states, Dark Mode, Dynamic Type, VoiceOver labels, 44pt targets | throughout |

## Build and run

```bash
brew install xcodegen          # once
cd NowNext
xcodegen generate              # creates NowNext.xcodeproj from project.yml
open NowNext.xcodeproj
```

1. Select the **NowNext** target → Signing & Capabilities → choose your Team. Do the same for **NowNextWidgets**.
   (Or set `DEVELOPMENT_TEAM` in `project.yml` and re-run `xcodegen generate`.)
2. Bundle IDs are `ai.palmettogroup.nownext` and `ai.palmettogroup.nownext.widgets`. Keep them if you own palmettogroup.ai; otherwise change both in `project.yml`, plus the App Group ID in `project.yml` and `Shared/SharedModelContainer.swift`.
3. With automatic signing, Xcode registers the App Group `group.ai.palmettogroup.nownext`. If it complains, add the App Groups capability to both targets and tick that group.
4. Pick an iPhone simulator → Run (⌘R). Purchases work locally through `NowNext/Resources/NowNext.storekit` (already set in the scheme).
5. Run tests with ⌘U (Swift Testing: planner rules, brain-dump parser, estimate stats, timer math).
6. Test widgets and the Live Activity on a **real device**; the simulator is unreliable for both.
7. Preview brand pieces in Xcode Canvas: `Design/BrandArt.swift` (badge + wordmark) and `Features/Focus/VisualTimerView.swift`.

Re-run `xcodegen generate` whenever you add/remove files or change `project.yml`. The `.xcodeproj` is git-ignored on purpose.

## Ship it

1. Build with **Xcode 26+** (App Store requirement since April 28, 2026).
2. App Store Connect → My Apps → **+** → New App (use values from `SUBMISSION.md`).
3. Create the In-App Purchase `ai.palmettogroup.nownext.pro` (Non-Consumable).
4. Enable GitHub Pages: repo Settings → Pages → Deploy from branch → `main` / `/docs`. This hosts the required Privacy Policy and Support URLs.
5. Xcode → Product → Archive → Distribute App → App Store Connect → Upload.
6. Add the build to TestFlight, test purchase/restore in sandbox, then attach build + IAP to the version and submit.

Everything for the listing (name, subtitle, keywords, description, privacy label, age rating, screenshot plan, review notes, checklist) is in **[SUBMISSION.md](SUBMISSION.md)**.

## Project layout

```
project.yml                 XcodeGen spec (app, widget extension, tests)
NowNext/
  App/                      @main app, root tabs, router, settings keys
  Features/                 Today, BrainDump, TaskDetail, Focus, Insights, Settings, Onboarding, Paywall
  Services/                 PlannerLogic (pure), FocusClock (pure), TaskStore, FocusController,
                            PurchaseManager, NotificationService, LiveActivityService
  Design/                   Components (buttons, cards, rows, rail, callouts, sheets) + brand art
  Intents/                  App Shortcuts (Siri)
  Resources/                Assets, Localizable.xcstrings, PrivacyInfo.xcprivacy, NowNext.storekit
Shared/                     Compiled into app AND widget: Theme (colors/fonts/spacing), SwiftData models, shared container,
                            Live Activity attributes, CompleteTaskIntent
NowNextWidgets/             Widget bundle: Now widget + focus Live Activity
NowNextTests/               Swift Testing unit tests
docs/                       GitHub Pages: support + privacy policy
```

**Design notes**
- Business rules live in pure types (`PlannerLogic`, `BrainDumpParser`, `EstimateStats`, `FocusClock`) so they're unit-tested without UI.
- The timer is date-based, not a ticking counter, so it's correct after backgrounding, locking, or a relaunch (state is saved to `UserDefaults`).
- One SwiftData store lives in the App Group container so the widget can read it. `CompleteTaskIntent` is a `LiveActivityIntent`, which makes iOS run it in the app's process so the app UI updates immediately when you check something off from the widget.
- Tone is non-shaming on purpose: no streaks to break, no red overdue badges, ending early still counts.

## Design system

All tokens live in `Shared/Theme.swift` (`enum Theme` + `Font.theme(_:)` + `.themeFont(_:)`); all reusable pieces live in `NowNext/Design/Components.swift` and `BrandArt.swift`. Screens compose these; they don't set their own colors or font sizes.

| Token | Value | Used for |
|---|---|---|
| background | `#050505` | every screen, launch screen, widget, Live Activity |
| surface | `#141414` | cards, rows, sheets |
| surfaceRaised | `#1F1F1F` | secondary buttons, icon tiles, empty rail bars |
| line | `#333333` | 1pt card borders, dividers |
| text / muted | `#FFFFFF` / `#C7C7C7` | body / secondary copy |
| red | `#E3120B` | the only accent: primary buttons, selected states, progress, big numbers, timer disk |
| yellow | `#F6C21C` | highlights only: stars, lightning bolt, callouts, Pro lock tags |
| gray | `#9A9A9A` | rail end caps, paused timer |
| warningFill | `#2A2413` | behind yellow-bordered callouts |

- **Type:** SF Pro only. Headlines Black/Heavy ALL CAPS; wordmark 58, hero 44, screen title 30, card title 19, option title 17 semibold, detail 14, section label 12 bold tracking 1.2. Every size scales with Dynamic Type through `UIFontMetrics`.
- **Shape:** gutter 20; radius cards 16, buttons 14, hero 18, icon tiles 12, sheets 28. Selected = red fill + 2pt white border.
- **Components:** `PrimaryButtonStyle` / `SecondaryButtonStyle` (54pt, press = 0.98 scale + 0.8 opacity), `BottomActionBar`, `OptionRow` (72pt min), `TaskRow`, `PlateCheck`, `SelectTile`, `Chip`, `StatTile`, `ProgressRail`, `Callout`, `LockTag`, `SheetHeader` + `.themedSheet()`, `ShieldBadge`, `Wordmark`, `BrandLockup`.
- **Navigation:** black nav bar with the progress rail in the center slot (Now capacity on every tab; elapsed time while focusing; step X of 3 in onboarding). Task details open as bottom sheets.

## Intentionally left out of v1

- iCloud sync (needs CloudKit schema rules + privacy label change)
- Due dates / calendar integration
- Recurring routines
- Accounts or any server
- On-device AI task breakdown (Apple Foundation Models) — good v1.1 candidate, needs iOS 26 gating

## Roadmap ideas

1. **AI "break it down"** with Apple's on-device Foundation Models (stays offline, no privacy label change).
2. Recurring routines (morning/evening) with a "just start" button.
3. iCloud sync across devices (and an iPad layout).
4. Live Activity buttons for pause/+5 (via `LiveActivityIntent`).
5. Body-doubling mode / ambient sounds.
6. Apple Watch complication showing the current Now task.

## Known limits to check in Xcode

- If the focus timer ends while the app is suspended, the session is saved the next time the app opens (the notification still fires on time). The Live Activity shows 0:00 until then.
- Moving tasks within a section uses `.onMove`; on iPhone, long-press-drag works in recent iOS versions. If it doesn't on your target, add an `EditButton`.
- `Localizable.xcstrings` starts empty; Xcode fills it with every string on the first build.
