---
title: "Making a visual relationship map accessible as a searchable list"
slug: "making-a-visual-relationship-map-accessible-as-a-searchable-list"
target_query: "accessible visual relationship map list"
search_intent: "informational"
meta_title: "Making Visual Relationship Maps Accessible With Searchable Lists"
meta_description: "Explore how visual relationship interfaces can be made accessible. Learn how Kith pairs a floating visual constellation with a searchable list for screen readers and quick access."
---

# Making a visual relationship map accessible as a searchable list

## Outline
1. **Introduction:** Balancing a warm visual map with accessibility and speed.
2. **The Visual Constellation:** Kith's floating lanterns and explicit closeness.
3. **The Accessibility Challenge:** Navigating a non-linear field with VoiceOver.
4. **The Searchable List Alternative:** A linear list as a core interface.
5. **Translating Visuals to Semantics:** Converting visual cues to text (name, closeness, circle).
6. **Designing for Speed and Reduced Motion:** Addressing cognitive load and respecting system settings.
7. **Implementation and Data Consistency:** Keeping both views in sync with a single JSON document.
8. **Practical Next Action & Internal Links:** Designing accessible interfaces and further reading.

## Introduction

In modern software design, there is often a tension between creating an interface that feels organic and one that remains structurally accessible. When designing an environment for keeping track of the people in our lives, traditional business-oriented layouts miss the mark. A personal space should feel personal, reflecting the nuances of relationships rather than treating human beings as data in a tool.

To achieve this, Kith was designed with a primary interface that feels like a quiet room of lanterns: a drifting constellation of soft circles on a linen paper background. This visual map is intuitive for sighted users, instantly conveying who is closest by the physical size of their representative bubble. However, an entirely visual, non-linear interface presents accessibility challenges. For users relying on screen readers like VoiceOver, or for anyone who needs to find a specific person quickly, a drifting two-dimensional field can be frustrating.

This article explores how we resolved this tension by pairing a visual relationship map with a fully accessible, searchable list. By treating both interfaces as core to the experience, we ensure that warmth and accessibility are not mutually exclusive.

## The Visual Constellation

The primary surface of Kith is the constellation, a floating field where each person is represented as a lantern. These lanterns are soft circles of clay, apricot, honey, and rose. They evoke the feeling of a paper mobile hanging in still air or a corkboard of overlapping Polaroids in warm light.

Relationships are quantified not by algorithmic inference, but by deliberate, explicit choice. Closeness is a user-defined value ranging from 1 to 5. We do not infer closeness based on recency of contact, log volume, or the specific circle a person belongs to. It is an intentional declaration. Visually, this closeness translates directly to the size of the lantern. The closer you are to someone, the larger their bubble appears, taking up more space in your visual field.

This spatial arrangement creates an emotional read of your social landscape. It is a calm representation of the people you keep close. When you open the app, you are greeted by this map, allowing you to quickly spot a close friend, tap their lantern, and begin writing a note. Yet, this design inherently prioritizes sighted users comfortable navigating an unstructured spatial layout.

## The Accessibility Challenge of 2D Space

While the constellation provides a beautiful sense of one's relationships, non-linear interfaces are difficult to navigate using assistive technologies. Screen readers rely on a linear hierarchy to present information sequentially. A scattered arrangement of bubbles lacks a predictable reading order.

Furthermore, relying on visual cues—like the size of a bubble to indicate closeness, or a specific hue like sage to denote a work circle—creates barriers for visually impaired users. If status is conveyed through color or size alone, that information is lost to someone who cannot perceive those attributes.

There is also the challenge of speed. As the number of people grows, visually scanning a drifting map to find one person becomes inefficient. The operating context of Kith is often a quiet moment after a call or dinner—a one-handed interaction where the goal is to write a short note and leave the app in under a minute. If finding a person takes too long, the design fails.

## The Searchable List as a Core Alternative

To address these challenges, we implemented a searchable list as a fallback and a co-equal surface to the visual constellation. This list is not hidden in a settings menu; it is an immediate alternative designed specifically for finding someone quickly and ensuring VoiceOver compatibility.

The searchable list imposes order on the organic space. It presents people in a predictable, alphabetical, or closeness-sorted linear format. When a user is in a hurry, they can bypass the spatial map, pull down the search bar, type a few letters of a name, and instantly access the person's profile to log a hangout, call, or standing note.

For screen reader users, the list is the definitive navigation tool. It provides a structured hierarchy where each row represents a person. By swiping through the list, a VoiceOver user can hear the names of the people they have added, clearly delineated. This dual-surface approach means we do not compromise the aesthetic warmth of the floating lanterns to achieve accessibility.

## Translating Visuals to Semantics

A critical piece of making the visual relationship map accessible is ensuring that all visual information is accurately translated into semantic data for the list and screen readers. In Kith, focus and VoiceOver rely entirely on explicit text, never on color or size alone.

When navigating the list, semantic labels are carefully constructed. Instead of reading a name, VoiceOver will read the name, the explicit closeness rating (1 through 5), and the assigned circle (e.g., family, close, friends, work, other).

If a lantern is colored sage to indicate a work relationship and sized large to indicate a closeness of 4, the screen reader does not describe a large sage bubble. Instead, it reads: "Alex, Work circle, Closeness 4." This ensures complete parity of information. The visual design system dictates that color never carries status alone; this constraint ensures that our data models always contain the explicit strings and values needed to describe the relationship to any user.

## Designing for Speed and Reduced Motion

Accessibility also encompasses cognitive load and motion sensitivity. The constellation features a slow drift, mimicking objects settling in space. While intended to be calming, continuous animation can be physically uncomfortable for users with vestibular disorders.

Kith integrates with iOS accessibility settings. When a user has enabled Reduce Motion, the app responds by freezing the layout in place. The reduced-motion static layout preserves the spatial arrangement and size variations but removes the drift. This ensures the visual map remains comfortable for a wider audience.

Moreover, the combination of the static layout option and the searchable list directly supports the product's core proposition: speed. The repeated action in Kith is to open a person, write a short note, and leave. By providing a list with search, we eliminate the cognitive load of visually scanning the map when the user knows exactly who they are looking for. They type, tap, log the note, and are done in seconds.

## Implementation and Data Consistency

Maintaining two distinct ways of viewing the same relationships requires a robust data structure. Kith operates as a device-first application, where all people and logs live in one local JSON document. This local document is the single source of truth for both the constellation and the searchable list.

When a user modifies a person's closeness from 3 to 5 within their profile page, the underlying JSON document is updated in an atomic local save. Because both the map and the list observe this same local store, the visual bubble immediately grows larger, and the text in the VoiceOver label updates simultaneously.

By avoiding complex network blocking—the local document remains usable offline, with iCloud and Hub synchronization happening optionally in the background—we guarantee that the interfaces are never left waiting for a server round-trip. This ensures that the searchable list is always as up-to-date and reliable as the visual map.

## Practical Next Action

If you are building an application with a spatial visual interface, evaluate your primary use cases to identify where a linear alternative might improve the experience. Consider implementing a searchable list alongside your visual view. Ensure that any information conveyed purely through visual attributes has a direct, explicit semantic equivalent in your data model, ready to be spoken by screen readers. Start by auditing your UI for reliance on color alone and add text labels or alternative views where necessary.

## Internal Link Suggestions

*   **Exploring Our Design System:** Read more about our visual language, including our use of linen, cream, and clay palettes. *(Link to an article on Kith's UI design philosophy)*
*   **The Anatomy of a Note:** Discover how logging chronological events—like hangouts, calls, and gifts—helps maintain a meaningful log. *(Link to an article on logging interactions in Kith)*
*   **Privacy First Data Storage:** Understand why Kith uses a single local JSON document for immediate access to your data. *(Link to an article on local-first architecture)*

## Source Notes

> **Reviewer Only – Do Not Publish:** The following notes connect the claims made in this draft to the canonical repository documentation.
>
> *   **Visual Constellation & Accessibility:** The `DESIGN.md` file explicitly states the direction as a "quiet room of lanterns," specifying colors like clay, apricot, and sage. It strictly mandates: "Color never carries status alone" and "Focus and VoiceOver use names, closeness, and circle — never color alone."
> *   **Searchable List Fallback:** `PRODUCT.md` and `PROJECT_STATUS.md` both confirm the dual interfaces. `PRODUCT.md` notes: "A list with search exists for finding someone quickly and for VoiceOver." `PROJECT_STATUS.md` under Features lists: "Searchable list fallback and reduced-motion static layout."
> *   **Closeness:** Both `AGENTS.md` and `PRODUCT.md` define closeness as an "explicit 1-5 value the person sets" and explicitly forbid inferring it from recency or log volume.
> *   **Terminology:** As directed by `AGENTS.md`, the text consistently refers to "people," "closeness," and "notes," completely avoiding forbidden terms like "contacts," "CRM," "pipelines," or "leads."
> *   **Operating Context & Speed:** `PRODUCT.md` defines the success metric as: "Success is opening the app... and writing down what just happened — in under a minute."
> *   **Data Architecture:** `PRODUCT.md` and `PROJECT_STATUS.md` describe the single local JSON document as the immediate store, with optional CloudKit and Hub synchronization that does not block local use.
