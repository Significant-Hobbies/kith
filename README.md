# Kith

A private iPhone app for the people you keep close.

People you add float as warm bubbles. Closer relationships are larger. Tap
someone to write down what matters — a dinner, a call, a birthday, a thing
you want to remember.

There is no Kith account. Notes live on the phone and, when you are signed
into iCloud, in your personal private CloudKit database (team
`8F7LXHTJZR`).

The public landing is the ios-landings factory at
https://kith.significanthobbies.com. Deploy it from that repo with
`pnpm run deploy:kith`. The `site/` folder here is leftover.

## Run

```bash
brew install xcodegen   # once
cd ios
xcodegen generate
open Kith.xcodeproj
```

Or from the repo root:

```bash
ios/scripts/check.sh
```

That regenerates the project, runs unit and UI tests on a simulator, and
builds an unsigned Release.

## Layout

- `ios/Sources/KithCore` — people, logs, and the local JSON document
- `ios/Sources/Kith` — SwiftUI constellation, person pages, and logging
- `ios/Tests` — XCTest for the document and the main interface

Launch with `--ui-demo` to load a fixed sample constellation instead of the
on-device document. `--fresh-demo` starts empty.
