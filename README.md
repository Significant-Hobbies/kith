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
The full local native gate passed 41 tests (including eight UI tests) and unsigned
Release compilation using XcodeBuildMCP with stable Xcode 26.6.

The optional **Recover missing Hub records** action now rechecks the approved
account’s history using PersonalSyncKit `629d8e7`. It restores missing records even
when an older build already saved their cursor, version and fingerprint. Current
local details and deletion markers remain authoritative; edits during the request
are preserved. Pagination finishes before a durable local commit and cursor update,
so interrupted downloads or failed saves can be retried. Replay is bounded to 100
pages of at most 500 changes and can fail without acknowledging a partial history.
Real signed-in/device recovery acceptance remains in
[issue 27](https://github.com/Significant-Hobbies/kith/issues/27).
No phone records or provider settings were changed for the synthetic checks.

### Actual caller isolation proof (9 September 2026)

Two additional tests exercise `AppModel.approvePlatformAccount` and
`syncFromPlatform` through an isolated URL session and memory-only synthetic
identities. Switching from A to B during a held response rejects A's downloaded
person and cursor, preserves A's queued mutation, and creates no success or
recovery receipt for B. A failed local download save stays retryable; the actual
recovery caller then commits the person and cursor together, verified on disk
reopen. No product defect was reproduced by these scenarios.

PersonalSyncKit `31f6b4e` adds an explicit composition initializer for this test
isolation; its default production connection is unchanged. The full native suite
passes 43 tests, including eight UI tests, with no skips; unsigned Release
compilation also passes on stable Xcode 26.6. This is synthetic caller
proof, not Google sign-in, physical phone use, iCloud convergence or public
distribution. The installed build and remaining acceptance in issue 27 are
unchanged.

### Rendered local persistence proof (9 September 2026)

The isolated UI journey now creates a person and two dated notes, edits closeness,
selectively deletes a note, and removes the person, checking actual rendered state
across process relaunches. All 44 native tests (nine UI) and unsigned Release pass.
[Original screenshots and scoped receipt](docs/qualification/2026-09-09/README.md)
retain the evidence. No product defect was reproduced; physical/account/iCloud and
distribution acceptance remain in issue 27. The installed build is unchanged.
