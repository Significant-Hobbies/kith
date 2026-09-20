---
title: Optional synchronization for private people and notes
slug: optional-synchronization-for-private-people-and-notes
target query: private relationship tracker sync
search intent: Understand how to keep personal notes about people synced privately across devices without mandatory accounts or cloud surveillance.
meta title: Optional Synchronization for Private People and Notes in Kith
meta description: Learn how Kith keeps your notes about close people private and local-first, with completely optional Hub synchronization.
---

## Outline

1.  **Introduction**: The personal nature of keeping notes on the people we keep close, and why that demands a different approach to data.
2.  **The Local-First Foundation**: How Kith stores people, closeness, and logs immediately in a local JSON document on your device.
3.  **Why Synchronization Must Be a Choice**: The philosophy behind opt-in synchronization and avoiding mandatory cloud accounts.
4.  **How Optional Hub Synchronization Works**: A technical and practical look at using PersonalSyncKit and the Significant Hobbies Hub.
5.  **Concrete Use Cases**: Writing notes offline after a dinner, maintaining a private constellation without a network connection.
6.  **The Absence of Surveillance**: Explicit privacy commitments, zero third-party analytics, and the rejection of social graphs.
7.  **Next Action**: How to start using Kith locally today.
8.  **Source Notes (Non-Publishable)**: Repository evidence supporting these product claims.

## Introduction

There is a quiet, profound difference between managing a network and tending to the people you keep close. When you open your phone after a late-night phone call, a birthday dinner, or a chance encounter, the instinct to write down a small note—a shared joke, a fleeting detail, a milestone—is an intimate act. It is not about building a database; it is about extending your own memory to ensure the people in your life feel known and remembered.

Because this information is inherently personal, the software we use to record it must reflect that intimacy. It requires an environment that is warm, immediate, and, above all, private. The notes you keep about your family, your close friends, and the people in your circles belong to you. They do not belong to a platform or an analytics engine.

This principle forms the absolute core of how Kith approaches data. Kith is built on the belief that your constellation of people should be yours alone. Instead of forcing you into a mandatory cloud account before you can write a single note, Kith starts on your device. When it comes to keeping that data safe or moving it between your own devices, it treats synchronization not as a requirement, but as a strictly optional feature.

## The Local-First Foundation

To understand how Kith handles synchronization, it is necessary to understand how it operates without it. Kith is built as a device-first application for iOS. When you first open the app, you are not presented with a loading screen demanding an email address. You are presented with a quiet space, ready for you to add a person.

Every person you add, every closeness level you set (an explicit value from one to five), every standing note, and every chronological log entry is written immediately to a single local JSON document stored directly on your iPhone. Kith does not need the internet to function.

The local-first approach guarantees immediacy. The repeated action in Kith is designed to take less than a minute: open a person’s lantern in the floating constellation, write a short log entry about what just happened, and leave. By saving to a local JSON file first, the interaction is always instant.

This also provides an absolute baseline of privacy. If you never choose to enable synchronization, your data never leaves your device. You can build your entire constellation, define circles, record how you met people, and keep detailed logs of hangouts, calls, and gifts, all without ever sending a byte of that personal history to an external server.

## Why Synchronization Must Be a Choice

In many modern applications, cloud synchronization is a toll. You must create an account to use the software, and the software claims the right to host and process your data.

For a tool designed to hold your most private notes about the people you care about, this model is unacceptable. The decision to move data off your device should be a deliberate, informed choice made by the person using the app, not a default enforced by the developer.

Optional synchronization respects the user's agency. It acknowledges that there are valid reasons to want data synced, but it refuses to make those benefits contingent on surrendering local control.

By keeping synchronization optional, Kith ensures that the local document remains the source of truth. The app is fully featured without the cloud. You are not penalized for staying offline. The constellation of floating bubbles, the searchable list, the detailed person pages—all of this operates perfectly on the local JSON document. Synchronization acts as a mirror and a transport mechanism, not a mandatory host.

## How Optional Hub Synchronization Works

For those who do choose to sync their data, Kith offers an optional connection to the Significant Hobbies Hub. This system is designed to be private and secure, built on the principle of explicit ownership and authenticated authority.

If you decide you want your constellation backed up, you can sign in using Sign in with Apple. This provides a secure, privacy-preserving way to authenticate without exposing your email address unnecessarily.

Once authenticated, Kith uses a framework called PersonalSyncKit to communicate with the private Cloudflare Hub backend. The synchronization process does not block your ability to use the app. If you are offline, you can continue to add people, adjust their closeness, and write logs.

Kith maintains a durable local outbox. When you make a change, it is immediately saved to your local JSON document and queued in the outbox. As soon as a network connection is available, Kith silently processes this queue, synchronizing the semantic records of your people and interactions with the Hub.

Crucially, this connection is truthful. Kith clearly distinguishes between being authenticated and successfully synchronizing. The app shows you the time of the last successful sync and the count of any durable changes waiting in the outbox. It explains the distinct roles of the local document, your iCloud backup, and the Hub.

During the current transition period, a private CloudKit mirror also remains available on the personal team when iCloud is signed in. This acts as an additional layer of security and a rollback mechanism.

## Concrete Use Cases: Offline Notes and Immediacy

Imagine you have just left a dinner with a close friend. You are walking to your car, and you are in a concrete parking garage with absolutely no cellular reception.

During the dinner, your friend mentioned the specific name of a book they want to read, and a milestone they are hoping to achieve next month. You want to write this down so you can ask them about it later.

In a traditional cloud-dependent app, you might be met with a frozen screen as the app futilely tries to contact its server to load the person's profile. You might have to write the note in a generic text app and transfer it later.

With Kith, you open the app, and your constellation is immediately there, rendered from the local JSON document. You tap your friend's lantern, opening their cream-colored sheet. You tap to add a log entry, type in the book title and the milestone, and save it. The action is instantaneous. The note is safely stored in the local document and placed in the durable outbox.

Later, when your phone reconnects to your home Wi-Fi, PersonalSyncKit quietly processes the outbox in the background, synchronizing that note to the Hub (if you have opted in). You never had to think about the network; the app simply worked at the speed of your thought.

Because Kith is device-first, disabling synchronization does not delete your local data. You can simply sign out. The local JSON document remains untouched, and you can continue using the app exactly as before, just without the remote mirror.

## The Absence of Surveillance

In Kith, syncing your data to the Hub does not mean opening it up to third-party surveillance. Kith strictly prohibits the inclusion of any third-party analytics SDKs. There is no hidden code tracking which people you interact with most, how often you adjust a closeness level, or what words you use in your logs.

Furthermore, Kith completely rejects the concept of a social graph. The people in your constellation are isolated entities within your own private context. Kith does not look at your contact book to suggest connections, nor does it upload your device contacts to see who else is using the app. You can optionally use the system multi-select picker to bring in a name, a birthday, and a first phone number or email to populate standing notes, but this is a one-way, device-level interaction. Kith never browses your contact book, and it never builds a web of relationships between its users.

The Hub synchronization is entirely concerned with backing up your explicit, personal records: the name, the circle (family, close, friends, work, other), the closeness, the birthday, the notes on how you met, the custom detail pairs, and the chronological logs. It is a faithful mirror of your local document, designed for your benefit alone.

## Next Action

If you value the privacy of your personal relationships and the immediacy of a local-first application, you do not need to wait for a cloud account to get started. You can begin building your constellation entirely on your own device.

Take a few minutes today to open Kith and add two or three people you consider close. Set their closeness level. Write down one recent detail you want to remember—a favorite coffee order, an upcoming trip, or the date you last saw them. Experience the speed and quietness of a device-first application.

Later, if you decide you want the security of an off-device backup, you can explore the optional Hub synchronization. But until then, your people and your notes remain exactly where they belong: with you.

---

### Internal Link Suggestions
- *Link "adding a person"* to the feature guide on using the constellation and person pages.
- *Link "Sign in with Apple"* to the privacy policy detailing the Hub authentication process.
- *Link "system multi-select picker"* to the tutorial on safely importing details without granting full contact book access.

---

## Source Notes (Non-Publishable)

This section documents the repository evidence and constraints used to construct the claims in this article. It is for internal review only and must be removed before publication.

- **Local-first / JSON Document:** `PRODUCT.md` confirms "Everything is stored first in one local JSON document." and "The local document remains immediately usable offline." `PROJECT_STATUS.md` repeatedly references the local JSON document for people and dated log entries.
- **Optional Hub Synchronization:** `PRODUCT.md` states "The Hub synchronization is optional and uses Sign in with Apple". `PROJECT_STATUS.md` details "Optional signed-in Hub synchronization for people and interactions, with a durable local outbox".
- **CloudKit Mirror:** `PRODUCT.md` mentions "the existing personal-team CloudKit mirror remains available during transition."
- **No Third-Party Analytics:** `AGENTS.md` explicitly forbids adding a third-party analytics SDK.
- **No Contact Book Browsing/Social Graph:** `PRODUCT.md` explicitly states "Kith never browses the contact book" and "not a social network." `PROJECT_STATUS.md` lists "browsing or storing the contact book, social graphs" as out of scope. Import is done strictly via the system multi-select picker (issue 28).
- **Closeness:** `PRODUCT.md` describes closeness as "an explicit 1 to 5, an optional birthday, how you met". `AGENTS.md` dictates: "Closeness is an explicit 1–5 value the person sets. Do not infer it from recency, log volume, or circle."
- **Terminology:** `AGENTS.md` enforces the use of "people, closeness, and notes" and explicitly bans "contacts, CRM, pipelines, or leads."
- **Truthful Connection State:** `PROJECT_STATUS.md` (2026-08-23 entry) notes Kith "distinguishes account authentication from successful Hub synchronization, shows last success and durable waiting changes, explains local/iCloud/Hub roles, and gives different recovery guidance".
