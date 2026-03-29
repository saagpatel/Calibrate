# Calibrate

[![Swift](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-iOS%2017%2B-blue?logo=apple)](https://developer.apple.com/ios/)
[![Xcode](https://img.shields.io/badge/Xcode-16.0-147EFB?logo=xcode)](https://developer.apple.com/xcode/)
[![CloudKit](https://img.shields.io/badge/Backend-CloudKit-1A9EF5?logo=icloud)](https://developer.apple.com/icloud/cloudkit/)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

A daily iOS prediction game that measures and trains your calibration — whether your stated confidence in an answer actually matches how often you are right.

---

## What It Does

Each day, Calibrate presents 5 numeric estimation questions. For each question you submit:

- A **50% confidence interval** — a range you expect to contain the true answer about half the time
- A **90% confidence interval** — a wider range you expect to contain the true answer 9 times out of 10
- A **point estimate** — your single best guess

After all 5 answers are submitted, the true values are revealed. Over time the app computes a **Calibration Score** (0–100) that measures how closely your stated confidence matches your observed accuracy. A well-calibrated person whose 90% intervals are right about 90% of the time scores higher than someone who is overconfident or underconfident, regardless of raw accuracy.

A separate **Knowledge Score** tracks point-estimate accuracy (MAPE) so the two dimensions of performance are ranked independently.

---

## Screenshot

> _Screenshot placeholder — add device screenshot here_

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 6.0, strict concurrency |
| UI | SwiftUI (iOS 17+) |
| Local persistence | SwiftData |
| Remote sync | CloudKit (private + public containers) |
| In-app purchase | StoreKit 2 |
| Charts | Swift Charts |
| Question authoring | Python 3.12 + Anthropic SDK (local CLI, not shipped) |

---

## Prerequisites

- Xcode 16.0+
- iOS 17.0+ device or simulator
- An Apple Developer account with iCloud/CloudKit entitlements enabled
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.38+ (optional — project file is committed)

---

## Getting Started

1. **Clone the repo**

   ```bash
   git clone <repo-url>
   cd Calibrate
   ```

2. **Open the project**

   ```bash
   open Calibrate.xcodeproj
   ```

   Or regenerate from the spec if needed:

   ```bash
   xcodegen generate
   ```

3. **Configure signing**

   In Xcode, set your Development Team under *Signing & Capabilities* for the `Calibrate` target.

4. **Run**

   Select a simulator or connected device running iOS 17+ and press Run (⌘R). The app seeds a local question bank on first launch and schedules a daily 8 AM notification.

---

## Project Structure

```
Calibrate/
├── App/                    # Entry point, ModelContainer init, CKContainer setup
├── Models/                 # SwiftData models (Question, DailySet, Answer, UserProfile)
├── Services/
│   ├── CalibrationEngine   # Pure scoring logic — hit rates, error, score 0–100
│   ├── QuestionService     # CloudKit public DB fetch + local SwiftData cache
│   ├── UserService         # Answer persistence + profile sync to CloudKit private DB
│   └── ImportService       # JSON question bundle import + seed
├── Views/
│   ├── Game/               # Daily question carousel, interval input, results reveal
│   ├── History/            # Calibration dashboard, answer history
│   ├── Onboarding/         # First-launch tutorial with a non-scored demo question
│   ├── Leaderboard/        # Global leaderboard (Phase 2)
│   └── Settings/           # Preferences, premium upgrade, hidden admin panel
├── Utilities/              # DateUtils (UTC streak logic), NotificationScheduler, Constants
CalibrateTests/             # Unit tests — CalibrationEngine, DateUtils, QuestionService, etc.
project.yml                 # XcodeGen spec
```

---

## Running Tests

```bash
xcodebuild test \
  -project Calibrate.xcodeproj \
  -scheme Calibrate \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## License

MIT — see [LICENSE](LICENSE).
