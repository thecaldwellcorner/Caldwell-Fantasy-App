# Caldwell-Fantasy-App

## Cursor Cloud specific instructions

### What this project is
This is **Caldwell Corner**, a native **iOS 17+ SwiftUI app** (a fantasy football
companion: dashboard, players/rankings, trade analyzer, AI assistant, draft, etc.).
It is an **Xcode project** (`CaldwellCorner.xcodeproj`, `objectVersion = 77` /
Xcode 16, `SDKROOT = iphoneos`, `IPHONEOS_DEPLOYMENT_TARGET = 17.0`). There is **no
Swift Package (`Package.swift`), no test target, and no SwiftLint config** in the repo.

> Source layout note: `main` currently contains only this README/AGENTS.md. The
> application source lives on branch `cursor/caldwell-corner-ios-app-fb0b` under
> `CaldwellCorner/` until it is merged.

### Hard platform limitation (read this first)
The **full app cannot be built, run, linted, or UI-tested on this Linux Cloud Agent
VM.** Building/running it requires **macOS + Xcode + the iOS SDK + iOS Simulator**,
which are Apple-only and unavailable on Linux. `SwiftUI`/`UIKit` are **not** part of
the open-source Linux Swift toolchain, so **any file that `import SwiftUI`** (all of
`Features/**`, `Theme/**`, `RootView.swift`, `CaldwellCornerApp.swift`,
`Data/AppState.swift`) will **not** compile here. Do not attempt `xcodebuild` — it
does not exist on Linux. To actually run the app, use a Mac with Xcode (open the
`.xcodeproj` and run on an iOS 17 simulator).

### What CAN be done on Linux (partial dev capability)
A **Swift 6.x toolchain is installed** (via `swiftly`, on `PATH` at
`~/.local/share/swiftly/bin`; check with `swift --version`). It can compile/run the
**platform-agnostic** code (Foundation/Combine only):
- `CaldwellCorner/Models/*.swift`
- `CaldwellCorner/Services/*.swift` (`TradeEngine`, `AIAssistant`)
- `CaldwellCorner/Data/MockData.swift`, `CaldwellCorner/Data/MockPlayers.swift`

Typecheck just the logic without UI:
```bash
swiftc -typecheck CaldwellCorner/Models/*.swift CaldwellCorner/Services/*.swift CaldwellCorner/Data/*.swift
```
To run/exercise the logic, compile those files together with a small driver. Gotcha:
**top-level statements are only allowed in a file literally named `main.swift`** — put
any throwaway driver code there (otherwise `swiftc` errors "expressions are not allowed
at the top level"). Keep such drivers outside the repo (e.g. in `/tmp`).

### Notes
- `systemImage` fields in the models are just SF Symbol **name strings**, not SwiftUI
  `Image`s, so the model/data files stay UI-free and compile on Linux.
- The Swift toolchain also needs these system libs (already installed during setup):
  `libcurl4-openssl-dev libpython3-dev libxml2-dev libncurses-dev libz3-dev gnupg2`.
