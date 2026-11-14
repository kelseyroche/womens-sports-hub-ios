# Rally for iPhone

Native SwiftUI iPhone app for following women's sports across leagues. Companion to the web app in `../womens-sports-hub`.

Every feature is built in both repos. The web app is the reference for design and behavior.

## Values

- No monetary gambling. No odds, spreads, betting lines or sportsbook sponsors. Fantasy and free prediction games are fine.
- Design matters most. Visual direction comes from the web app (Rally): flat league-colored tiles, big condensed numerals, yellow only for live games.

## Layout

- `Sources/RallyKit` shared logic: league catalog, ESPN client, game models. Builds and runs on macOS, no Xcode needed.
- `Sources/RallyProbe` command-line check that prints today's games from ESPN.
- `Tests/RallyKitTests` unit tests (need Xcode's XCTest).
- `App` SwiftUI screens. `project.yml` is an XcodeGen spec that generates the Xcode project.

## Run the core without Xcode

    swift run RallyProbe

## Run the app in the iPhone Simulator

1. Install Xcode from the Mac App Store, open it once, and accept the license.
2. `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. `brew install xcodegen`
4. `xcodegen generate && open Rally.xcodeproj`
5. Pick an iPhone simulator and press Run.

## Status

- Done: league catalog, ESPN scoreboard client, Today screen with game tiles.
- Verified: core builds and returns live ESPN data; app sources typecheck against the macOS SDK.
- Not yet verified: running on iPhone or the simulator, unit tests.
- Next: Following (saved on device), Tomorrow and Upcoming, game screen, player screen, push alerts, widgets, Live Activities.

## Source

Scores and schedules come from ESPN's unofficial API. It has no guarantee and is a risk for any public release.
