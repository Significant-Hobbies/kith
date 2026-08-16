import Foundation

public enum KithError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case missingPerson
    case emptyName
}

public enum CircleKind: String, Codable, CaseIterable, Sendable {
    case family
    case close
    case friends
    case work
    case other

    public var title: String {
        switch self {
        case .family: "Family"
        case .close: "Close"
        case .friends: "Friends"
        case .work: "Work"
        case .other: "Other"
        }
    }
}

public enum LogKind: String, Codable, CaseIterable, Sendable {
    case note
    case hangout
    case call
    case message
    case gift
    case milestone
    case remember

    public var title: String {
        switch self {
        case .note: "Note"
        case .hangout: "Hangout"
        case .call: "Call"
        case .message: "Message"
        case .gift: "Gift"
        case .milestone: "Milestone"
        case .remember: "Remember"
        }
    }

    public var symbolName: String {
        switch self {
        case .note: "text.alignleft"
        case .hangout: "cup.and.saucer.fill"
        case .call: "phone.fill"
        case .message: "bubble.left.fill"
        case .gift: "gift.fill"
        case .milestone: "sparkles"
        case .remember: "bookmark.fill"
        }
    }
}

public enum PersonHue: String, Codable, CaseIterable, Sendable {
    case clay
    case apricot
    case honey
    case rose
    case rust
    case sand
    case sage

    public static func assigned(for id: UUID) -> PersonHue {
        let options = PersonHue.allCases
        let index = abs(id.uuidString.hashValue) % options.count
        return options[index]
    }
}

public struct Person: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var howWeMet: String
    public var circle: CircleKind
    public var closeness: Int
    public var hue: PersonHue
    public var birthday: Date?
    public var standingNotes: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        howWeMet: String = "",
        circle: CircleKind = .friends,
        closeness: Int = 3,
        hue: PersonHue? = nil,
        birthday: Date? = nil,
        standingNotes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.howWeMet = howWeMet
        self.circle = circle
        self.closeness = Self.clampCloseness(closeness)
        self.hue = hue ?? .assigned(for: id)
        self.birthday = birthday
        self.standingNotes = standingNotes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    public var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        let letters = parts.compactMap(\.first)
        let value = String(letters).uppercased()
        return value.isEmpty ? "?" : value
    }

    public static func clampCloseness(_ value: Int) -> Int {
        min(5, max(1, value))
    }

    /// Diameter in points for the constellation lantern.
    public static func lanternDiameter(closeness: Int) -> Double {
        switch clampCloseness(closeness) {
        case 1: 64
        case 2: 80
        case 3: 100
        case 4: 124
        default: 152
        }
    }

    public var lanternDiameter: Double {
        Self.lanternDiameter(closeness: closeness)
    }
}

public struct Entry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var personID: UUID
    public var kind: LogKind
    public var happenedOn: Date
    public var body: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        personID: UUID,
        kind: LogKind,
        happenedOn: Date,
        body: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.personID = personID
        self.kind = kind
        self.happenedOn = happenedOn
        self.body = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.createdAt = createdAt
    }
}

public struct KithDocument: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var people: [Person]
    public var entries: [Entry]
    public var savedAt: Date

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case people
        case entries
        case savedAt
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        people: [Person] = [],
        entries: [Entry] = [],
        savedAt: Date = .distantPast
    ) {
        self.schemaVersion = schemaVersion
        self.people = people
        self.entries = entries
        self.savedAt = savedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        people = try container.decode([Person].self, forKey: .people)
        entries = try container.decode([Entry].self, forKey: .entries)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .distantPast
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(people, forKey: .people)
        try container.encode(entries, forKey: .entries)
        try container.encode(savedAt, forKey: .savedAt)
    }

    /// Newer document wins. Used when the phone and personal iCloud disagree.
    public static func newer(_ lhs: KithDocument, _ rhs: KithDocument) -> KithDocument {
        lhs.savedAt >= rhs.savedAt ? lhs : rhs
    }

    public mutating func markSaved(at date: Date = Date()) {
        savedAt = date
    }

    public static var empty: KithDocument { KithDocument() }

    public func person(id: UUID) -> Person? {
        people.first { $0.id == id }
    }

    public func entries(for personID: UUID) -> [Entry] {
        entries
            .filter { $0.personID == personID }
            .sorted { lhs, rhs in
                if lhs.happenedOn != rhs.happenedOn { return lhs.happenedOn > rhs.happenedOn }
                return lhs.createdAt > rhs.createdAt
            }
    }

    public func lastContact(for personID: UUID) -> Date? {
        entries(for: personID).first?.happenedOn
    }

    public mutating func upsert(_ person: Person) throws {
        let name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw KithError.emptyName }
        var saved = person
        saved.name = name
        saved.closeness = Person.clampCloseness(person.closeness)
        saved.updatedAt = Date()
        if let index = people.firstIndex(where: { $0.id == saved.id }) {
            saved.createdAt = people[index].createdAt
            people[index] = saved
        } else {
            people.append(saved)
        }
        markSaved()
        sortPeople()
    }

    public mutating func removePerson(id: UUID) {
        people.removeAll { $0.id == id }
        entries.removeAll { $0.personID == id }
        markSaved()
    }

    public mutating func add(_ entry: Entry) throws {
        guard people.contains(where: { $0.id == entry.personID }) else {
            throw KithError.missingPerson
        }
        entries.append(entry)
        markSaved()
    }

    public mutating func removeEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        markSaved()
    }

    public func matchingPeople(query: String) -> [Person] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return people }
        return people.filter { person in
            person.name.localizedCaseInsensitiveContains(needle)
                || person.howWeMet.localizedCaseInsensitiveContains(needle)
                || person.standingNotes.localizedCaseInsensitiveContains(needle)
                || person.circle.title.localizedCaseInsensitiveContains(needle)
        }
    }

    private mutating func sortPeople() {
        people.sort { lhs, rhs in
            if lhs.closeness != rhs.closeness { return lhs.closeness > rhs.closeness }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
