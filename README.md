# Calibrate

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Do you actually know what you know? Find out in 5 questions a day.

Calibrate is a daily iOS prediction game that measures and trains your calibration — whether your stated confidence matches how often you are right. Each day you answer 5 numeric estimation questions with 50% and 90% confidence intervals plus a point estimate. Over time a Calibration Score (0–100) reveals how closely your stated confidence maps to observed accuracy.

## Features

- **Daily 5-question rounds** — fresh numeric estimation questions each day
- **Dual scoring** — Calibration Score (interval accuracy) and Knowledge Score (point-estimate MAPE) tracked independently
- **Swift Charts visualization** — premium calibration curve comparing stated confidence with observed interval hit rates
- **CloudKit uploads** — answers and profile data (including calibration score) upload to the private database; calibration scores are also published to the public leaderboard; cross-device restore is not implemented
- **StoreKit 2 subscriptions** — monthly ($2.99) and annual ($14.99) plans unlocking premium features (calibration curve, friend groups, domain breakdown)
- **Optional local reminder** — user-controlled 8:00 AM notification with no remote push service
- **Global leaderboard** — fetches up to 100 CloudKit entries by calibration score, displays the top 20, and shows personal rank within the fetched entries when present
- **Python question CLI** — Anthropic SDK-powered authoring tool (dev-time only, not shipped)

## Quick Start

### Prerequisites
- Xcode 16.0+
- iOS 17.0+ device or simulator
- Apple Developer account (for CloudKit)

### Installation
```bash
git clone https://github.com/saagpatel/Calibrate.git
cd Calibrate
open Calibrate.xcodeproj
```

### Usage
Build and run the `Calibrate` scheme on your device or simulator from Xcode.

CloudKit uploads, question delivery, and leaderboards require a signed build with the app's iCloud entitlement. Core gameplay falls back to the bundled question bank when CloudKit is unavailable.

The app bundle ID is `com.calibrat.app`; tests use `com.calibrat.app.CalibrateTests`.
The existing CloudKit container remains `iCloud.com.calibrate.app` and subscription
product IDs remain `com.calibrate.premium.monthly` and `com.calibrate.premium.annual`.

## Verification

Run from the repository root on macOS with Xcode 16+ selected (`xcode-select -p`),
its iOS SDK, and an installed iPhone simulator runtime. This is an Xcode project,
not a Swift package. The unsigned simulator lane mirrors [CI](.github/workflows/ci.yml)
and needs no Apple Developer account:

```bash
plutil -lint Calibrate/Info.plist Calibrate/PrivacyInfo.xcprivacy Calibrate/Calibrate.entitlements ExportOptions.plist
make build
xcrun simctl list devices available
# Replace the UUID below with an available iPhone simulator from that list.
make test SIMULATOR_ID='paste-available-uuid-here' TEST_FLAGS='-only-testing:CalibrateTests/CalibrationEngineTests'
make test SIMULATOR_ID='paste-available-uuid-here'
```

`make build` compiles Release for a generic iOS Simulator; `make test` runs the
focused class or full `CalibrateTests` suite. Derived data stays in
`.build/DerivedData`. There is no separate configured Swift lint command;
`plutil` checks resource syntax, while the compiler and tests cover Swift changes.

For SwiftUI changes, manually build/run the scheme in Xcode on a simulator and
check the affected navigation, layout, and accessibility. Unit tests do not prove
that UI flow. Signed CloudKit, StoreKit, and notification behavior require their
own authorized manual checks. Do not use the question generator's API generation
or CloudKit upload as a verification smoke test: those can consume API credits or
change provider data. `make run` opens the project for manual use.

## Privacy

Calibrate uses private and public CloudKit databases for answer/profile uploads, question delivery, leaderboard, and friend-group features. See [PRIVACY.md](PRIVACY.md) for the exact data flows. The app has no advertising SDKs or cross-app tracking.

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6.0 (strict concurrency) |
| UI | SwiftUI (iOS 17+) |
| Local persistence | SwiftData |
| Remote data | CloudKit (public reads/writes, private answer/profile uploads) |
| In-app purchase | StoreKit 2 |
| Charts | Swift Charts |

## License

MIT
