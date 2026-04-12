# Calibrate

## Overview
Calibrate is a daily iOS prediction game where users submit 50% and 90% confidence intervals for 5 numeric estimation questions. The app tracks calibration accuracy over time — whether stated confidence matches observed accuracy — and surfaces this as a long-term skill score with a global leaderboard.

## Tech Stack
- Language: Swift 5.10+
- UI: SwiftUI (iOS 17.0+ deployment target)
- Local persistence: SwiftData (iOS 17)
- Remote sync: CloudKit (iCloud private + public containers)
- IAP: StoreKit 2
- Charts: Swift Charts (iOS 16+)
- Question generation: Python 3.12 + Anthropic SDK (local CLI, not shipped in app)

## Development Conventions
- SwiftUI only — no UIKit except where unavoidable (custom gesture recognizers)
- All async operations use Swift concurrency (async/await, actors) — no Combine or callbacks
- SwiftData models are the single source of truth for local state; CloudKit is sync layer only
- File naming: PascalCase for types and views, camelCase for functions and properties
- No force unwraps (`!`) anywhere — use guard/if-let or provide safe defaults
- Unit tests required for CalibrationEngine and DateUtils before any dependent UI is built
- CloudKit container ID: `iCloud.com.calibrate.app`

## Current Phase
**Phase 3: Complete** — StoreKit 2 premium subscriptions, CloudKit leaderboard, friend groups, advanced calibration curve, privacy manifest. See IMPLEMENTATION-ROADMAP.md for full phase details and acceptance criteria.

## Key Decisions
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

## Do NOT
- Do not add features not in the current phase of IMPLEMENTATION-ROADMAP.md
- Do not use UIKit components when a SwiftUI equivalent exists
- Do not store the Claude API key anywhere in the Xcode project — it's a local Python CLI tool only
- Do not write to CloudKit public DB from the app except for leaderboard entries and friend groups (Phase 2+)
- Do not use Combine — Swift concurrency only
- Do not allow the app to proceed without confirming the 90% interval contains the 50% interval (enforce in IntervalInputWidget binding logic, not on submit)
- Do not build the leaderboard, friend groups, or StoreKit integration in Phase 0 or Phase 1
- Do not use force unwraps — zero tolerance
