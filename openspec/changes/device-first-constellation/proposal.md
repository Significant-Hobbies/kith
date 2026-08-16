# Device-first constellation

## Why

Keeping people in mind is not a spreadsheet job. The owner wants a private
iPhone surface where the people they add are visible as floating bubbles —
closer relationships larger — and each person has a dated log of the things
that actually happened.

## What

- Add, edit, and remove people with name, circle, closeness, hue, optional
  birthday, how you met, and standing notes.
- A constellation home: drifting lanterns sized by closeness.
- A searchable list fallback and a frozen layout when Reduce Motion is on.
- Per-person chronological logs with kind, date, and body.
- One local JSON document. No account. No network.

## Out

- Contact import, iCloud, notifications, photos, messaging, a web client,
  scoring closeness from activity.

## How

SwiftUI app + `KithCore` document/store, XcodeGen project, XCTest for the
document and the main add-person / add-log path.
