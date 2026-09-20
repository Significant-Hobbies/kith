---
title: Designing a relationship constellation without social scoring
slug: designing-a-relationship-constellation-without-social-scoring
target query: relationship tracker without social scoring
search intent: Informational / Conceptual
meta title: Designing a Relationship Constellation Without Social Scoring | Kith
meta description: How Kith uses a floating constellation and explicit closeness—not algorithms or automated social scoring—to help you remember the people who matter.
---

## Outline

1. **The Problem with Social Scoring**: Why applying automated metrics to relationships fails.
2. **The Constellation Concept**: A visual layout using floating bubbles sized by explicit closeness.
3. **Rejecting Algorithmic Inference**: Relying entirely on user-defined closeness rather than calculating it.
4. **Designing for Quiet Moments**: Crafting an interface for brief use after a hangout or call.
5. **Structuring Memory**: Balancing chronological logs (gifts, milestones, hangouts) with labelled details.
6. **Escaping the Address Book**: Why importing contacts must be an explicit, selective act.
7. **Privacy as a Primitive**: Storing the constellation in a local JSON document first.
8. **Practical Next Action**: Start your constellation.

---

## The Problem with Social Scoring

Software design frequently borrows paradigms from Customer Relationship Management (CRM). These tools, built around pipelines and touchpoints, introduce coldness when applied to personal friendships. Treating people like a pipeline turns relationships into a checklist of obligations.

Many modern personal tools attempt to automate relationship management through social scoring. They analyze how frequently you message someone or the recency of your last call to output an algorithmic "relationship health" score. This approach fundamentally misunderstands human connection. A sibling you speak to once a month might be your closest relationship, while a colleague you interact with daily belongs in a different sphere. Automated social scoring reduces nuanced dynamics to mathematical formulas, rewarding frequency over substance. Designing a system that respects human connection requires explicitly rejecting CRM paradigms and algorithmic inference. A personal log of people should feel like a private space, not a dashboard for managing metrics.

## The Constellation Concept

Instead of a rigid alphabetical list, a relationship log can reflect the organic nature of human connection. In Kith, the primary home surface is designed as a floating constellation of people.

This constellation uses a visual metaphor to represent your personal network. People you add float as warm bubbles. The size of each bubble correlates directly with the closeness of the relationship. By abstracting relationships into a spatial format, the interface provides an immediate overview. When you open the application, you see a map of the people who matter to you, scaled by their importance rather than alphabetical order or interaction recency.

While a searchable list is maintained as a fallback for quick lookup and VoiceOver, the constellation is the primary mode of interaction. It sets the tone: this is a warm, personal log, not a corporate contact manager.

## Rejecting Algorithmic Inference

The core mechanic behind the constellation is closeness. In Kith, closeness is an explicit value set by the user on a simple scale from 1 to 5. Crucially, the system makes no attempt to calculate this value. Bubble size on the constellation is driven by this explicit closeness only. It is not inferred from the volume of log entries, the recency of your last contact, or the "circle" (family, close, friends, work, other) to which they belong.

This manual assignment empowers the user. If you have a childhood friend you rarely see but consider deeply important, you can set their closeness to a 5. Their bubble will remain prominent, reflecting their actual importance, regardless of how few notes you have logged recently. A frequent work contact might be a 2, remaining smaller despite a high volume of logs. By refusing to infer relationship strength, the design avoids the trap of social scoring and trusts the user to know their own relationships.

## Designing for Quiet Moments

The context in which a relationship log is used heavily influences its design. This is a mobile-first experience, typically used on an iPhone, often one-handed, in the quiet moments that follow an interaction.

Consider the concrete scenario: you have just finished dinner with a friend. The goal is to quickly capture a few details—a new job or an upcoming trip—before the moment fades. In these scenarios, users have little patience for complex forms. The repeated action must be frictionless: "open someone, write a short note, leave." Success is measured by the ability to complete this loop in under a minute. This constraint shapes the interface, stripping away friction to focus entirely on the speed of capture.

## Structuring Memory Without Rigidity

While capture must be fast, the information stored must remain useful. Finding the balance between unstructured text and rigid database fields is a common challenge.

Kith structures a person's profile to capture the essence of the relationship without overwhelming the user. A person has a name, a circle classification, an explicit closeness value, and an optional birthday. Beyond these, the system provides flexible structures:
*   **How you met**: A simple narrative context.
*   **Labelled detail pairs**: Seeded with common contexts like relationship, where they are, where they work, and last contact.
*   **Free-text list**: For unstructured information.
*   **Standing notes**: General, enduring observations.

The core of the interaction memory is the chronological log. Each person has a history of entries, categorized by kind: note, hangout, call, message, gift, milestone, or remember. Each entry has a date and a short body. This structure allows the user to record a `hangout` on a specific date and briefly note what was discussed, or log a `gift` idea they want to `remember`. It provides just enough structure without forcing the user to fill out a comprehensive dossier.

## Escaping the Address Book

A significant distinction between a relationship constellation and a standard contact manager lies in how data is acquired. The default behavior for many apps is to request full access to the device's contact book, ingesting hundreds of records indiscriminately.

A relationship log is not meant to house every plumber or former colleague. It is for an intentional selection of people. To enforce this, Kith never browses the system contact book in the background. Adding people is intentional. When users choose to import contacts to save typing, they use the system's native multi-select picker. This picker runs out of process, meaning the app only receives the records explicitly tapped. No broad "contacts permission" is required.

Furthermore, the import is selective. A chosen contact maps only its name, birthday (with yearless values supported), and first phone/email into the person's standing notes. It does not pull in addresses or social profiles, reinforcing that you are curating a constellation, not an exhaustive directory.

## Privacy as a Primitive

When software deals with personal relationships, the data architecture must prioritize privacy. A cloud-first approach introduces unnecessary risk.

Kith adopts a device-first philosophy. Everything is stored primarily in a single local JSON document on the iPhone. This provides several benefits:
*   **Offline First**: The app is usable without a network connection. You can add people and log notes while on an airplane without encountering sync errors.
*   **Data Ownership**: The record of your relationships lives on your device, not in a corporate database.

Synchronization is treated as an optional enhancement. While a private CloudKit mirror exists for continuity, and a Hub synchronization is available via Sign in with Apple, neither is required. Crucially, the local document remains authoritative. When optional Hub sync is enabled, downloaded records commit to the local document before the sync cursor advances, ensuring failed saves can be retried safely. A network failure never blocks local use.

## Conclusion

Designing software for human connection requires stepping away from enterprise metrics. By replacing algorithmic social scoring with explicit choices, and rigid pipelines with a warm constellation, we can build tools that respect real relationships. A relationship log should be a quiet, private place to remember the people who matter. It should prioritize the intimacy of the data above all else. When you strip away automated scoring, you are left with a tool that helps you stay close to the people you choose.

## Practical Next Action

Think of five people outside your immediate household who you genuinely want to stay close to. Add them to your system, explicitly assign a closeness value that feels right to you, and jot down one detail you want to remember from your last interaction.

## Internal-link suggestions

*   **[Designing the local JSON document for privacy]**: Link from the "Privacy as a Primitive" section to an article discussing the device-first architecture.
*   **[Handling partial dates in birthday logs]**: Link from the "Structuring Memory Without Rigidity" section to a technical post on dealing with yearless dates.
*   **[Building the floating constellation in SwiftUI]**: Link from the "The Constellation Concept" section to a tutorial detailing the SwiftUI implementation of the bubble interface.

---

## Source Notes

**Evidence supporting product claims:**
*   **Closeness & Bubble Size**: `PRODUCT.md` states, "Bubble size on the constellation is closeness only." and "Closeness is an explicit 1–5 value the person sets."
*   **Rejection of Scoring/CRM**: `AGENTS.md` and `PRODUCT.md` emphasize, "Speak about people, closeness, and notes — never contacts, CRM, pipelines, or leads." and "Closeness is something you set, not something the app scores." `AGENTS.md` notes: "Do not infer it from recency, log volume, or circle."
*   **Device-First Architecture**: `AGENTS.md` states, "People and logs live in one local JSON document." and "Do not make network access block local use".
*   **Profile Structure**: `PRODUCT.md` lists the fields: circle, explicit closeness (1-5), optional birthday, how you met, standing notes, labelled detail pairs (relationship / where they are / where they work / last contact), a free-text list, and a hue.
*   **Log Kinds**: `PROJECT_STATUS.md` lists log kinds: note, hangout, call, message, gift, milestone, remember.
*   **Contact Import Constraints**: `PRODUCT.md` and `PROJECT_STATUS.md` state, "Kith never browses the contact book." and details the use of the system multi-select picker sharing only name, birthday, and first phone/email into notes without requiring contacts permission.
*   **Offline and Sync Behavior**: `README.md` and `PROJECT_STATUS.md` outline that local use does not wait for services, and that Hub downloads commit locally before acknowledging the cursor.

**Important limitations:**
*   **No Web Client or Messaging**: `PROJECT_STATUS.md` lists messaging and a web client as "Out of scope".
*   **No Social Graphs**: `PRODUCT.md` states Kith is "not a social network".
*   **Hub Sync is Optional**: `PRODUCT.md` states "Hub synchronization is optional and uses Sign in with Apple".
*   **Test Environment Only**: `README.md` notes that physical use, real-account synchronization, and public distribution remain unqualified as of the last status update.
