# Kith

A private iPhone app for the people you keep close.

People you add float as warm bubbles. Closer relationships are larger. Tap
someone to write down what matters — a dinner, a call, a birthday, a thing
you want to remember.

Kith works without an account. People and notes save on the phone first;
private iCloud continuity and a Significant Hobbies Hub account are optional.
Local use does not wait for either service. Hub downloads commit locally
before their sync cursor advances, so a failed save can be retried.

Build 10 was signature-verified and installed on the owner's iPhone on
8 September 2026. Its launch was rejected because the phone was locked.
Physical use, real-account synchronization and public distribution remain
unqualified. Follow the current installation and usage checks in
[issue 27](https://github.com/Significant-Hobbies/kith/issues/27).

The public landing is the ios-landings factory at
https://kith.significanthobbies.com. Deploy it from that repo with
`pnpm run deploy:kith`. This repo holds no landing source.

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
