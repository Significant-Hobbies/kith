# Kith — PROJECT STATUS

Last updated: 2026-09-08

## Why / What

Kith is a private iPhone app for the people you actually want to stay close
to. They float as bubbles — closer people are larger — and each person has a
dated log of the things that matter: hangouts, calls, gifts, milestones, and
the small facts that make someone feel known.

In scope: adding people, setting closeness and circle, a floating
constellation home, a searchable list, standing notes, and a chronological
log per person.

Out of scope: a mandatory Kith account, contact-book import, social graphs,
reminders as a notification product, messaging, and a web client.

## Dependencies

### External

- SwiftUI on iOS 17+
- Personal Apple Developer team `8F7LXHTJZR` (Sarthak Agrawal) and CloudKit
  container `iCloud.com.significanthobbies.kith`
- PersonalSyncKit from `Significant-Hobbies/significanthobbies` and the private
  Cloudflare Hub Worker
- XcodeGen to generate the Xcode project
- XCTest for domain, persistence, and interface coverage

### Internal

- Cloudflare Hub backend for optional semantic people and interaction
  synchronization. Significant Hobbies provides the shared browser sign-in
  handoff; local JSON remains the immediate store.

## Timeline

- 2026-09-08 — Build 12 prepares explicit Hub account ownership under issue 27
  and Hub issue 156. Approval persists with the local document before runtime
  binding or backfill. Another account cannot reassign the document, enqueue
  its records, or commit downloads into it. Shared source `118fc55` binds the
  durable queue and rejects stale identity/sync callbacks. Incompatible iCloud
  copies are kept separate and the mirror pauses with an explanation. Four
  new ownership tests cover restart, failed approval save/retry, reassignment
  refusal and mismatched cloud copies. The full local native unit/UI/Release
  gate passed. Hosted CI and physical account journeys remain pending;
  build 11 remains installed.

- 2026-09-08 — Build 11 prepares durable deletion recovery under issue 27.
  Regressions reproduced deleted people and notes returning from an old Hub
  download after restart. Deletion markers now commit in the same local
  document, recover failed outbox writes, prevent stale downloads from
  restoring records, and survive iCloud document selection and writes.
  Reconnect queues saved current state and retries deletion conflicts with
  updated versions. All 25 core/app tests pass with temporary data, and the
  full local native gate passes unit/UI tests and unsigned Release compilation.
  Hosted qualification is recorded in issue 27. Build 10 remains the verified
  installed phone app until those gates pass; actual signed-in use and public
  distribution remain unqualified.

- 2026-09-08 — Build 10 adopts PersonalSyncKit `e52fc1c` and commits downloaded
  people and notes before acknowledging the Hub cursor. A native integration
  regression injects a failed app write, retries the same download, reopens the
  saved person/note and verifies replay creates no duplicates. The full local
  native gate passed 19 unit tests, 8 UI tests and unsigned Release compilation.
  Build 8 remains the last verified phone installation. Physical signed-in use
  and distribution remain open in issue 27; shared consumer migration is
  tracked in Significant-Hobbies/significanthobbies#155.
- 2026-09-08 — Build 9 removes a network-dependent loading screen. Local people,
  notes and onboarding become available immediately after the file opens,
  before optional iCloud availability, account restoration and Hub sync finish.
  A suspended-iCloud regression failed on build-8 behavior and now verifies
  local editing, note creation and disk persistence while the network remains
  suspended. The full native check passed 18 unit tests, 8 UI tests and unsigned
  Release compilation. Build 9 is not yet installed or distributed; build 8
  remains the last verified phone installation. Physical use and signed-in sync
  remain in [issue 27](https://github.com/Significant-Hobbies/kith/issues/27).
- 2026-09-08 — Priority save-integrity repair prepared as build 8. The old
  person/note editors and onboarding treated an asynchronous file write as
  successful immediately. Regressions reproduced false saves and mutation
  after a failed document load. Local writes now serialize, publish only after
  an atomic save, and retain drafts/records on failure. Five focused regressions
  pass. The full native gate passed 9 core tests, 8 app tests, 8 UI tests and
  an unsigned Release build. Device installation and physical journeys remain in [issue 27](https://github.com/Significant-Hobbies/kith/issues/27).
- 2026-09-07 — Development build 7 installed on the owner's iPhone from
  source 916e876ede113ea1ba2eb13b56105502ca88bf68. Launch remains blocked by
  FBS Locked on 8 September. This is a development installation, not a
  TestFlight or physical-use qualification. Earlier TestFlight receipts below
  remain historical.

- 2026-08-23 — Removed the leftover `site/` landing fork. Its `wrangler.jsonc`
  declared Pages project `kith`, the project the `ios-landings` factory
  deploys, so a deploy from here would have replaced the live site. The live
  page is byte-identical to the factory build; the fork differed by 6 lines of
  inlined CSS reset — a stale copy of the same engine. README already called it
  leftover.

- 2026-08-23 — prepared Kith `1.0.0 (5)` from the merged truthful Hub-sync
  release. App Store Connect rejected a build-4 upload as a duplicate, proving
  build 4 already exists remotely even though the earlier repository note had
  not been reconciled. Build 5 is the next valid upload.

- 2026-08-23 — made the Significant Hobbies connection truthful: Kith now
  distinguishes account authentication from successful Hub synchronization,
  shows last success and durable waiting changes, explains local/iCloud/Hub
  roles, and gives different recovery guidance for expired sign-in, offline,
  and service failures. The change is verified in source and awaits its next
  TestFlight build.

- 2026-08-23 — bumped the app build number to `1.0.0 (4)` so the already-landed
  constellation onboarding could ship in its own unique internal TestFlight
  build. App Store Connect now confirms that build number has been used.

- 2026-08-22 — added first-run constellation onboarding through the real local
  person and log services: explicit closeness, one dated memory, resumable
  progress, existing-document bypass, optional continuation, and privacy/sync
  education only after local value.

- 2026-08-22 — Apple completed processing Kith 1.0.0 (3) on personal team
  `8F7LXHTJZR`. The valid build is assigned to the owner in the internal
  `Personal Testing` group with automatic distribution.

- 2026-08-21 — Hub-enabled Kith 1.0.0 (2) completed
  internal-only TestFlight processing on personal team `8F7LXHTJZR` after the
  browser handoff replaced bundle-specific native Apple identity.
- 2026-08-21 — added optional Sign in with Apple synchronization for people
  and interactions through the Hub. Local JSON remains immediate and
  offline-capable; the CloudKit mirror stays enabled as migration rollback.
- 2026-08-21 — created the personal-team App Store Connect record as
  `Kith by Significant Hobbies` (ID `6803666674`) and uploaded iPhone build
  `1.0.0 (1)` for internal-only TestFlight; Apple accepted the package for
  processing after the application target was corrected to emit only the
  intended iPhone device family
- 2026-08-17 — public landing live at kith.significanthobbies.com from
  the ios-landings factory
- 2026-08-17 — added a public landing from the shared iOS template
  (Indulge page set, Kith tokens)
- 2026-08-16 — signed with the personal Apple team and mirrored the local
  document into that team's private iCloud container
- 2026-08-16 — first device-first constellation: local people and logs, warm
  floating bubbles sized by closeness, person pages, and a searchable list

## Products

- Native iPhone app `com.significanthobbies.kith`; Hub-enabled
  build `1.0.0 (3)` is available to the owner through the internal
  `Personal Testing` group on personal team `8F7LXHTJZR`. No App Store
  submission.
- Public landing at https://kith.significanthobbies.com (ios-landings,
  Cloudflare Pages project `kith`)

## Features (shipped)

- Local JSON document for people and dated log entries
- Constellation of floating bubbles sized by explicit closeness
- Person profile: circle, closeness, how you met, standing notes, birthday
- Per-person log kinds: note, hangout, call, message, gift, milestone, remember
- Searchable list fallback and reduced-motion static layout
- Empty state and a `--ui-demo` fixture for tests and screenshots
- Private CloudKit mirror on the personal team when iCloud is signed in
- Optional signed-in Hub synchronization for people and interactions,
  with a durable local outbox, foreground/manual sync, and no local-data import
- Truthful Hub connection state with last success, waiting-change count, and
  actionable authentication/network/service recovery
- Public factory landing at kith.significanthobbies.com

## Work queue

https://github.com/Significant-Hobbies/kith/issues
