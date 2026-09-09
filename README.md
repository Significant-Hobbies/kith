# Kith

A private iPhone app for the people you keep close.

People you add float as warm bubbles. Closer relationships are larger. Tap
someone to write down what matters — a dinner, a call, a birthday, a thing
you want to remember.

Kith works without an account. People and notes save on the phone first;
private iCloud continuity and a Significant Hobbies Hub account are optional.
Local use does not wait for either service. Hub downloads commit locally
before their sync cursor advances, so a failed save can be retried.

The prior build-12/source `8d661d8` installation was signature-verified on
9 September 2026. Its launch was rejected because the phone was locked.
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

### Hub account ownership

Kith asks before connecting existing local people and notes to the displayed Hub
account. That approval is saved in the local document before upload. Signing in
to a different account leaves the original people available locally and asks
you to return to their original account to sync; it never transfers them
implicitly. A failed ownership save leaves the document unapproved and retryable.

The optional iCloud mirror pauses when its document has a different or unapproved
Hub owner, preserving both copies. Real account switching, reconciliation and
phone journeys remain in issue 27 and Significant Hobbies Hub issue 156.

### Hub date compatibility (9 September 2026)

The native decoder now accepts the Hub contract's date-only values and timestamps
with fractional seconds, including numeric time-zone offsets. A real native
coordinator regression reproduced the prior failure: valid downloaded people and
notes were omitted while their cursor advanced. The repaired path commits them
to the local document, survives disk reopen, and remains duplicate-free on replay.
Malformed required dates remain rejected; ownership checks are unchanged.
The full local native gate passed 39 tests (including eight UI tests) and unsigned
Release compilation using XcodeBuildMCP with stable Xcode 26.6.

This source repair does not rewind an existing cursor or recover records already
skipped by an older build. Safe historical replay and real signed-in/device
acceptance remain in [issue 27](https://github.com/Significant-Hobbies/kith/issues/27).
No phone records or provider settings were changed for the synthetic checks.
