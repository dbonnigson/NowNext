# NowNext — App Store Submission Package

Everything App Store Connect asks for, pre-filled. Character counts are checked against Apple's limits.
Requirements verified September 2026 (see "Current Apple requirements" at the bottom).

---

## 1. Listing copy

| Field | Value | Length / limit |
|---|---|---|
| **App name** | `NowNext: ADHD Planner` | 21 / 30 |
| **Subtitle** | `Brain dump, pick 3, then focus` | 30 / 30 |
| **Keywords** | `todo,task,list,timer,pomodoro,executive,function,organizer,time,blindness,visual,routine,checklist` | 98 / 100 |
| **Bundle ID** | `ai.palmettogroup.nownext` | |
| **SKU** | `NOWNEXT-IOS-001` | |
| **Primary category** | Productivity | It's a planner/task manager first. |
| **Secondary category** | Lifestyle | Avoids Health/Medical, which invites medical-claim scrutiny (Guideline 1.4). |
| **Price** | Free (with one In-App Purchase) | |

> Name check: an older app called "Now&Next" (Indigo Mountain, task manager) exists and appears delisted in at least some regions. App Store names must be unique, so "NowNext: ADHD Planner" should be accepted, but if App Store Connect rejects it, use one of the alternatives below. Search App Store Connect for "NowNext" before creating the record. If taken, alternatives that fit your "ADHD in Progress" brand: `In Progress: ADHD Planner` (25), `Tiny Steps: ADHD Planner` (24).
> Keyword rules followed: no spaces, no words repeated from name/subtitle (planner, brain, dump, pick, focus, ADHD), no competitor names.

### Promotional text (170 max — editable any time without review)

```
Too many tabs open in your head? Dump it all, pick just three for Now, and watch time shrink on a visual timer. No account. No ads. Your data stays on your phone.
```
(162 characters)

### Description (4000 max)

```
Planners built for neurotypical brains ask you to organize everything up front. NowNext works the other way: get it out of your head first, then pick just three things for right now.

Made for ADHD brains, busy brains, and anyone who has stared at a 40-item to-do list and done none of it.

BRAIN DUMP
• Type or paste anything, one thought per line. Every line becomes a task.
• No categories, no due dates, no decisions yet. Just get it out.
• Say "Add to my NowNext" to Siri to capture without opening the app.

NOW, NEXT, LATER
• Now holds up to three things (you can change the limit from 1 to 5).
• Everything else waits in Next or Later, out of sight and out of the way.
• Swipe to move a task. When Now is full, finish one before adding another.

TINY STEPS
• Break big, scary tasks into steps so small they feel silly.
• The focus screen shows only your next step, nothing else.

VISUAL FOCUS TIMER
• A shrinking colored disk shows time as space, not just numbers.
• Pause, add five minutes, or end early. Every focused minute still counts.
• See the countdown on your Lock Screen and in the Dynamic Island.
• Get a gentle notification when time is up.

FIGHT TIME BLINDNESS
• Add a rough time guess to any task.
• NowNext compares your guess with the time you actually focused.

HOME SCREEN WIDGET
• See your Now list and check things off without opening the app.

NOWNEXT PRO (one-time purchase, no subscription)
• Upcoming, as a countdown: your calendar shown as time left (45 min, 3 days, 2 weeks) instead of a grid of dates, with a 14-day horizon strip and one-tap prep tasks.
• Prefer a regular calendar? Flip to month, week or day view any time. Every event still shows how long until it starts.
• Put any task on the calendar from its "Where it lives" menu, and optionally add it to your iPhone calendar too (iCloud, Google, Outlook).
• Tap any event to fix the wording or move it.
• Routines: tasks that come back daily, on weekdays, weekly or monthly. Missed days never pile up.
• Insights: focus minutes by day and tasks finished each week.
• Time-sense calibration: learn how your guesses compare with reality ("tasks take you about 40% longer than you think") and plan with a personal multiplier.

PRIVATE BY DESIGN
• No account, no sign-up, no ads, no tracking.
• Everything is stored on your device. We never see your tasks.

NowNext is a planning and focus tool. It is not a medical device and does not diagnose or treat ADHD or any other condition.
```

### What's New (v1.0.0)

```
First release. Brain dump, Now/Next/Later, tiny steps, a visual focus timer with Live Activities, a Home Screen widget, Siri capture, and NowNext Pro (Upcoming countdown and calendar, scheduling tasks to your calendar, Routines, Insights).
```

### URLs

| Field | URL |
|---|---|
| Privacy Policy URL | `https://dbonnigson.github.io/NowNext/privacy.html` |
| Support URL | `https://dbonnigson.github.io/NowNext/` |
| Marketing URL (optional) | `https://palmettogroup.ai` or leave blank |

These pages are in `/docs`. Turn on GitHub Pages (Settings → Pages → Deploy from branch → `main` / `/docs`) **before** submitting. Reviewers click them.

---

## 2. In-App Purchase

| Field | Value |
|---|---|
| Type | Non-Consumable |
| Reference name | NowNext Pro |
| Product ID | `ai.palmettogroup.nownext.pro` (must match `PurchaseManager.proProductID`) |
| Price | $7.99 USD (base country United States; the local `.storekit` file matches) |
| Family Sharing | On (recommended) |
| Display name | NowNext Pro |
| Description (45 max) | `Countdown calendar, routines and insights` (41) |
| Review screenshot | Screenshot of the paywall (Settings → Unlock NowNext Pro) |
| Review notes | "Unlocks the Plan tab: Upcoming (calendar as countdown or month/week/day), scheduling tasks onto a calendar, Routines (recurring tasks) and Insights. Core planner is free." |

Submit the IAP **with** the first app version (App Store Connect → the version page → In-App Purchases → add it). An IAP created but not attached to the version is the most common first-submission rejection for unlock-style apps.

---

## 3. App Privacy ("nutrition label")

Answer: **Data Not Collected.**

Calendar events (Pro › Upcoming, optional) are read with EventKit and processed only on the device. Scheduled tasks the user chooses to add are written to their own calendar on-device. Nothing is stored by NowNext off-device or transmitted, so it is not "collected" under Apple's definition and the label stays the same. The permission string is `NSCalendarsFullAccessUsageDescription` in Info.plist.

Why this is accurate:
- No analytics, ads, crash-reporting or third-party SDKs are linked.
- Tasks, steps and focus sessions are stored with SwiftData in the app's own (App Group) container on-device. Nothing is sent to a server.
- Purchases are processed by Apple; the app only reads StoreKit entitlements on-device.
- Notifications are local (`UNUserNotificationCenter`), not push.

This matches `NowNext/Resources/PrivacyInfo.xcprivacy`: `NSPrivacyTracking = false`, no collected data types, and one required-reason API (`UserDefaults`, reason `CA92.1`, app-only settings). The widget extension's manifest declares nothing.

If you ever add analytics, crash reporting, iCloud sync, or an AI feature that sends text off-device, **both** the label and the manifest must change before that build ships.

---

## 4. Age rating questionnaire

All content questions: **None / No.** (No violence, sexual content, profanity, drugs, gambling, horror, medical/treatment info, user-generated content, unrestricted web access, messaging, or advertising.)
- Contests: No
- In-app controls / parental controls: not applicable
- Health or wellness topics: the app mentions ADHD in marketing and shows a disclaimer; it gives no medical or treatment information. Answer "No" to medical/treatment information.

Expected result: **4+**. (Apple updated the questionnaire in 2026; answer any new questions with "No" unless you've added features since.)

---

## 5. Screenshots

The app is **iPhone-only, portrait, dark mode only**, so only the iPhone set is required: **6.9" (1320×2868)** or **6.5" (1284×2778)**. PNG/JPEG, no transparency, 1–10 images. No iPad set is needed.

Capture from the iPhone 17 Pro Max simulator with ⌘S. Keep caption panels on the brand look: #050505 background, headline in white or signal red Black caps, yellow only for a star or bolt accent. Use real-looking sample tasks.

| # | Screen | Caption headline |
|---|---|---|
| 1 | Today: shield badge + wordmark, 3 tasks in Now, a few in Next | **JUST THREE THINGS. RIGHT NOW.** |
| 2 | Brain Dump with a pasted list turning into tasks | **EMPTY YOUR HEAD IN SECONDS** |
| 3 | Focus running: red disk ~60% full, big timer, next step card | **SEE TIME SHRINK** |
| 4 | Task sheet with tiny steps, chips and a time guess | **BREAK IT INTO SILLY-SMALL STEPS** |
| 5 | Lock Screen Live Activity + Now widget | **CHECK IT OFF FROM YOUR HOME SCREEN** |
| 6 | Plan › Upcoming (Pro): "Next up 2H 15M" hero + 14-day strip | **SEE HOW LONG YOU HAVE, NOT JUST THE DATE** |
| 6b | Plan › Routines (Pro) | **ROUTINES THAT NEVER PILE UP** |
| 7 | Settings: privacy row / "Not medical advice" callout | **NO ACCOUNT. NO ADS. STAYS ON YOUR PHONE.** |

The first two carry most of the conversion.

---

## 6. App Review notes (paste into "Notes")

```
NowNext is an offline planner and focus timer. There is no login or account.

How to reach every feature:
- Onboarding appears on first launch (3 cards, "Skip" at top right).
- Brain Dump tab: type or paste several lines, tap Capture. Each line becomes a task.
- Swipe a Brain Dump task right to move it to Now; left for Next or Later.
- Today tab: Now is capped at 3 tasks by default (Settings > Planner). Tap the circle to complete.
- Tap a task to add "Tiny steps" and a time guess, then "Focus on this".
- Focus tab: pick a length, tap Start. Pause, +5 min and End are available. A Live Activity appears on the Lock Screen/Dynamic Island.
- Widget: long-press Home Screen > + > NowNext > "Now".
- Siri/Shortcuts: "Add to my NowNext" (also "Brain dump in NowNext").

In-App Purchase: "NowNext Pro" (non-consumable) unlocks the Plan tab: Upcoming (calendar shown as time-until), Routines (recurring tasks) and Insights. Open the Plan tab or Settings > Unlock NowNext Pro. Restore Purchases is on the paywall and in Settings.

Calendar permission (full access) is requested only when the user taps "Connect Calendar" in Plan > Upcoming, or turns on "Also add to my calendar" when scheduling a task. It is used to show events as a countdown or month/week/day calendar, to add a scheduled task to the calendar the user picks, and to open Apple's own editor when the user taps one of their events. NowNext only changes or removes events it created itself, or ones the user explicitly edits in Apple's editor. Calendar data never leaves the device. Manual events can be added without granting it.

To see scheduling: open any task > "Where it lives" > Calendar, pick a time, Save. It appears in Plan > Upcoming.

Notifications permission is requested only when the user starts their first focus session or turns on the daily reminder, and is used only for local "time's up" and reminder notifications.

The app mentions ADHD because it is designed around common ADHD planning struggles. It makes no medical claims, and a "not a medical device" disclaimer is shown in onboarding and Settings.
```

---

## 7. Pre-submission checklist

- [ ] `DEVELOPMENT_TEAM` set; bundle IDs registered: `ai.palmettogroup.nownext`, `ai.palmettogroup.nownext.widgets`
- [ ] App Group `group.ai.palmettogroup.nownext` created and enabled on **both** App IDs (Xcode does this with automatic signing)
- [ ] Built with **Xcode 26+ / iOS 26 SDK** (required since April 28, 2026)
- [ ] Version `1.0.0`, build `1` (bump build for every upload)
- [ ] GitHub Pages is live; privacy + support URLs load on a phone
- [ ] IAP created in App Store Connect, product ID matches, **attached to the version**
- [ ] Purchase and Restore tested in the simulator (StoreKit config) and in TestFlight sandbox
- [ ] Tested on the smallest iPhone (iPhone SE / 16e) and the largest (Pro Max), portrait
- [ ] Largest Dynamic Type size checked on every tab (text scales via UIFontMetrics)
- [ ] VoiceOver pass: check buttons, timer, widget buttons all read sensibly
- [ ] Airplane mode: every feature still works
- [ ] Widget and Live Activity work on a real device (they're flaky in the simulator)
- [ ] No test data in screenshots that looks like lorem ipsum; no placeholder text anywhere
- [ ] App Privacy answered "Data Not Collected"; matches `PrivacyInfo.xcprivacy`
- [ ] Age rating questionnaire completed (new 2026 questions)
- [ ] EU: DSA trader status set in App Store Connect (required to distribute in the EU)
- [ ] Export compliance: `ITSAppUsesNonExemptEncryption = NO` is already in Info.plist

---

## 8. Top review risks and how they're handled

| Risk | Guideline | Mitigation in the build |
|---|---|---|
| "Just another to-do app" | 4.3 Spam | Clear differentiators: capped Now list, brain-dump parser, visual timer, estimate-vs-actual calibration, Live Activity, widget, Siri capture. Lead with these in screenshots 1–3. |
| Thin functionality | 4.2 | Widget, Live Activity, App Shortcut, local notifications, persistent on-device data. |
| Medical claims about ADHD | 1.4.1 / 5.1.3 | No diagnosis/treatment claims; disclaimer in onboarding + Settings + description; category is Productivity, not Medical. |
| IAP issues | 3.1.1 / 2.1 | StoreKit 2, price shown from App Store, Restore in two places, Terms + Privacy links on paywall, core app fully usable free. |
| Broken links | 2.1 / 5.1.1 | Privacy and support pages in `/docs`; enable Pages first. |
| Privacy label mismatch | 5.1.2 | Manifest and label both say no data collected. |

---

## Current Apple requirements (checked Sept 26, 2026)

- Uploads must be built with **Xcode 26 or later using the iOS/iPadOS 26 SDK** (effective April 28, 2026). The app's *deployment target* can stay at iOS 17. Building with the 26 SDK automatically applies the new system design (Liquid Glass) to standard SwiftUI controls, so re-check screenshots after your first build.
- **Updated age rating questions** must be answered (effective January 31, 2026).
- **Privacy manifest** required-reason API declarations (since May 2024) — done.
- Screenshots: 6.5" iPhone set is the minimum if you don't supply 6.9". This build is iPhone-only, so no iPad set is required.

Sources: [Apple — Upcoming requirements](https://developer.apple.com/news/upcoming-requirements/), [Apple — Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
