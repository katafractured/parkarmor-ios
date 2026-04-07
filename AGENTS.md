# ParkArmor — Agent Instructions

## Project Purpose

iOS parking assistant app with Apple Watch companion. Saves parking location, tracks meter time, sends reminders before expiry, and logs parking history with photos. Pro tier (IAP) unlocks history and photo attachments.

## Tech Stack

- Swift / SwiftUI
- SwiftData (local persistence — parking records, history, photos)
- WatchKit / watchOS (Watch companion app)
- ActivityKit (Live Activities — meter countdown on lock screen)
- WidgetKit (home/lock screen widgets)
- StoreKit 2 (Pro tier IAP)
- MapKit (parking location display)
- UserNotifications (meter expiry alerts)

## Targets

| Target | Bundle ID | Purpose |
|---|---|---|
| ParkArmor | main app | iOS parking app |
| ParkArmorWatch Watch App | watch app | watchOS companion |
| ParkArmorWatch Watch AppTests | | Watch unit tests |
| ParkArmorWatch Watch AppUITests | | Watch UI tests |

## Key Files

```
ParkArmor/                   # Main iOS app source
ParkArmorWatch Watch App/    # watchOS companion source
ParkArmor.storekit           # StoreKit configuration for IAP testing
ParkArmor.xcodeproj
ci_scripts/                  # Xcode Cloud CI scripts
```

## How to Build

```bash
# iOS
xcodebuild -scheme ParkArmor -destination 'platform=iOS Simulator,name=iPhone 16' build

# watchOS
xcodebuild -scheme 'ParkArmorWatch Watch App' -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

## How to Run Tests

```bash
xcodebuild test -scheme ParkArmor -destination 'platform=iOS Simulator,name=iPhone 16'
```

## In-App Purchase

- **Free**: save parking location + basic timer
- **Pro**: parking history + photo attachments
- `ParkArmor.storekit` for local testing
- StoreKit 2 Transaction API for validation — no legacy receipt checks

## Architectural Patterns

- SwiftData for all persistence (parking records, photos stored as file references)
- Watch app uses WatchConnectivity to sync active parking session from phone
- Live Activities via ActivityKit for lock screen countdown
- UserNotifications for configurable pre-expiry alerts

## Constraints

- SwiftData schema migrations required for model changes — do not break existing saved records
- Live Activities have strict memory and CPU limits — keep ActivityAttributes lightweight
- Watch app communicates via WatchConnectivity only — no direct network calls from Watch
- `ci_scripts/` are for Xcode Cloud — do not modify without understanding CI pipeline
- StoreKit 2 only — do not use legacy receipt validation or SKPaymentQueue
- Photo attachments stored as file references in SwiftData, not as Binary Large Objects — do not change this pattern
