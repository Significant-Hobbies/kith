# Kith — PROJECT STATUS

Last updated: 2026-08-21

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
- PersonalSyncKit from `Significant-Hobbies/personal-platform` and the private
  Cloudflare Personal Platform Worker
- XcodeGen to generate the Xcode project
- XCTest for domain, persistence, and interface coverage

### Internal

- Cloudflare Personal Platform for optional semantic people and interaction
  synchronization. Significant Hobbies provides the shared browser sign-in
  handoff; local JSON remains the immediate store.

## Timeline

- 2026-08-21 — Personal Platform-enabled Kith 1.0.0 (2) completed
  internal-only TestFlight processing on personal team `8F7LXHTJZR` after the
  browser handoff replaced bundle-specific native Apple identity.
- 2026-08-21 — added optional Sign in with Apple synchronization for people
  and interactions through Personal Platform. Local JSON remains immediate and
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

- Native iPhone app `com.significanthobbies.kith`; Personal Platform-enabled
  build `1.0.0 (2)` completed internal-only TestFlight processing on personal
  team `8F7LXHTJZR`. No App Store submission.
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
- Optional signed-in Cloudflare synchronization for people and interactions,
  with a durable local outbox, foreground/manual sync, and no local-data import
- Public factory landing at kith.significanthobbies.com

## Work queue

https://github.com/Significant-Hobbies/kith/issues
