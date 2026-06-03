# Calibrate

Daily iOS prediction game: users submit 50% and 90% confidence intervals for 5 numeric questions. Tracks calibration accuracy over time with a global leaderboard.

## Stack
- Swift 6.0 (strict concurrency enabled), SwiftUI, iOS 17.0+ deployment target
- Local persistence: SwiftData; remote sync: CloudKit (iCloud private + public containers)
- IAP: StoreKit 2; Charts: Swift Charts (iOS 16+)
- Question generation: Python 3.12 + Anthropic SDK — local CLI only, not shipped in app
- CloudKit container ID: `iCloud.com.calibrate.app`

## Build / Test / Run
Build and run the `Calibrate` scheme in Xcode on device or simulator.
Unit tests required for CalibrationEngine and DateUtils before any dependent UI is built.

## Architecture Decisions
| Decision | Choice | Why |
|----------|--------|-----|
| Backend | CloudKit only | Zero infrastructure cost, iCloud auth built-in, iOS-native |
| Confidence levels | 50% + 90% intervals | Richer calibration data; two data points per question |
| Daily set assignment | Date-keyed, UTC-based, same for all users | Enables direct social comparison |
| Answer reveal | After all 5 (batch reveal) | Report-card moment; prevents late-question anchoring |
| Point estimate | Tracked as "Knowledge Score" separately | Two-axis competition; doesn't pollute calibration ranking |
| Admin UI | In-app, hidden behind 5-tap gesture on version label | Zero infrastructure; solo curator |
| Rolling window | Last 30 questions for "recent" score; all-time for "career" | 30 = meaningful sample without months of play |
| Monetization | Free + premium ($2.99/mo, $14.99/yr via StoreKit 2) | No ads ever |
| Premium features | Advanced calibration curve, friend groups, domain breakdown | Core gameplay always free |

## Conventions
- SwiftUI only; UIKit allowed only for custom gesture recognizers where no SwiftUI equivalent exists.
- All async operations use Swift concurrency (async/await, actors) — Combine is not used.
- SwiftData models are the single source of truth for local state; CloudKit is sync layer only.
- File naming: PascalCase for types and views, camelCase for functions and properties.
- Force unwraps (`!`) are not permitted — use guard/if-let or provide safe defaults.

## Scoped Gates
- **Scope gate:** Build only what the current phase of IMPLEMENTATION-ROADMAP.md specifies; leaderboard, friend groups, and StoreKit integration are Phase 2+ only.
- **CloudKit write gate:** App writes to the CloudKit public DB only for leaderboard entries and friend groups (Phase 2+). All other app writes go to the private container.
- **Interval validation gate:** Confirm the 90% interval contains the 50% interval in IntervalInputWidget binding logic — not on submit. The app must not proceed if this invariant fails.
- **API key gate:** The Claude API key must never appear in the Xcode project — it belongs to the local Python CLI only.

<!-- portfolio-context:start -->
# Portfolio Context

## What This Project Is

Calibrate is a daily iOS prediction game where users submit 50% and 90% confidence intervals for 5 numeric estimation questions. The app tracks calibration accuracy over time — whether stated confidence matches observed accuracy — and surfaces this as a long-term skill score with a global leaderboard.

## Current State

**Phase 3: Complete** — StoreKit 2 premium subscriptions, CloudKit leaderboard, friend groups, advanced calibration curve, privacy manifest. See IMPLEMENTATION-ROADMAP.md for full phase details and acceptance criteria.

## Stack

- Language: Swift 6.0 (strict concurrency enabled)
- UI: SwiftUI (iOS 17.0+ deployment target)
- Local persistence: SwiftData (iOS 17)
- Remote sync: CloudKit (iCloud private + public containers)
- IAP: StoreKit 2
- Charts: Swift Charts (iOS 16+)
- Question generation: Python 3.12 + Anthropic SDK (local CLI, not shipped in app)

## How To Run

Build and run the `Calibrate` scheme on your device or simulator from Xcode.

## Known Risks

- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not use UIKit components when a SwiftUI equivalent exists
- Do not store the Claude API key anywhere in the Xcode project — it's a local Python CLI tool only
- Do not write to CloudKit public DB from the app except for leaderboard entries and friend groups (Phase 2+)
- Do not use Combine — Swift concurrency only
- Do not allow the app to proceed without confirming the 90% interval contains the 50% interval (enforce in IntervalInputWidget binding logic, not on submit)
- Do not build the leaderboard, friend groups, or StoreKit integration in Phase 0 or Phase 1
- Do not use force unwraps — zero tolerance

## Next Recommended Move

Use this context plus the README and supporting docs to resume the next active task, then promote the repo beyond minimum-viable by capturing a dedicated handoff, roadmap, or discovery artifact.

<!-- portfolio-context:end -->

<!-- secondbrain-breadcrumb -->
## SecondBrain knowledge vault

Prior lessons, decisions, and context for this project live in SecondBrain at `wiki/maps/projects/calibrate.md`. The whole vault is searchable via the `engraph` MCP — query it for this project + its stack before non-trivial work.
