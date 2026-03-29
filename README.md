# Calibrate

[![Swift](https://img.shields.io/badge/Swift-f05138?style=flat-square&logo=swift)](#) [![License](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](#)

> Do you actually know what you know? Find out in 5 questions a day.

Calibrate is a daily iOS prediction game that measures and trains your calibration — whether your stated confidence matches how often you are right. Each day you answer 5 numeric estimation questions with 50% and 90% confidence intervals plus a point estimate. Over time a Calibration Score (0–100) reveals how closely your stated confidence maps to observed accuracy.

## Features

- **Daily 5-question rounds** — fresh numeric estimation questions each day
- **Dual scoring** — Calibration Score (interval accuracy) and Knowledge Score (point-estimate MAPE) tracked independently
- **Swift Charts visualization** — score history, confidence interval hit rates, and performance trends
- **CloudKit sync** — answers and scores sync privately across your devices
- **StoreKit 2** — optional premium question packs
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

## Tech Stack

| Layer | Technology |
|-------|------------|
| Language | Swift 6.0 (strict concurrency) |
| UI | SwiftUI (iOS 17+) |
| Local persistence | SwiftData |
| Remote sync | CloudKit (private + public containers) |
| In-app purchase | StoreKit 2 |
| Charts | Swift Charts |

## License

MIT
