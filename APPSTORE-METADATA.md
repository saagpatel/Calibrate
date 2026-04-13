# App Store Metadata — Calibrate

## Identity

| Field | Value |
|---|---|
| Name | Calibrate |
| Subtitle | Train Your Prediction Accuracy |
| Bundle ID | com.calibrate.app |
| SKU | CALIBRATE-001 |
| Primary Category | Education |
| Secondary Category | Games |
| Age Rating | 4+ |
| Price | Free |
| In-App Purchases | Calibrate Premium Monthly ($2.99/mo) · Calibrate Premium Annual ($14.99/yr) |
| Availability | All territories |

---

## Keywords

*(100 character limit — comma-separated)*

```
calibration,estimation,trivia,forecasting,prediction,quiz,knowledge,accuracy,statistics,daily
```

Character count: 93

---

## Description

*(4,000 character limit)*

**Are you as confident as you think you are?**

Most people are overconfident — their "90% sure" intervals contain the right answer only 60% of the time. Calibrate trains you to fix this, one set of questions per day.

Every day, Calibrate gives you five numeric estimation questions: What is the diameter of Mars? How many episodes did Friends run? What was Apple's revenue last quarter? For each question, you don't just guess a single number — you give a range you're 50% confident in and a wider range you're 90% confident in. Then you find out how you did.

Over time, your calibration score tells you the truth about your own uncertainty. A perfect score means your 50% intervals contain the answer 50% of the time, and your 90% intervals contain it 90% of the time. Getting there is harder than it sounds — and more useful than almost any other form of intellectual training.

**How it works**

For each question, enter five values:
- Your inner range (50% confidence interval)
- Your outer range (90% confidence interval)
- Your point estimate

After all five questions are locked in, Calibrate reveals every answer at once — no peeking between questions. You see exactly which intervals hit, which missed, and by how much. Your calibration score updates immediately.

**Two scores, two skills**

Calibrate tracks two separate dimensions of prediction quality:

- **Calibration score** — measures how accurately your stated confidence matches your observed accuracy. This is the skill of knowing what you don't know.
- **Knowledge score** — measures how close your point estimates are to the truth. This is how much you actually know.

Both scores are tracked over your last 30 questions (recent performance) and your full history (career performance), so you can see whether you are genuinely improving.

**Compete on what matters**

The global leaderboard ranks players by calibration score, not knowledge score. This means the leaderboard rewards intellectual honesty — the ability to accurately represent your own uncertainty — rather than trivia recall. A well-calibrated generalist will outrank an overconfident expert.

**Premium features**

Calibrate is free to play forever. The core daily game, calibration scores, streaks, and global leaderboard are all free.

Calibrate Premium adds:
- **Calibration Curve** — a reliability diagram showing exactly where your confidence drifts from reality at the 50% and 90% confidence levels
- **Friend Groups** — create or join a private group leaderboard with a 6-character invite code; compete with people you know
- **Domain Breakdown** — see your calibration score broken down by question category (geography, science, economics, history, pop culture, current events)

Premium is available as a monthly subscription ($2.99/month with 3-day free trial) or an annual subscription ($14.99/year with 7-day free trial). Cancel any time. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period.

**Daily rhythm**

Questions refresh at midnight UTC. The same set goes to every player on a given day, which means your score on today's set is directly comparable to everyone else's. Push notifications are available (opt-in) to remind you when your daily set is ready.

**Privacy**

Calibrate has no advertising. Your answer history is stored in your own iCloud private container — Calibrate's servers never see your individual answers. Only your aggregated calibration score and display name are shared with the public leaderboard. No tracking, no third-party SDKs.

---

## Promotional Text

*(170 character limit — can be updated without a new app review)*

```
New questions every day. Train the skill of knowing what you don't know — and compete on the global calibration leaderboard.
```

Character count: 124

---

## Support and Privacy URLs

| Field | URL |
|---|---|
| Support URL | https://[placeholder]/calibrate/support |
| Marketing URL | https://[placeholder]/calibrate |
| Privacy Policy URL | https://[placeholder]/calibrate/privacy |

*Replace with actual URLs before submission. The privacy policy must address: iCloud private database for answer history, CloudKit public database for leaderboard display name + calibration score, no third-party data sharing, StoreKit 2 subscription handling.*

---

## In-App Purchase Metadata

### Calibrate Premium Monthly
- **Product ID:** `com.calibrate.premium.monthly`
- **Reference Name:** Calibrate Premium Monthly
- **Price:** $2.99 / month
- **Free Trial:** 3 days
- **Display Name:** Calibrate Premium
- **Description:** Unlock the calibration curve chart, friend groups, and domain breakdown scores. Cancel anytime.

### Calibrate Premium Annual
- **Product ID:** `com.calibrate.premium.annual`
- **Reference Name:** Calibrate Premium Annual
- **Price:** $14.99 / year
- **Free Trial:** 7 days
- **Display Name:** Calibrate Premium (Annual)
- **Description:** Unlock the calibration curve chart, friend groups, and domain breakdown scores. Billed annually. Cancel anytime.

---

## Screenshots Plan

### iPhone 6.9" (iPhone 16 Pro Max — 1320×2868 px) — 4 required

| # | Screen | Description | Key elements to show |
|---|---|---|---|
| 1 | Question card — interval input in progress | QuestionCardView with a geography question active, dual interval bands partially filled in | Question text readable; 90% band (blue) visually wider than 50% band (amber); point estimate field; category tag (e.g. "Geography"); unit hint visible |
| 2 | Results view — batch reveal | ResultsView showing all 5 answers revealed simultaneously | Mix of hits (✓ checkmarks in amber/blue) and misses (✗); ground truth values displayed prominently; MAPE % visible; score delta at bottom (e.g. "+2.4 pts") |
| 3 | Calibration Dashboard | CalibrationDashboardView after several days of use | Career score and Recent (last 30) score as large numeric displays; hit rates for 50% and 90% intervals; current streak; "Today's set complete ✓" state |
| 4 | Premium Upgrade view or Calibration Curve (premium) | Either the PremiumUpgradeView showing the feature list and pricing, or the CalibrationCurveView showing a reliability diagram | If curve: data points plotted against the perfect calibration diagonal line, overconfident region shaded, underconfident region shaded; if paywall: clean feature list, trial callout, monthly + annual options |

### iPad 13" (iPad Pro M4 — 2064×2752 px) — 4 required

| # | Screen | Description |
|---|---|---|
| 1 | Onboarding tutorial — interactive demo | TutorialQuestionView showing the "How many bones in the adult human body?" demo question with intervals being entered |
| 2 | Daily set in progress — question 3 of 5 | DailySetView card carousel showing progress indicator (3/5), question card, and already-locked prior answers visible |
| 3 | Global leaderboard | LeaderboardView showing global top 20 with rank numbers, display names, calibration scores, and the current user's rank pinned at the bottom |
| 4 | Calibration Dashboard — wide layout | Full dashboard on iPad with career score, recent score, hit rate bars, streak, domain breakdown (premium) |

---

## App Review Notes

**How to test the core gameplay loop:**

1. Launch the app. Complete the onboarding tutorial (the tutorial uses a fixed demo question about human bones — it is non-scored and walks through the interval input widget)
2. On the home screen, tap "Play Today's Set"
3. For each of the 5 questions, enter five numeric values: lower 90% bound, lower 50% bound, point estimate, upper 50% bound, upper 90% bound. The fields enforce ordering constraints in real time — if your 50% interval extends outside your 90% interval, you will see an inline error and cannot proceed
4. Tap "Lock In" to submit each question. After locking question 5, the Results screen shows all answers simultaneously
5. The Calibration Dashboard is accessible from the Results screen

**CloudKit question delivery:** Questions are delivered from a CloudKit public database. On first launch with a network connection, the app fetches today's daily set. If offline, it falls back to locally cached questions. If you are testing in an environment without CloudKit access, the app may show "No questions available" — this is expected and not a crash.

**iCloud requirement for answer sync and leaderboard:** The CloudKit private database sync and the global leaderboard require the device to be signed into iCloud. If iCloud is not available, the app still functions for daily gameplay with local persistence only; the leaderboard will not load and answers will not sync across devices. This behavior is graceful — no crash, no error dialog.

**Admin hidden view:** There is a hidden admin view accessible by tapping the version label in Settings 5 times. This view is used by the developer to approve question content stored in a local question bank. For the purposes of App Review, this view only reads from and writes to the developer's own iCloud account and the app's local SwiftData store. It has no effect on other users' data. If this view raises concerns during review, it can be documented further or moved to a development-only build target.

**StoreKit 2 sandbox testing:** The premium subscription features (calibration curve, friend groups, domain breakdown) are accessible via sandbox purchase. To test: Settings → Calibrate Premium → select a plan → purchase in sandbox. After purchase, the three premium features unlock immediately without requiring an app restart.

**In-App Purchase restore:** A "Restore Purchases" button is present on the Premium Upgrade view. Tapping it re-verifies the current StoreKit 2 entitlement.

**Push notifications:** The app requests notification permission on first launch (after onboarding). A daily notification fires at 8:00 AM local time. Testing via Xcode's Simulator notification trigger is the recommended approach during review.

---

## Submission Checklist

### Metadata
- [ ] App name: "Calibrate" — confirm no trademark conflict in Education and Games categories
- [ ] Subtitle within 30 characters
- [ ] Keywords within 100 characters — include "calibration" and "estimation" (primary discovery terms)
- [ ] Description accurately describes the subscription terms and what is free vs. premium
- [ ] In-App Purchase display names and descriptions entered in App Store Connect for both products
- [ ] Free trial durations (3-day monthly, 7-day annual) accurately stated in IAP descriptions
- [ ] Promotional text within 170 characters
- [ ] Support URL live; Privacy Policy URL live and addresses iCloud data use
- [ ] Privacy policy URL added to App Store Connect IAP metadata as well

### Screenshots
- [ ] iPhone 6.9" — 4 screenshots at 1320×2868 px
- [ ] iPhone 6.1" — 4 screenshots (or use 6.9" — accepted)
- [ ] iPad 13" — 4 screenshots at 2064×2752 px
- [ ] At least one screenshot shows premium feature (calibration curve or friend groups) — required when app has IAP
- [ ] Screenshots show realistic calibration score data (not 100/100 — use realistic values like 68.3 career, 74.1 recent)

### Build
- [ ] `xcodebuild archive` succeeds on Release scheme, zero warnings
- [ ] Privacy manifest (`PrivacyInfo.xcprivacy`): declares leaderboard display name + score go to public CloudKit DB; answer history stays in user's private CloudKit DB; no tracking; no advertising; StoreKit 2 only (no payment data handled by app)
- [ ] CloudKit container `iCloud.com.calibrate.app` added to Capabilities and entitlements
- [ ] iCloud capability: CloudKit checked, container ID correct
- [ ] Push Notifications capability enabled (for daily local notifications — no remote push server used)
- [ ] StoreKit 2 products `com.calibrate.premium.monthly` and `com.calibrate.premium.annual` in "Ready to Submit" state in App Store Connect before submitting the binary
- [ ] App icon in all required sizes (1024×1024 source in asset catalog)
- [ ] Version 1.0, build number set
- [ ] Claude API key is NOT present anywhere in the Xcode project (it is a local Python CLI tool only)

### App Store Connect
- [ ] Age rating: 4+ (no violence, no mature content, no user-generated content beyond display name)
- [ ] Export compliance: standard encryption only (iCloud/CloudKit uses Apple's encryption) — answer "No" to custom encryption
- [ ] Primary category: Education; Secondary: Games
- [ ] Price: Free
- [ ] In-App Purchase: both subscription products created, pricing set, descriptions entered in all relevant locales
- [ ] Subscription group created: "Calibrate Premium" — both products in the same group so users cannot hold both simultaneously
- [ ] TestFlight: minimum 14 days of daily use, 0 crash reports, calibration scores show realistic variance, at least 1 complete subscription purchase + cancellation tested in production sandbox
- [ ] App Review Notes: include admin view explanation; note CloudKit requirement for leaderboard; include StoreKit sandbox instructions

## Copyright
© 2026 saagpatel
