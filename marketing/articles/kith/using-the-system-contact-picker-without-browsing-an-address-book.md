---
title: "Using the system contact picker without browsing an address book"
slug: "using-the-system-contact-picker-without-browsing-an-address-book"
target_query: "ios contact picker without permission"
search_intent: "Technical and product approach for importing people on iOS without requesting address book access."
meta_title: "Using the iOS Contact Picker Without Browsing the Address Book"
meta_description: "How Kith uses the iOS system contact picker to selectively import people without requesting full address book permissions."
---

## Outline
1. **The cost of full access**: The privacy and product friction of requesting the entire address book.
2. **Why Kith rejects the address book**: Building for closeness rather than bulk lists.
3. **The iOS system multi-select picker**: Using out-of-process UI to preserve privacy.
4. **Mapping selections to local data**: Handling names, yearless birthdays, and contact details.
5. **How contact selection works in practice**: Concrete examples of single and batch imports.
6. **Internal-link suggestions**: Context for related architecture and product positioning.
7. **Practical next action**: Evaluating picker adoption for iOS applications.
8. **Source notes**: Internal repository verification for product claims.

## The cost of full access

When software involves other people, getting those people into the application is a primary challenge. For years, the default method on iOS has been requesting blanket access to the address book. The application prompts the user, asking for permission to read their contacts. If granted, the application ingests the entire database—coworkers, extended family, acquaintances, and service businesses.

This approach creates friction. People are hesitant to hand over their entire network to a third-party application. A full address book contains private information about other people who never consented to having their data read. Presenting an entire address book inside a new application also dilutes the application's purpose. If the software is designed for a specific subset of relationships, importing hundreds of irrelevant records clutters the interface and creates a burdensome clean-up task.

For developers, requesting this access means adding a usage description to the application configuration, justifying the data access, and handling the complex state of denied, restricted, or granted permissions. Storing or processing a full address book requires stringent data protection and complicates compliance with evolving privacy regulations across different regions.

Modern iOS provides system-level interfaces allowing users to select specific pieces of data to share without giving the application broad access to the underlying database. By using these system pickers, applications receive exactly what the user explicitly chooses to share, preserving trust and simplifying the codebase.

## Why Kith rejects the address book

To understand why avoiding full address book access is necessary, consider Kith. Kith is a private iOS application designed to help people remember the individuals in their lives. It is explicitly not a CRM, not a contact book, and not a social network.

Kith's core proposition is "The people you keep close." It is built for a small, private constellation of relationships. Users open the app, see a floating constellation of bubbles—where size represents an explicit closeness from 1 to 5—tap someone, and write down a short note. The repeated action is opening someone, writing a short note, and leaving.

Because Kith is a log of people, treating the address book as a bulk import source violates the product structure. An address book is a utility holding the local pharmacy and former colleagues. Kith is for relationships that matter. Browsing or storing the entire contact book is out of scope. Kith does not score closeness based on recency or log volume; closeness is explicitly set by the user.

Asking for permission to read the entire address book would suggest Kith views relationships as bulk data to be mined. Instead, Kith requires an approach where the user remains in complete control, carefully bringing in only the individuals they explicitly choose. This aligns with the brand commitments of being a warm, personal log.

## The iOS system multi-select picker

To avoid manual data entry while keeping the user in control, Kith uses the system multi-select contact picker provided by iOS. This is an out-of-process user interface managed directly by the operating system.

When a user decides to add people from their existing contacts, Kith presents the system picker. Because the picker runs out-of-process, Kith cannot see what the user is browsing. The application does not have access to search queries, the list of names, or any contact details on the screen. The operating system handles the selection safely isolated from the host application.

Consequently, Kith does not need to request contacts permission. There is no system alert prompting the user to allow access to the address book, and there is no need for a contacts usage description. Privacy is preserved by default, eliminating onboarding friction.

When the user selects one or more contacts and confirms their choice, the operating system securely hands only the selected records back to Kith. This explicit action serves as authorization. The broader address book remains completely private and untouched.

## Mapping selections to local data

Receiving data from the system picker is only the first step. The application must map that data into its own domain models. Kith's mapping is intentionally constrained to ensure the application remains a personal log rather than a duplicate address book.

When the system multi-select picker shares the chosen records, Kith extracts a specific subset of information: the person's name, their birthday, and their first phone number or email address.

The handling of birthdays supports the iOS contact framework's allowance for dates without years. Kith specifically supports these yearless values, rendering them appropriately so the application can log an upcoming birthday without requiring the exact year of birth.

The first phone number or email address is mapped into the person's "standing notes." Standing notes in Kith are a free-text area meant for persistent facts about a person. By placing the contact detail here, Kith avoids becoming a communication utility. The application does not wire up messaging actions; it simply retains the information as a useful, static fact.

During import, Kith applies sensible defaults. It skips existing or empty names to prevent phantom records. Selected people are initialized with standard defaults, such as an assigned circle.

Crucially, this batch of new people is committed in one atomic local save. Kith operates on a device-first architecture where all people and logs live in one local JSON document. If the user opts into the optional Significant Hobbies Hub synchronization, the batch is enqueued and synced with a single Hub sync request.

## How contact selection works in practice

To illustrate how this system operates smoothly in practice, consider two common scenarios.

### Example 1: Adding a close friend

Imagine a user wants to add their best friend, Alex, to Kith. Instead of typing Alex's name and birthday manually, the user taps the option to add from contacts. The system contact picker slides up. The user searches for "Alex", selects the contact card, and taps "Done."

The iOS system passes the single selected record to Kith. Kith extracts the name "Alex", maps a yearless birthday seamlessly, and takes Alex's primary phone number, placing it into the standing notes. A new person record is created locally. When the user returns home, a new bubble for Alex floats in the constellation. The user can then tap Alex's bubble, set their closeness to a 5, and write a short log entry.

### Example 2: Batch importing family members

A user decides to add their immediate family to Kith. They open the system picker, scroll through contacts, and select four relevant family members. They ignore irrelevant contacts visible on the screen.

Upon confirmation, the system hands the four records to Kith. Kith processes the batch locally. It discovers one selected contact has an empty name field and skips this invalid record. For the remaining three, it extracts names, birthdays, and the first available email or phone number.

The application groups these three new people and performs a single atomic save to the local JSON document. The family members immediately appear in the searchable list and the constellation, leaving the rest of the address book unread.

## Internal-link suggestions

When integrating this article, consider the following internal links to provide a cohesive reading experience:

*   **Link to device-first architecture:** When discussing the local JSON document, link to technical documentation detailing Kith's offline-first capabilities and atomic saving mechanisms.
*   **Link to product positioning:** When discussing why Kith is not a CRM, link to the core product philosophy page detailing the explicit closeness metric.
*   **Link to Hub synchronization:** When mentioning the single Hub sync request, link to the documentation explaining the optional Sign in with Apple synchronization.

## Practical next action

For developers evaluating how to handle contacts, audit your current implementation. Does the application genuinely need to browse or store the entire address book to function?

If the application's goal is allowing users to select specific individuals, replace `CNContactStore` authorization requests with a system picker like `CNContactPickerViewController` or its SwiftUI equivalents. Update onboarding flows to present the picker exactly when the user intends to add a person. By adopting this approach, you remove friction, build trust, and vastly simplify privacy and compliance requirements.

## Source notes

> **Note for reviewers: This section is for internal verification only and should be removed prior to publication.**
>
> The claims in this draft are supported by repository files:
>
> *   **`PRODUCT.md`**: Confirms the application is "not a CRM, not a contact book". It specifies: "People can be added by hand or chosen from device contacts through the system picker — picked contacts share name, birthday, and first phone/email. Kith never browses the contact book." It details the "one local JSON document" architecture.
> *   **`PROJECT_STATUS.md`**: Validates the technical implementation under issue 28: "added optional contact import through the system multi-select picker... Picking shares only the chosen records, so no contacts permission or usage description is needed." It supports mapping details: "Each pick maps name, birthday (yearless values render without a year), and first phone/email into standing notes... existing or empty names are skipped, and the batch commits in one atomic local save with a single Hub sync request."
> *   **`AGENTS.md`**: Supports tone and terminology: "Speak about people, closeness, and notes — never contacts, CRM, pipelines, or leads."
>
> **Important Limitations to observe:**
> *   The application explicitly does not support a social graph or messaging capabilities (`PROJECT_STATUS.md`).
> *   Synchronization is entirely optional and heavily favors the local JSON document (`PRODUCT.md`, `PROJECT_STATUS.md`). Network access must not block local use.