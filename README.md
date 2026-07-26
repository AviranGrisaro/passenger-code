# passenger-code

Native iOS app for **Passenger** — one live map that shows what's packed right now and what's actually local.

> Land like a tourist. Move like a local.

## Stack

| | |
|---|---|
| Language | Swift 6.0, strict concurrency `complete` |
| UI | SwiftUI |
| Min OS | iOS 26.0 |
| Map | MapKit |
| Backend | Supabase (not wired yet — added when the first TRD calls for it) |
| Tests | Swift Testing (unit), XCTest (UI) |
| Bundle id | `com.avirangrisaro.passenger` |

No third-party Swift packages yet. That's deliberate — each one gets added when a TRD justifies it, not upfront.

## Layout

```
Passenger/            app target (file-system synchronized group)
  PassengerApp.swift  entry point
  RootMapView.swift   the map — the whole product lives here
PassengerTests/       unit tests (Swift Testing)
PassengerUITests/     UI tests (XCTest)
```

Targets use Xcode's **synchronized file groups** — adding a `.swift` file to the folder is enough, no `project.pbxproj` edit needed.

## Build & test

```bash
xcodebuild build -project Passenger.xcodeproj -scheme Passenger -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

```bash
xcodebuild test -project Passenger.xcodeproj -scheme Passenger -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:PassengerTests
```

## Status

Fresh start, 2026-07-26. Builds clean, one passing test. Nothing else is built yet — every feature comes from a PRD in `passenger-brain/prds/`, and every PRD must cite the strategy line that authorizes it.

## The old codebase

Passenger replaces **Locali**, a 16.5k-line Swift app that drifted into scope the strategy forbids (social graph, friend following, onboarding carousels). It is not deleted — it's frozen at `github.com/AviranGrisaro/locali`, branch `main`.

Before building a feature, check `passenger-brain/SALVAGE.md` — it inventories every old file with a reuse/reference/burn verdict. Salvage leaf code only (models, service clients, map math). Never architecture, view hierarchies, or state management; those are what went wrong.
