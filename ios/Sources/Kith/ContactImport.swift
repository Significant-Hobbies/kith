import Contacts
import Foundation
import KithCore

/// Maps contacts chosen in the system picker onto new Kith people. The app
/// never reads the contact book; the picker supplies only the picked records.
enum ContactImport {
    /// Contacts often store a birthday without a year. The sentinel keeps the
    /// date honest on the person page, which hides the year when it appears.
    static let yearlessBirthdayYear = 2000

    struct Outcome: Equatable {
        var people: [Person] = []
        var skipped = 0
    }

    /// Plan one import batch: drop nameless contacts and names already in the
    /// constellation or picked twice in the same batch.
    static func plan(contacts: [CNContact], existing: [Person], now: Date = Date()) -> Outcome {
        var names = Set(existing.map { normalizedName($0.name) })
        var outcome = Outcome()
        for contact in contacts {
            guard let person = person(from: contact, now: now),
                  names.insert(normalizedName(person.name)).inserted else {
                outcome.skipped += 1
                continue
            }
            outcome.people.append(person)
        }
        return outcome
    }

    static func person(from contact: CNContact, now: Date = Date()) -> Person? {
        let name = displayName(for: contact)
        guard !normalizedName(name).isEmpty else { return nil }
        return Person(
            name: name,
            birthday: birthdayDate(for: contact),
            standingNotes: standingNotes(for: contact),
            details: details(for: contact),
            createdAt: now,
            updatedAt: now
        )
    }

    static func normalizedName(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func birthdayText(_ date: Date, calendar: Calendar = .current) -> String {
        if calendar.component(.year, from: date) == yearlessBirthdayYear {
            return date.formatted(.dateTime.month(.wide).day())
        }
        return date.formatted(.dateTime.month(.wide).day().year())
    }

    private static func displayName(for contact: CNContact) -> String {
        let formatted = CNContactFormatter.string(from: contact, style: .fullName)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !formatted.isEmpty { return formatted }
        if contact.contactType == .organization {
            return contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return [contact.givenName, contact.familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Only rows with real values; the editor seeds the remaining default keys.
    private static func details(for contact: CNContact) -> [PersonDetail] {
        var details: [PersonDetail] = []
        if contact.contactType != .organization {
            let work = contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !work.isEmpty {
                details.append(PersonDetail(key: Person.detailKeyWhereTheyWork, value: work))
            }
        }
        if let address = contact.postalAddresses.first?.value {
            let place = [address.city, address.state, address.country]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: ", ")
            if !place.isEmpty {
                details.append(PersonDetail(key: Person.detailKeyWhereTheyAre, value: place))
            }
        }
        return details
    }

    private static func birthdayDate(for contact: CNContact) -> Date? {
        guard let birthday = contact.birthday,
              let month = birthday.month, let day = birthday.day else { return nil }
        var components = DateComponents()
        components.year = birthday.year ?? yearlessBirthdayYear
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }

    private static func standingNotes(for contact: CNContact) -> String {
        var lines: [String] = []
        if let phone = contact.phoneNumbers.first?.value.stringValue, !phone.isEmpty {
            lines.append("Phone: \(phone)")
        }
        if let email = contact.emailAddresses.first?.value as String?, !email.isEmpty {
            lines.append("Email: \(email)")
        }
        return lines.joined(separator: "\n")
    }
}
