# Kith — PROJECT STATUS

Last updated: 2026-08-16

## Why / What

Kith is a private iPhone app for the people you actually want to stay close
to. They float as bubbles — closer people are larger — and each person has a
dated log of the things that matter: hangouts, calls, gifts, milestones, and
the small facts that make someone feel known.

In scope: adding people, setting closeness and circle, a floating
constellation home, a searchable list, standing notes, and a chronological
log per person.

Out of scope: accounts, cloud sync, contact-book import, social graphs,
reminders as a notification product, messaging, and a web client.

## Dependencies

### External

- SwiftUI on iOS 17+
- XcodeGen to generate the Xcode project
- XCTest for domain, persistence, and interface coverage

### Internal

- None. Kith does not call Fleet services.

## Timeline

- 2026-08-16 — first device-first constellation: local people and logs, warm
  floating bubbles sized by closeness, person pages, and a searchable list

## Products

- Native iPhone app `com.significanthobbies.kith` (local binary, not in the
  App Store yet)

## Features (shipped)

- Local JSON document for people and dated log entries
- Constellation of floating bubbles sized by explicit closeness
- Person profile: circle, closeness, how you met, standing notes, birthday
- Per-person log kinds: note, hangout, call, message, gift, milestone, remember
- Searchable list fallback and reduced-motion static layout
- Empty state and a `--ui-demo` fixture for tests and screenshots

## Work queue

https://github.com/Significant-Hobbies/kith/issues
