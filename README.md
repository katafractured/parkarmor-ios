# ParkArmor

ParkArmor is a privacy-first parking companion for iPhone, Apple Watch, widgets, Live Activities, and Siri Shortcuts.

It helps you save where you parked, find your car later, track parking timers, and surface that information across Apple platforms without sending your parking history to a server.

## Why This Is Open Source

ParkArmor is sold on the App Store as a polished consumer app, but the code is open because the project is built around two principles:

- Privacy should be inspectable, not just promised.
- Useful local-first software should be sustainable to maintain.

The App Store version funds ongoing development, testing, design work, and maintenance. The source is public because privacy-driven apps are stronger when people can verify how they work.

## Privacy Model

ParkArmor is designed to be on-device and local-first.

- No user accounts
- No cloud sync
- No analytics SDKs
- No ad tech
- No third-party backend
- No network dependency for core parking features

Parking data is stored locally and shared across app targets through the App Group container:

- `group.com.katafract.ParkArmor`

## Core Features

- Save your parking spot with notes and optional parking photos
- View active parking on the map and get walking directions back
- Parking meter timer with notifications and Live Activities
- Home Screen and Lock Screen widgets
- Siri Shortcuts via App Intents
- Auto-detect parking prompts
- Apple Watch companion app
- Watch complication support
- AR walk-back view on supported devices

## Business Model

ParkArmor Pro is a one-time paid upgrade sold on the App Store.

- Product ID: `com.katafract.ParkArmor.pro`
- App Store pricing and purchase handling are managed with StoreKit

Open source does not mean unsupported or abandoned. The paid App Store release is what funds continued work on the project.

## Platform Targets

- iOS 17.0+
- watchOS 10.0+

Project targets currently include:

- `ParkArmor`
- `ParkArmorWidgetExtension`
- `ParkArmorWatch Watch App`
- `ParkArmorWatchComplicationExtension`

## Technical Notes

ParkArmor is built with:

- SwiftUI
- SwiftData
- WidgetKit
- ActivityKit
- App Intents
- WatchConnectivity
- CoreLocation
- CoreMotion
- ARKit

The app follows a local-only architecture. Shared state for widgets and watch features is coordinated through SwiftData and App Group `UserDefaults`.

## Repository Layout

- [`ParkArmor/App`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmor/App) app entry and app-wide coordination
- [`ParkArmor/Models`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmor/Models) SwiftData models and preferences
- [`ParkArmor/Services`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmor/Services) location, notifications, StoreKit, watch sync, and supporting services
- [`ParkArmor/Screens`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmor/Screens) main app UI
- [`ParkArmorWidgetExtension`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmorWidgetExtension) widgets and Live Activity UI
- [`ParkArmorWatch Watch App`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmorWatch%20Watch%20App) Apple Watch companion app
- [`ParkArmorWatchComplication`](/Users/christianflores/Documents/GitHub/ParkArmor/ParkArmorWatchComplication) watch complication extension

## Running Locally

1. Open the Xcode project.
2. Select the `ParkArmor` app target.
3. Make sure signing, App Group capability, and StoreKit configuration are valid for your machine.
4. Build and run on an iPhone simulator or device.
5. For watch testing, run the watch app on a paired watch simulator or physical Apple Watch.

## App Store Release

The App Store distribution is a single iPhone app bundle that embeds its companion targets:

- iPhone app
- widget extension
- watch app
- watch complication extension

## Contributing

Issues and pull requests are welcome, especially around:

- privacy review
- accessibility
- Apple platform integrations
- widget and watch experience improvements
- bug fixes and stability

If you plan to contribute a large change, open an issue first so the implementation direction is clear.

## License

This repository does not currently include a standalone license file.

If you intend to reuse or redistribute code from this project, clarify licensing terms with the maintainer first.
