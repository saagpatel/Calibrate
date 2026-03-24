# Calibrate — Implementation Roadmap

## Architecture

### System Overview
```
[CloudKit Public DB]              [CloudKit Private DB]
  DailySet records (date-keyed)     Answer history (user-owned)
  Question records (approved bank)  UserProfile (scores, streak)
  LeaderboardEntry records          PremiumEntitlement cache
        ↓                                   ↓
        └──────────── CKContainer ──────────┘
                           ↓
    ┌──────────────────────┼───────────────────────┐
    ↓                      ↓                       ↓
QuestionService       UserService            PremiumStore
(fetch + cache)    (answers + profile)   (StoreKit 2 actor)
    ↓                      ↓                       ↓
    └──────────── CalibrationEngine ───────────────┘
                           ↓
              ┌────────────┴────────────┐
              ↓                         ↓
         SwiftUI Views          AdminQuestionView
                                (gated, in-app)
                                        ↑
                             question_generator.py
                             (local Python CLI)
                                        ↑
                                 Claude API
```

### File Structure
```
Calibrate/
├── Calibrate.xcodeproj
├── Calibrate/
│   ├── App/
│   │   ├── CalibrateApp.swift              # @main entry, ModelContainer init, CKContainer setup
│   │   └── AppDelegate.swift               # UNUserNotificationCenter registration
│   ├── Models/
│   │   ├── Question.swift                  # SwiftData @Model + CK serialization helpers
│   │   ├── DailySet.swift                  # SwiftData @Model — 5-question daily bundle
│   │   ├── Answer.swift                    # SwiftData @Model — user's intervals + point estimate
│   │   ├── UserProfile.swift               # SwiftData @Model — scores, streak, metadata
│   │   └── LeaderboardEntry.swift          # Struct (not SwiftData) — CK public DB record shape
│   ├── Services/
│   │   ├── QuestionService.swift           # CK public DB fetch, local SwiftData cache, daily set resolution
│   │   ├── CalibrationEngine.swift         # Pure static functions — scoring, curve data, MAPE
│   │   ├── UserService.swift               # Answer persistence, profile sync to CK private DB
│   │   ├── LeaderboardService.swift        # CK public DB leaderboard reads/writes (Phase 2)
│   │   └── PremiumStore.swift              # @MainActor observable, StoreKit 2 (Phase 3)
│   ├── Views/
│   │   ├── Onboarding/
│   │   │   ├── OnboardingView.swift        # Shown once on first launch
│   │   │   └── TutorialQuestionView.swift  # Interactive non-scored demo question
│   │   ├── Game/
│   │   │   ├── DailySetView.swift          # Question carousel — drives game flow
│   │   │   ├── QuestionCardView.swift      # Single question + IntervalInputWidget
│   │   │   ├── IntervalInputWidget.swift   # Dual-range slider (50%=amber, 90%=blue) + point estimate
│   │   │   └── ResultsView.swift           # Batch reveal of all 5 + score delta
│   │   ├── History/
│   │   │   ├── CalibrationDashboardView.swift  # Career + recent scores, streak, hit rates
│   │   │   ├── CalibrationCurveView.swift      # Swift Charts reliability diagram (premium)
│   │   │   └── AnswerHistoryView.swift          # Paginated list of past answers
│   │   ├── Leaderboard/
│   │   │   ├── LeaderboardView.swift           # Global top 20 + user rank (Phase 2)
│   │   │   └── FriendGroupView.swift           # Group leaderboard — premium (Phase 3)
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── PremiumUpgradeView.swift        # Paywall (Phase 3)
│   │   │   └── AdminQuestionView.swift         # Hidden — 5-tap on version label
│   │   └── Components/
│   │       ├── CalibrationScoreBadge.swift     # Reusable score display chip
│   │       ├── StreakView.swift                # Flame + count
│   │       ├── QuestionCategoryTag.swift       # Color-coded category pill
│   │       └── PremiumLockOverlay.swift        # Blurred lock overlay for gated views
│   ├── Utilities/
│   │   ├── DateUtils.swift                 # UTC date flooring, streak logic, date string formatting
│   │   ├── NotificationScheduler.swift     # UNUserNotificationCenter daily scheduling
│   │   └── Constants.swift                 # CK container ID, product IDs, admin flag key
│   └── Resources/
│       ├── Assets.xcassets
│       └── Localizable.strings
├── CalibrateTests/
│   ├── CalibrationEngineTests.swift        # 8 unit tests — must pass before Phase 1
│   ├── QuestionServiceTests.swift          # Deterministic seed tests
│   └── DateUtilsTests.swift               # Edge cases: DST, midnight, Jan 1
├── scripts/
│   └── question_generator.py              # Local CLI: Claude API → JSON → admin review queue
└── CLAUDE.md
```

---

## Data Models

### SwiftData Models (local + CloudKit private DB sync)

```swift
// Question.swift
@Model class Question {
    var id: UUID
    var text: String
    var category: String            // "geography" | "science" | "economics" | "history" | "popCulture" | "currentEvents"
    var groundTruthValue: Double
    var groundTruthUnit: String     // e.g. "km", "trillion USD", "episodes"
    var groundTruthDate: Date       // date the value was verified
    var isEvergreen: Bool           // false = auto-retire after groundTruthDate + 365 days
    var sourceURL: String
    var explanation: String         // shown on results screen after reveal
    var difficulty: Double          // 0.0–1.0, set manually during admin review
    var isApproved: Bool            // admin gate — only approved questions enter daily sets
    var createdAt: Date

    init(id: UUID = UUID(), text: String, category: String, groundTruthValue: Double,
         groundTruthUnit: String, groundTruthDate: Date, isEvergreen: Bool,
         sourceURL: String, explanation: String, difficulty: Double = 0.5,
         isApproved: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.text = text; self.category = category
        self.groundTruthValue = groundTruthValue; self.groundTruthUnit = groundTruthUnit
        self.groundTruthDate = groundTruthDate; self.isEvergreen = isEvergreen
        self.sourceURL = sourceURL; self.explanation = explanation
        self.difficulty = difficulty; self.isApproved = isApproved; self.createdAt = createdAt
    }
}

// DailySet.swift
@Model class DailySet {
    var id: UUID
    var utcDate: String             // "2026-03-22" — primary lookup key, unique
    var questionIDs: [UUID]         // ordered array of exactly 5 approved question IDs
    var publishedAt: Date

    init(id: UUID = UUID(), utcDate: String, questionIDs: [UUID], publishedAt: Date = Date()) {
        self.id = id; self.utcDate = utcDate
        self.questionIDs = questionIDs; self.publishedAt = publishedAt
    }
}

// Answer.swift
@Model class Answer {
    var id: UUID
    var questionID: UUID
    var utcDate: String             // which daily set this answer belongs to
    var pointEstimate: Double
    var lower50: Double             // 50% interval lower bound
    var upper50: Double             // 50% interval upper bound
    var lower90: Double             // 90% interval lower bound
    var upper90: Double             // 90% interval upper bound
    var submittedAt: Date

    // Computed — not stored. Caller provides groundTruthValue from joined Question.
    func hit50(truth: Double) -> Bool { lower50 <= truth && truth <= upper50 }
    func hit90(truth: Double) -> Bool { lower90 <= truth && truth <= upper90 }
    func mape(truth: Double) -> Double {
        guard truth != 0 else { return 0 }
        return abs(pointEstimate - truth) / abs(truth)
    }

    init(id: UUID = UUID(), questionID: UUID, utcDate: String, pointEstimate: Double,
         lower50: Double, upper50: Double, lower90: Double, upper90: Double,
         submittedAt: Date = Date()) {
        self.id = id; self.questionID = questionID; self.utcDate = utcDate
        self.pointEstimate = pointEstimate; self.lower50 = lower50; self.upper50 = upper50
        self.lower90 = lower90; self.upper90 = upper90; self.submittedAt = submittedAt
    }
}

// UserProfile.swift
@Model class UserProfile {
    var id: UUID
    var displayName: String
    var joinedAt: Date
    var currentStreak: Int
    var longestStreak: Int
    var lastCompletedUTCDate: String    // "" if never completed
    var totalQuestionsAnswered: Int
    var isPremiumCached: Bool           // StoreKit is source of truth — this is cache only

    init(id: UUID = UUID(), displayName: String, joinedAt: Date = Date(),
         currentStreak: Int = 0, longestStreak: Int = 0,
         lastCompletedUTCDate: String = "", totalQuestionsAnswered: Int = 0,
         isPremiumCached: Bool = false) {
        self.id = id; self.displayName = displayName; self.joinedAt = joinedAt
        self.currentStreak = currentStreak; self.longestStreak = longestStreak
        self.lastCompletedUTCDate = lastCompletedUTCDate
        self.totalQuestionsAnswered = totalQuestionsAnswered
        self.isPremiumCached = isPremiumCached
    }
}
```

### CloudKit Public DB Record Types

```
CKRecord type: "Question"
  Fields:
    questionID      String      UUID string — matches local SwiftData Question.id
    text            String
    category        String
    groundTruthValue  Double
    groundTruthUnit String
    groundTruthDate Date
    isEvergreen     Int64       1 = true, 0 = false
    sourceURL       String
    explanation     String
    difficulty      Double
    isApproved      Int64       1 = true (only approved records synced to public DB)

CKRecord type: "DailySet"
  Fields:
    utcDate         String      "2026-03-22" — primary query field
    questionIDs     [String]    Array of UUID strings (ordered, length = 5)
    publishedAt     Date

CKRecord type: "LeaderboardEntry"
  Fields:
    userRecordName  String      CKRecord.ID.recordName of user's private DB record
    displayName     String
    calibrationScore  Double    Lower = better (calibration error ×100)
    totalAnswered   Int64
    lastUpdated     Date
    isPremium       Int64       1 = true

CKRecord type: "FriendGroup"  (Phase 3)
  Fields:
    groupID         String      6-char alphanumeric code
    groupName       String
    memberRecordNames [String]  Array of userRecordName strings
    createdBy       String      userRecordName of creator
    createdAt       Date
```

---

## Calibration Engine

```swift
// CalibrationEngine.swift — all functions are pure static, no side effects

struct AnswerWithTruth {
    let answer: Answer
    let truth: Double
}

enum CalibrationResult {
    case insufficient               // fewer than 5 answers in sample
    case result(CalibrationData)
}

struct CalibrationData {
    let score: Double               // 0–100, higher = better calibrated
    let hit50Rate: Double           // observed frequency for 50% intervals
    let hit90Rate: Double           // observed frequency for 90% intervals
    let error50: Double             // |0.50 - hit50Rate|
    let error90: Double             // |0.90 - hit90Rate|
    let overallError: Double        // mean(error50, error90)
    let sampleSize: Int
}

struct CalibrationEngine {

    /// Compute calibration score for a set of answers.
    /// - Parameters:
    ///   - answers: Array of AnswerWithTruth, sorted oldest→newest
    ///   - window: If provided, use only the last N answers (rolling window)
    static func calibrationResult(answers: [AnswerWithTruth], window: Int? = nil) -> CalibrationResult {
        let sample = window.map { Array(answers.suffix($0)) } ?? answers
        guard sample.count >= 5 else { return .insufficient }

        let hit50Rate = Double(sample.filter { $0.answer.hit50(truth: $0.truth) }.count) / Double(sample.count)
        let hit90Rate = Double(sample.filter { $0.answer.hit90(truth: $0.truth) }.count) / Double(sample.count)

        let error50 = abs(0.50 - hit50Rate)
        let error90 = abs(0.90 - hit90Rate)
        let overallError = (error50 + error90) / 2.0

        // Score: 0 = worst possible error (0.50 for both levels), 100 = perfect
        // Maximum possible overallError = 0.50 (all intervals miss at both confidence levels)
        let score = max(0.0, min(100.0, 100.0 - (overallError / 0.50 * 100.0)))

        return .result(CalibrationData(
            score: score,
            hit50Rate: hit50Rate,
            hit90Rate: hit90Rate,
            error50: error50,
            error90: error90,
            overallError: overallError,
            sampleSize: sample.count
        ))
    }

    /// Mean absolute percentage error of point estimates. Lower = more accurate.
    /// Returns 0–100 score (100 = perfect point estimates).
    static func knowledgeScore(answers: [AnswerWithTruth]) -> Double {
        guard !answers.isEmpty else { return 0 }
        let validAnswers = answers.filter { $0.truth != 0 }
        guard !validAnswers.isEmpty else { return 0 }
        let mape = validAnswers.map { $0.answer.mape(truth: $0.truth) }.reduce(0, +) / Double(validAnswers.count)
        return max(0.0, min(100.0, 100.0 - (mape * 100.0)))
    }

    /// Reliability diagram data points: [(statedConfidence, observedFrequency)]
    /// For Swift Charts calibration curve. Returns [(0.50, hit50Rate), (0.90, hit90Rate)].
    static func reliabilityPoints(answers: [AnswerWithTruth]) -> [(stated: Double, observed: Double)] {
        guard answers.count >= 5 else { return [] }
        let hit50Rate = Double(answers.filter { $0.answer.hit50(truth: $0.truth) }.count) / Double(answers.count)
        let hit90Rate = Double(answers.filter { $0.answer.hit90(truth: $0.truth) }.count) / Double(answers.count)
        return [(0.50, hit50Rate), (0.90, hit90Rate)]
    }
}
```

---

## Question Generator Script

```python
# scripts/question_generator.py
# Dependencies: pip install anthropic
# Usage: python question_generator.py --category economics --count 20 --output pending_review.json
# Claude API key must be in macOS Keychain under service "calibrate-claude-api"
# Add it once: security add-generic-password -s "calibrate-claude-api" -a "apikey" -w "sk-ant-..."
# Retrieve: security find-generic-password -s "calibrate-claude-api" -w

import anthropic, json, argparse, subprocess, sys
from datetime import datetime

VALID_CATEGORIES = ["geography", "science", "economics", "history", "popCulture", "currentEvents"]

SYSTEM_PROMPT = """You generate numeric estimation questions for a calibration game called Calibrate.

Rules for questions:
- Single numeric ground truth answer (no ranges, no approximations like "about 200")
- Verifiable from a publicly accessible source — include the URL
- Answerable without specialized domain expertise (general educated knowledge)
- Not trivially Googleable in under 5 seconds (avoid "What year was X founded?")
- Interesting — questions that make people think "huh, I had no idea"

Mark isEvergreen=false for values that change over time (GDP, population, box office, etc.).
isEvergreen=true for physical constants, historical facts, geographic measurements.

Return ONLY a valid JSON array. No preamble, no markdown, no explanation.

Schema for each object:
{
  "text": "Question text ending in a question mark?",
  "category": "geography|science|economics|history|popCulture|currentEvents",
  "groundTruthValue": 0.0,
  "groundTruthUnit": "unit of measurement (e.g. km, million km², trillion USD, episodes, meters)",
  "groundTruthDate": "YYYY-MM-DD (date value was verified)",
  "isEvergreen": true,
  "sourceURL": "https://...",
  "explanation": "One sentence explaining the answer and why it's interesting.",
  "estimatedDifficulty": 0.5
}"""

def get_api_key() -> str:
    result = subprocess.run(
        ["security", "find-generic-password", "-s", "calibrate-claude-api", "-w"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("ERROR: API key not found in Keychain.")
        print("Add it with: security add-generic-password -s 'calibrate-claude-api' -a 'apikey' -w 'YOUR_KEY'")
        sys.exit(1)
    return result.stdout.strip()

def generate_questions(category: str, count: int) -> list[dict]:
    client = anthropic.Anthropic(api_key=get_api_key())
    user_prompt = f"Generate {count} estimation questions in the '{category}' category. Vary difficulty from 0.2 to 0.9."

    response = client.messages.create(
        model="claude-opus-4-5",
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": user_prompt}]
    )

    raw = response.content[0].text.strip()
    # Strip markdown fences if present
    if raw.startswith("```"):
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    return json.loads(raw.strip())

def main():
    parser = argparse.ArgumentParser(description="Generate Calibrate questions via Claude API")
    parser.add_argument("--category", choices=VALID_CATEGORIES, required=True)
    parser.add_argument("--count", type=int, default=20)
    parser.add_argument("--output", default="pending_review.json")
    args = parser.parse_args()

    print(f"Generating {args.count} {args.category} questions...")
    questions = generate_questions(args.category, args.count)

    # Add metadata
    for q in questions:
        q["isApproved"] = False
        q["generatedAt"] = datetime.utcnow().isoformat() + "Z"

    with open(args.output, "w") as f:
        json.dump(questions, f, indent=2)

    print(f"✓ {len(questions)} questions written to {args.output}")
    print(f"Open AdminQuestionView in the app to review and approve.")

if __name__ == "__main__":
    main()
```

---

## API Contracts

| Service | Endpoint | Method | Auth | Rate Limit | Purpose |
|---------|----------|--------|------|------------|---------|
| CloudKit Web Services | `https://api.apple-cloudkit.com/database/1/{container}/development/public/records/query` | POST | CK Web Auth Token | 40 req/sec | Query DailySet and Question records |
| CloudKit Web Services | `.../records/modify` | POST | CK Web Auth Token | 40 req/sec | Write LeaderboardEntry, FriendGroup |
| Anthropic Messages API | `https://api.anthropic.com/v1/messages` | POST | API Key (Keychain) | 50 req/min | Question generation (local script only) |
| StoreKit 2 | Native framework | N/A | iCloud/App Store | N/A | Subscription purchase + entitlement |

**CloudKit query for today's DailySet:**
```json
POST /database/1/iCloud.com.calibrate.app/development/public/records/query
{
  "recordType": "DailySet",
  "filterBy": [{
    "fieldName": "utcDate",
    "comparator": "EQUALS",
    "fieldValue": { "value": "2026-03-22", "type": "STRING" }
  }]
}
```

---

## Scope Boundaries

**In scope (v1.0):**
- Daily 5-question game with 50% + 90% interval input + point estimate
- Local SwiftData persistence with CloudKit private DB sync
- Calibration score (career + last-30) and knowledge score
- Daily streak tracking
- CloudKit public DB for question delivery and leaderboard
- Global leaderboard (top 100 + user rank)
- Admin question review UI (in-app, hidden)
- Local question generation pipeline (Python CLI + Claude API)
- Daily push notifications
- Onboarding tutorial
- StoreKit 2 premium subscription
- Premium: calibration curve chart, friend groups, domain breakdown scores

**Out of scope:**
- Web companion app
- Android app
- Community question submission
- Prediction markets (event-based forecasting)
- Multiplayer / real-time competition
- Apple Watch app
- Widgets (Lock Screen, Home Screen)

**Deferred to v1.1+:**
- Community question submission pipeline
- Advanced mode (multi-confidence levels: 25%, 50%, 75%, 90%)
- Domain-specific calibration scores breakdown
- Historical replay (re-play past sets)
- Team/organizational calibration

---

## Security & Credentials

- **Claude API key:** macOS Keychain only, service name `calibrate-claude-api`. Never in Xcode project, never in `.env`, never committed to git. Python script reads it via `security find-generic-password`.
- **CloudKit auth:** Transparent via CloudKit framework — user's iCloud account. No credentials to manage in the app.
- **StoreKit 2:** No server-side receipt validation required. `Transaction.currentEntitlement(for:)` is the source of truth. App never handles raw payment data.
- **User data:** Answer history stored exclusively in user's CloudKit private DB. Calibrate has no server that receives or stores user answers. Only leaderboard aggregates (display name + score) go to public DB.
- **Admin mode:** `isAdminMode` in UserDefaults. Bypassable by a determined user — acceptable because admin actions only write to your own iCloud account and local SwiftData. Not a security risk.
- **`.gitignore` must include:** `*.xcconfig` with secrets, `scripts/.env` if ever added, `DerivedData/`

---

## Phase 0: Foundation + Calibration Engine (Weeks 1–2)

**Objective:** Scaffolded Xcode project with SwiftData models, working calibration math (unit-tested), functional admin UI, and ≥100 approved questions in the local bank. No game UI.

**Tasks:**

1. Create Xcode project: SwiftUI app, iOS 17.0 deployment target. Enable iCloud capability, add CloudKit container `iCloud.com.calibrate.app`. Add `CKContainer.default()` init in `CalibrateApp.swift`.
   **Acceptance:** `Command+B` succeeds. CloudKit Dashboard (developer.apple.com) shows `iCloud.com.calibrate.app` container in Development schema.

2. Define all SwiftData models per the Data Models section above: `Question`, `DailySet`, `Answer`, `UserProfile`. Add `ModelContainer(for: Question.self, DailySet.self, Answer.self, UserProfile.self)` to `CalibrateApp.swift`.
   **Acceptance:** App launches in simulator without crash. Xcode preview renders `QuestionCardView` placeholder with mock `Question` data injected directly.

3. Implement `CalibrationEngine.swift` with `calibrationResult(answers:window:)`, `knowledgeScore(answers:)`, and `reliabilityPoints(answers:)` exactly as specified above.
   **Acceptance:** `CalibrationEngineTests.swift` passes all 8 tests:
   - Perfect calibration (50% of 50% intervals hit, 90% of 90% intervals hit) → score = 100
   - All overconfident (0% hit rate both levels) → score = 0
   - All underconfident (100% hit rate both levels) → score = 0
   - Perfectly calibrated 50%, all miss 90% → score = 50
   - window=30 with 50 answers uses only last 30
   - window=5 with 3 answers returns `.insufficient`
   - Empty input returns `.insufficient`
   - knowledgeScore with perfect point estimates returns 100

4. Implement `DateUtils.swift`: `currentUTCDate() -> String` (returns "YYYY-MM-DD" floored to UTC), `isToday(utcDate: String) -> Bool`, `daysBetween(from: String, to: String) -> Int` (for streak calculation).
   **Acceptance:** `DateUtilsTests.swift` passes: UTC midnight edge case returns correct date; two consecutive dates return daysBetween = 1; same date returns 0.

5. Implement `question_generator.py` per the script spec above. Run for all 6 categories (20 questions each = 120 total). Output to `scripts/pending_review.json`.
   **Acceptance:** Script runs without error. Output is valid JSON. Spot-check 5 random questions: source URLs are live and confirm ground truth values.

6. Build `AdminQuestionView.swift`: SwiftUI `List` showing all `isApproved == false` Questions. Each row: question text, category tag, ground truth value + unit, source URL as tappable link, difficulty slider (0.0–1.0), Approve button (green), Reject button (red, deletes record).
   **Acceptance:** Hidden behind 5-tap gesture on version label in `SettingsView`. Tapping Approve sets `isApproved = true` and saves to SwiftData. Tapping Reject deletes the record. Approved count visible in Settings debug row.

7. Import `pending_review.json` into SwiftData via a temporary `ImportService` (can be a button in AdminQuestionView for now). Review and approve ≥100 questions.
   **Acceptance:** SwiftData store contains ≥100 `Question` records with `isApproved == true`, distributed across all 6 categories (minimum 15 per category).

**Verification checklist:**
- [ ] `Command+U` → CalibrationEngineTests: 8/8 pass, DateUtilsTests: all pass
- [ ] App launches on iPhone 15 Pro simulator without crash or warning
- [ ] Admin view accessible via 5-tap gesture; approve/reject functional
- [ ] ≥100 approved questions in SwiftData store (verify count in admin debug row)
- [ ] CloudKit Dashboard shows container in Development schema

**Risks:**
- SwiftData + CloudKit sync configuration is tricky on first setup (entitlement conflicts, container ID typos).
  - Mitigation: Follow Apple's "Syncing Model Data Across a Person's Devices" sample code exactly.
  - Fallback: Disable CloudKit sync in Phase 0 (local SwiftData only); re-enable in Phase 2.

---

## Phase 1: Core Gameplay Loop (Weeks 3–5)

**Objective:** Complete, playable daily game on-device. 5 questions, dual-interval input, batch answer reveal, calibration score updates, streak tracking, push notifications, onboarding. No CloudKit question delivery yet — questions come from local SwiftData.

**Tasks:**

1. Implement `QuestionService.swift` (local-only for Phase 1). `fetchDailySet(for utcDate: String) -> DailySet?` checks SwiftData for a stored `DailySet` with matching `utcDate`. If none exists, generates one deterministically: seed a shuffled array of approved question IDs using `utcDate` as the seed string (use `utcDate.hashValue` as `Int64` seed for `SystemRandomNumberGenerator` alternative — use a seeded LCG or `Array.shuffled(using:)` with a deterministic RNG). Store the generated `DailySet` in SwiftData.
   **Acceptance:** Calling `fetchDailySet(for: "2026-03-22")` three times returns identical `questionIDs`. Different dates return different (but consistent) sets. `QuestionServiceTests.swift` verifies determinism.

2. Build `IntervalInputWidget.swift`. Requirements:
   - Numeric text fields (not sliders — sliders are imprecise for wide numeric ranges) for: lower90, lower50, point estimate, upper50, upper90
   - Fields arranged left-to-right in that order with visual nesting (90% band in blue, 50% band in amber)
   - Real-time validation: enforce `lower90 ≤ lower50 ≤ pointEstimate ≤ upper50 ≤ upper90`. If violated, show inline red error text and disable "Lock In" button.
   - Unit label displayed next to each field (e.g., "km")
   - Numeric keyboard with decimal support
   **Acceptance:** User cannot submit when constraints are violated. Error clears immediately when constraints are restored. Renders correctly in dark mode.

3. Build `QuestionCardView.swift`: question text (large, readable), category tag, unit hint ("Your answer will be in: km"), `IntervalInputWidget`. Build `DailySetView.swift`: TabView-style card carousel for 5 questions, progress indicator (1/5 → 2/5 etc.), "Lock In" button per question. Navigates to `ResultsView` after question 5.
   **Acceptance:** User can swipe forward only after current question fields pass validation. "Lock In" on Q5 triggers navigation to `ResultsView` and writes all 5 `Answer` records to SwiftData atomically (all or nothing).

4. Build `ResultsView.swift`. For each of the 5 questions, show:
   - Question text
   - Ground truth value + unit (large, prominent)
   - Whether 50% interval hit (✓ amber) or missed (✗)
   - Whether 90% interval hit (✓ blue) or missed (✗)
   - Point estimate vs. truth (MAPE % shown)
   - Source URL tappable
   - Brief explanation text
   - Bottom summary: today's calibration score delta ("+3.2 pts" or "−1.1 pts"), current career score
   **Acceptance:** All 5 results display correctly. Score delta matches `CalibrationEngine` output. "See your dashboard" button navigates to `CalibrationDashboardView`.

5. Build `CalibrationDashboardView.swift`:
   - Career calibration score (all-time, large display)
   - Recent calibration score (last 30 questions)
   - Hit rate for 50% intervals (e.g., "42% of your 50% intervals contained the truth — ideal is 50%")
   - Hit rate for 90% intervals
   - Knowledge score (point estimate accuracy)
   - Current streak + longest streak
   - "Today's set complete ✓" or "Play today's set →" CTA
   **Acceptance:** All values recompute correctly after completing a daily set. Values persist across app restart (read from SwiftData on appear).

6. Guard against replaying the same UTC date: in `DailySetView.swift`, on appear check `UserProfile.lastCompletedUTCDate`. If it matches `DateUtils.currentUTCDate()`, show "Come back tomorrow" screen instead of questions.
   **Acceptance:** Completing a set then force-quitting and reopening shows the completed state, not the question carousel.

7. Implement `NotificationScheduler.swift`. On first launch (after permission grant), schedule a repeating daily local notification at 8:00 AM user local time. Content: title "Your daily calibration is ready", body "5 questions. 2 minutes. How well do you know what you don't know?" Reschedule on each app launch to keep it current.
   **Acceptance:** Notification permission prompt appears on first launch. Notification fires in simulator using `Triggers` debug (skip to 8 AM). Permission denial is handled gracefully (no crash, no repeated prompts).

8. Build `OnboardingView.swift` + `TutorialQuestionView.swift`. Show on first launch (UserDefaults `hasCompletedOnboarding` flag). Tutorial uses a fixed demo question ("How many bones are in the adult human body?", answer: 206) to walk through the interval input. Non-scored. "Got it →" button marks onboarding complete.
   **Acceptance:** Shown exactly once. Both "Skip" and "Got it" routes mark `hasCompletedOnboarding = true`. Tutorial question input works identically to real `IntervalInputWidget`.

**Verification checklist:**
- [ ] Complete full 5-question set; all 5 `Answer` records in SwiftData post-completion
- [ ] Calibration scores update correctly (verify manually: submit all correct 90% intervals → hit rate should increase)
- [ ] Same UTC date cannot be played twice (force-quit test)
- [ ] Local notification appears at correct time
- [ ] Onboarding shown on fresh install, not on second launch
- [ ] `IntervalInputWidget` rejects invalid interval ordering in real-time

**Risks:**
- Custom numeric interval input is complex to build without native RangeSlider. Five numeric fields is the safer approach for v1.
  - Mitigation: Use `TextField` with `.keyboardType(.decimalPad)` and `onChange` validation.
  - Fallback: If UX feels clunky in TestFlight, ship Phase 1 with only 90% interval (lower90, upper90, pointEstimate) and add 50% in v1.1.

---

## Phase 2: CloudKit Sync + Leaderboard (Weeks 6–8)

**Objective:** Questions delivered from CloudKit public DB. Answer history synced to CloudKit private DB (multi-device). Global leaderboard functional. Calibration curve chart built (premium-gated).

**Tasks:**

1. Seed CloudKit public DB: add `--upload` flag to `question_generator.py` that writes approved questions and pre-generated `DailySet` records for 90 days to CloudKit public DB via CloudKit Web Services API. Requires a CK web auth token (generate in CloudKit Dashboard → API Access).
   **Acceptance:** CloudKit Dashboard shows ≥100 `Question` records and 90 `DailySet` records in Development environment. Query via CK Dashboard returns correct record for today's UTC date.

2. Update `QuestionService.swift`: `fetchDailySet(for:)` first attempts CloudKit public DB query (CK `CKQueryOperation` on `DailySet` recordType, filter `utcDate == target`). On success, fetch all 5 referenced `Question` records by ID. Cache in SwiftData for 7 days. On failure (offline/timeout), fall back to local cache.
   **Acceptance:** Fresh install with LTE fetches correct set in < 2 seconds. Airplane mode uses cached set. Stale cache (> 7 days old) triggers background refresh on next launch.

3. Implement CloudKit private DB sync in `UserService.swift`. After each daily set completion, write a `CKRecord` (type: `Answer`) for each of the 5 answers to the user's private CloudKit container. Also sync `UserProfile` record (calibration scores, streak). Use `CKModifyRecordsOperation` for batch writes.
   **Acceptance:** Complete daily set on iPhone. Open app on iPad with same iCloud account. History and calibration score match within 60 seconds. (Test requires two physical devices or one device + simulator logged into same iCloud account.)

4. Implement `LeaderboardService.swift`. After daily set completion, compute user's current calibration score and upsert their `LeaderboardEntry` CKRecord in public DB (match on `userRecordName`). `fetchLeaderboard() -> [LeaderboardEntry]` fetches top 100 sorted by `calibrationScore` ascending (lower error = better), plus a separate query for the user's own entry.
   **Acceptance:** Two test accounts both complete daily set. `LeaderboardView` shows both accounts with correct scores and relative ranking within 2 minutes of completion.

5. Build `LeaderboardView.swift`: top 20 entries with rank number, display name, calibration score, total answered. User's own entry always visible (pinned at bottom if outside top 20, showing actual rank). Pull-to-refresh.
   **Acceptance:** Renders correctly with ≥2 test accounts. "Rank #3 of 47 players" format. Empty state: "No leaderboard data yet — complete today's set to appear."

6. Build `CalibrationCurveView.swift` using Swift Charts. Reliability diagram: X-axis = stated confidence (0%–100%), Y-axis = observed frequency (0%–100%). Two data points: (50%, observed50Rate) and (90%, observed90Rate). Reference line: perfect calibration diagonal (0,0) → (1,1). Color-coded: overconfident region shaded red, underconfident region shaded blue. Wrap in `PremiumLockOverlay` for free users.
   **Acceptance:** Chart renders correctly for 30+ answers. Reference diagonal is visible. Overconfident user (hit90Rate = 60%) shows data point below the diagonal. Premium lock overlay appears for non-premium users.

**Verification checklist:**
- [ ] Questions fetch from CK public DB on cold launch (verify via Xcode Network Instrument — look for `api.apple-cloudkit.com` requests)
- [ ] Airplane mode: cached set loads without error
- [ ] Answers sync to CK private DB — verify on second device within 60 seconds
- [ ] Leaderboard updates after completing set (allow up to 2 minutes for CK propagation)
- [ ] Calibration curve renders correctly and updates after new answers

**Risks:**
- CloudKit private DB sync conflicts if user answers on two devices in same UTC day (shouldn't happen — same UTC date = same set, already completed).
  - Mitigation: Lock daily set on first `Answer` write. Subsequent writes for same `utcDate` are no-ops.
  - Fallback: If CK private sync proves flaky in testing, ship Phase 2 with public leaderboard only; private sync as v1.1 patch.

---

## Phase 3: StoreKit 2 + Premium + App Store Submission (Weeks 9–10)

**Objective:** Full StoreKit 2 subscription, premium features gated, App Store assets, TestFlight distribution.

**Tasks:**

1. Configure products in App Store Connect:
   - `com.calibrate.premium.monthly` — $2.99/month, 3-day free trial
   - `com.calibrate.premium.annual` — $14.99/year, 7-day free trial
   **Acceptance:** Products visible and in "Ready to Submit" state in App Store Connect. Purchasable in StoreKit 2 sandbox environment.

2. Implement `PremiumStore.swift` as `@MainActor final class PremiumStore: ObservableObject`:
   ```swift
   @Published var isPremium: Bool = false

   func load() async {
       // Check current entitlement on app launch
       for await result in Transaction.currentEntitlements {
           if case .verified(let transaction) = result,
              ["com.calibrate.premium.monthly", "com.calibrate.premium.annual"].contains(transaction.productID) {
               isPremium = true
               return
           }
       }
       isPremium = false
   }

   func purchase(product: Product) async throws { ... }
   func restore() async { await load() }
   ```
   Call `await premiumStore.load()` in `CalibrateApp.swift` `.task` modifier on launch.
   **Acceptance:** Sandbox purchase sets `isPremium = true` immediately. Force-quit and reopen — still premium. Cancel subscription in sandbox → `isPremium` becomes false on next `load()` call.

3. Wrap premium features with `PremiumLockOverlay`:
   - `CalibrationCurveView`: blur + lock icon + "Unlock with Calibrate Premium" CTA
   - `FriendGroupView` tab: replaced with "Premium" badge tap → `PremiumUpgradeView`
   - Domain breakdown scores section in `CalibrationDashboardView`: lock overlay
   **Acceptance:** Free users see lock on all 3 surfaces. Premium users see content with no visible lock or flash. Downgrading (sandbox cancel) re-applies locks on next launch.

4. Build `PremiumUpgradeView.swift`: displays both subscription options, feature list (3 bullet points), free trial callout, purchase buttons, restore button, terms/privacy links.
   **Acceptance:** Purchase flow works end-to-end in sandbox. Restore button recovers subscription after reinstall. Loading state shown during purchase async operation.

5. Build `FriendGroupView.swift`: "Create group" (generates 6-char alphanumeric `groupID` CKRecord in public DB, displays shareable code) + "Join group" (text field for code → fetch matching CKRecord → add `userRecordName` to `memberRecordNames` array). Group leaderboard: same format as global but filtered to group members.
   **Acceptance:** Two test accounts: Account A creates group and shares 6-char code. Account B joins. Both complete daily set. Group leaderboard shows both accounts with correct ranking.

6. App Store submission assets:
   - Screenshots: iPhone 15 Pro (6.7"), iPhone 15 (6.1"), iPad Pro 12.9" — 3 screenshots each (onboarding, gameplay, dashboard)
   - App description: written, keyword-optimized (calibration, estimation, trivia, knowledge)
   - Privacy policy URL: host on GitHub Pages (simple markdown → HTML)
   - Privacy manifest (`PrivacyInfo.xcprivacy`): declare no data collected except for leaderboard display name + score
   **Acceptance:** App Store Connect shows 0 metadata warnings or errors. Privacy manifest passes Xcode validation.

7. TestFlight: distribute to internal group. Minimum 14 days of daily use before App Store submission.
   **Acceptance:** 0 crash reports in Xcode Organizer. Calibration scores show realistic variance over 14 days of data. At least 1 full subscription purchase + cancellation cycle tested in production sandbox.

**Verification checklist:**
- [ ] `com.calibrate.premium.monthly` and `.annual` purchasable in sandbox
- [ ] `isPremium` persists across reinstall (entitlement check, not UserDefaults)
- [ ] All 3 premium gates show lock for free users, content for premium users
- [ ] Friend group create + join works between 2 test devices
- [ ] App Store Connect: 0 metadata warnings, privacy manifest validates
- [ ] 14-day TestFlight with no crashes

**Risks:**
- App Store review may flag the admin hidden UI as suspicious.
  - Mitigation: Document in App Review Notes: "A hidden admin view (5-tap gesture on version label in Settings) is used by the developer to curate question content. It only writes to the developer's own iCloud account and has no effect for other users."
  - Fallback: If rejected for this reason, move admin to a separate dev-only build target with a different bundle ID.

---

## StoreKit 2 Product IDs Reference

```
com.calibrate.premium.monthly    $2.99/month    3-day free trial
com.calibrate.premium.annual     $14.99/year    7-day free trial
```

## CloudKit Container Reference

```
Container ID:     iCloud.com.calibrate.app
Public DB:        Questions, DailySets, LeaderboardEntries, FriendGroups
Private DB:       Answers, UserProfile (per-user, iCloud-owned)
```

## Constants.swift Reference

```swift
// Constants.swift
enum Constants {
    enum CloudKit {
        static let containerID = "iCloud.com.calibrate.app"
        static let questionRecordType = "Question"
        static let dailySetRecordType = "DailySet"
        static let leaderboardRecordType = "LeaderboardEntry"
        static let friendGroupRecordType = "FriendGroup"
    }
    enum StoreKit {
        static let monthlyProductID = "com.calibrate.premium.monthly"
        static let annualProductID = "com.calibrate.premium.annual"
    }
    enum UserDefaults {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAdminMode = "isAdminMode"
    }
    enum Notifications {
        static let dailyCategoryID = "DAILY_CALIBRATION"
        static let dailyHour = 8   // 8:00 AM local time
        static let dailyMinute = 0
    }
    enum Calibration {
        static let recentWindowSize = 30    // last N questions for "recent" score
        static let minimumSampleSize = 5    // minimum answers before showing score
    }
}
```
