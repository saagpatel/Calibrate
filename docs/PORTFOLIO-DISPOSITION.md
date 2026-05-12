# Calibrate — Portfolio Disposition

**Status:** Release Frozen — SwiftUI iOS prediction game on
`origin/main` with StoreKit 2 integration complete (Phase 3),
explicit `APPSTORE-METADATA.md` shipped on canonical main, and a
`fix(build): add DEVELOPMENT_TEAM for App Store signing` commit
indicating the operator has already wired App Store signing. **First
member of a new iOS App Store cluster** — distinct from the
Apple-desktop signing cluster (different submission process, different
review pipeline, different distribution channel).

> Disposition uses strict `origin/main` verification.
> **Introduces the iOS App Store cluster** as a fourth top-level
> disposition cluster (alongside Apple-desktop signing, static-host,
> self-hosted service).

---

## Verification posture

This repo has **only `origin`** (`saagpatel/Calibrate`) — no
`legacy-origin` remote. Clean migration state. Local clone's `main`
is tracking `origin/main` correctly.

Specifically verified on `origin/main`:

- Tip: `cfa444a` (HEAD)
- Substantive commits on `origin/main`:
  - `f6289aa` fix: regenerate xcodeproj from project.yml
  - `cd0031b` fix(build): add DEVELOPMENT_TEAM for App Store signing
  - `8c84035` fix(build): wire test target into scheme and use top-level schemes config
  - `63c1b24` feat(phase3): complete StoreKit config, environment fixes, and settings upgrade path
  - `6854549` feat: add GitHub Actions CI workflow
- Tree on `origin/main` is a real iOS Xcode project:
  - `Calibrate.xcodeproj/`
  - `Calibrate/` (Swift source)
  - `CalibrateTests/`
  - `ExportOptions.plist`
  - **`APPSTORE-METADATA.md`** — operator-prepared App Store
    submission package (identity, keywords, description)
  - `IMPLEMENTATION-ROADMAP.md`
- Release scaffolding on `origin/main`:
  - **`APPSTORE-METADATA.md`** (App Store submission package)
  - GitHub Actions CI workflow
  - `ExportOptions.plist` for `xcodebuild -exportArchive`
- Default branch: `main`

---

## Current state in one paragraph

Calibrate is a daily SwiftUI iOS prediction game that measures and
trains your calibration. Each day the user answers 5 numeric
estimation questions with 50% and 90% confidence intervals plus a
point estimate; over time a Calibration Score (0–100) reveals how
closely stated confidence matches observed accuracy. Per memory:
Phases 0-3 complete (StoreKit 2 in-app purchases, leaderboard,
friend groups). The `feat(phase3)` commit on canonical main confirms
StoreKit config + environment fixes + settings upgrade path are
shipped. App Store metadata is pre-prepared as a markdown file —
the operator has done the App Store Connect description /
keywords / identity work already and just needs to upload.

For full detail see:
- `README.md` on `origin/main`
- `APPSTORE-METADATA.md`
- `IMPLEMENTATION-ROADMAP.md`

---

## Why "Release Frozen (iOS App Store)" — NOT desktop signing cluster

Calibrate is an iOS app, not a macOS desktop app. The release
pipeline is materially different:

| Aspect | Desktop signing cluster | **iOS App Store cluster (new)** |
|---|---|---|
| Distribution channel | DMG / GitHub Releases | App Store Connect |
| Signing artifact | Developer ID Application | App Store Distribution Certificate + Provisioning Profile |
| Review process | Notarization (automated, fast) | App Store Review (human, days) |
| Pricing model | Free / direct sales | App Store IAP (StoreKit) |
| Update mechanism | Direct download / Sparkle | App Store auto-update |
| Sandboxing requirement | Optional | Mandatory |
| External integrations | Free | StoreKit + Apple ID |

The "gate" is therefore not just signing — it's a different
submission pipeline entirely.

This is the **first member of the iOS App Store cluster**. Other
iOS apps in the portfolio per memory (Afterimage, Ghost Routes,
Liminal, Nocturne, Redact, Room Tone, Seismoscope, Terroir, Tide
Engine, Wavelength, Chromafield) should join here when their
dispositions are written.

---

## Cluster taxonomy update

This row introduces the **fourth top-level disposition cluster**:

| Cluster | Count | Distribution |
|---|---|---|
| **Signing (Apple desktop)** | 22 | DMG via Apple Developer ID notarization |
| **iOS App Store (new)** | **1** | App Store Connect submission + review |
| **Static-host (web)** | 3 | Vercel / Netlify / etc. |
| **Self-hosted service** | 1 | launchd + nginx long-running service |

iOS App Store could materially grow given the iOS-app count in
operator memory — predict the cluster reaches 10+ members within
the next few audit rounds.

---

## Unblock trigger (operator)

When ready to ship:

1. **Apple Developer Program enrollment confirmed.** iOS App Store
   distribution requires the $99/year individual or org enrollment.
   `DEVELOPMENT_TEAM` is already wired per `cd0031b`, but the
   account-level enrollment must be active.
2. **App Store Connect record created.** `APPSTORE-METADATA.md`
   has identity / keywords / description prepared — operator
   transfers this into App Store Connect.
3. **StoreKit 2 IAP products configured in App Store Connect** to
   match the StoreKit config from `63c1b24` (Phase 3).
4. **App Store Review preparation:**
   - Privacy nutrition labels (data collection disclosure)
   - Age rating / content rating
   - Review notes for the reviewer if any non-obvious behavior
   - Screenshots for required device sizes (operator already has
     `screenshots/` dir locally per stash)
5. Build archive with `xcodebuild archive` + `xcodebuild
   -exportArchive` (config in `ExportOptions.plist`).
6. Upload to App Store Connect via Transporter or `xcrun altool`.
7. Submit for review.

Estimated operator time once enrollment + ASC record exist: ~4-6
hours (App Store Review can take 24-72 hours after submission,
but operator-time is the upload + screenshots + privacy labels).

---

## Portfolio operating system instructions

| Aspect | Posture |
|---|---|
| Portfolio status | `Release Frozen (iOS App Store)` |
| Distribution channel | **App Store Connect**, NOT direct DMG, NOT static host |
| Review cadence | Suspend overdue counting |
| Resurface conditions | (a) Operator submits for App Store Review, (b) review feedback requires changes, or (c) operator opens a v2 scope packet |
| Do **not** auto-add to desktop signing cluster | Different submission pipeline; different signing certificate |
| **New cluster: iOS App Store** | **First member.** Future iOS apps (Afterimage, Ghost Routes, Liminal, Nocturne, Redact, Room Tone, Seismoscope, Terroir, Tide Engine, Wavelength, Chromafield per memory) batch here. |
| Special concern | **Privacy nutrition labels.** Calibration data is local-first per StoreKit Phase 3 — labels should reflect this. |
| Special concern | **App Store Review uncertainty.** Unlike Apple notarization (automated, fast), App Store Review has human reviewers and can reject for reasons that aren't obvious from code. |

---

## Why this row founds the iOS App Store cluster

Every prior cluster in the session was discovered by examining
distribution shape. iOS App Store is the cleanest cluster boundary
seen so far:

- Different signing certificate type
- Different distribution channel (Apple's App Store, not direct
  download)
- Different review process (human review, multi-day, can reject)
- Different update mechanism (App Store auto-update)
- Different pricing model (App Store IAP via StoreKit)
- Different sandboxing posture (mandatory)

These differences don't compose with the desktop-signing playbook.
Any iOS app needs its own bring-up sequence.

---

## Reactivation procedure (for the next code session)

1. Verify `git branch -vv` shows `main` tracking `origin/main`.
   Already correct as of this disposition pass.
2. Review the local stash (`r11-calibrate-stash`) — contains mods
   to `CLAUDE.md` and `screenshots/screenshot-1.png` plus
   untracked `.claude/`.
3. **Open `Calibrate.xcodeproj` in Xcode** — confirm the
   regenerated xcodeproj from `project.yml` (`f6289aa`) still
   builds cleanly.
4. Run `xcodebuild test` against `CalibrateTests/` to confirm.
5. **Audit `APPSTORE-METADATA.md`** for any content that needs
   updating before App Store Connect entry (operator may have
   iterated on copy since writing it).
6. **Verify StoreKit 2 IAP product IDs match between Xcode
   StoreKit config and what will go into App Store Connect.**

---

## Last known reference

| Field | Value |
|---|---|
| `origin/main` tip | `cfa444a` (HEAD) |
| Last substantive commit | `cd0031b` fix(build): add DEVELOPMENT_TEAM for App Store signing |
| Default branch | `main` |
| Build system | **iOS / Swift / SwiftUI / Xcode / XCTest** — distinct from cross-platform desktop signing cluster |
| Phases shipped | 0-3 per memory (StoreKit 2 in-app purchases, leaderboard, friend groups). Phase 3 commit (`63c1b24`) confirms on canonical main. |
| Release scaffolding | **`APPSTORE-METADATA.md`** + GitHub Actions CI + `ExportOptions.plist` |
| Distribution channel | **App Store Connect**, not direct download |
| Blocker | App Store Connect submission flow (operator-only) |
| Migration state | **No `legacy-origin` remote** — clean |
| Distinguishing feature | **First iOS App Store cluster member.** Founds the cluster. ~11 iOS apps in memory should batch here in subsequent rounds. |
