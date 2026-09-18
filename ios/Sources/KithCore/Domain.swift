import Foundation

public enum KithError: Error, Equatable, Sendable {
    case accountMismatch
    case unsupportedSchema(Int)
    case missingPerson
    case emptyName
    case deletedRecord
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

/// A labelled fact about a person, e.g. "Where they work" → "Agency".
public struct PersonDetail: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var key: String
    public var value: String

    public init(id: UUID = UUID(), key: String, value: String = "") {
        self.id = id
        self.key = key
        self.value = value
    }
}

/// One row in a person's free-text list.
public struct PersonListItem: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var text: String

    public init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
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
    public var details: [PersonDetail]
    public var listItems: [PersonListItem]
    public var createdAt: Date
    public var updatedAt: Date

    public static let detailKeyRelationship = "Relationship"
    public static let detailKeyWhereTheyAre = "Where they are"
    public static let detailKeyWhereTheyWork = "Where they work"
    public static let detailKeyLastContact = "Last contact"
    public static let defaultDetailKeys = [
        detailKeyRelationship, detailKeyWhereTheyAre,
        detailKeyWhereTheyWork, detailKeyLastContact,
    ]

    public init(
        id: UUID = UUID(),
        name: String,
        howWeMet: String = "",
        circle: CircleKind = .friends,
        closeness: Int = 3,
        hue: PersonHue? = nil,
        birthday: Date? = nil,
        standingNotes: String = "",
        details: [PersonDetail] = [],
        listItems: [PersonListItem] = [],
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
        self.details = details
        self.listItems = listItems
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case howWeMet
        case circle
        case closeness
        case hue
        case birthday
        case standingNotes
        case details
        case listItems
        case createdAt
        case updatedAt
    }

    /// Documents saved before details/listItems existed decode
    /// them as empty rather than failing the whole file open.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        howWeMet = try container.decodeIfPresent(String.self, forKey: .howWeMet) ?? ""
        circle = try container.decode(CircleKind.self, forKey: .circle)
        closeness = try container.decode(Int.self, forKey: .closeness)
        hue = try container.decode(PersonHue.self, forKey: .hue)
        birthday = try container.decodeIfPresent(Date.self, forKey: .birthday)
        standingNotes = try container.decodeIfPresent(String.self, forKey: .standingNotes) ?? ""
        details = try container.decodeIfPresent([PersonDetail].self, forKey: .details) ?? []
        listItems = try container.decodeIfPresent([PersonListItem].self, forKey: .listItems) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
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
    public var deletionDates: [UUID: Date]
    public var hubAccountID: String?

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case people
        case entries
        case savedAt
        case deletionDates
        case hubAccountID
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        people: [Person] = [],
        entries: [Entry] = [],
        savedAt: Date = .distantPast,
        deletionDates: [UUID: Date] = [:],
        hubAccountID: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.people = people
        self.entries = entries
        self.savedAt = savedAt
        self.deletionDates = deletionDates
        self.hubAccountID = hubAccountID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        people = try container.decode([Person].self, forKey: .people)
        entries = try container.decode([Entry].self, forKey: .entries)
        savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? .distantPast
        deletionDates = try container.decodeIfPresent([UUID: Date].self, forKey: .deletionDates) ?? [:]
        hubAccountID = try container.decodeIfPresent(String.self, forKey: .hubAccountID)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(people, forKey: .people)
        try container.encode(entries, forKey: .entries)
        try container.encode(savedAt, forKey: .savedAt)
        try container.encode(deletionDates, forKey: .deletionDates)
        try container.encodeIfPresent(hubAccountID, forKey: .hubAccountID)
    }

    /// Keep the newer working copy while retaining deletions from either copy.
    public static func newer(_ lhs: KithDocument, _ rhs: KithDocument) -> KithDocument {
        // The first argument is the retained working copy. Never merge records
        // or deletion markers across different (including unapproved) owners.
        guard lhs.hubAccountID == rhs.hubAccountID else { return lhs }
        var chosen = lhs.savedAt >= rhs.savedAt ? lhs : rhs
        chosen.deletionDates = lhs.deletionDates.merging(rhs.deletionDates, uniquingKeysWith: max)
        chosen.people.removeAll { chosen.deletionDates[$0.id] != nil }
        for entry in chosen.entries {
            if let deletedAt = chosen.deletionDates[entry.personID], chosen.deletionDates[entry.id] == nil {
                chosen.deletionDates[entry.id] = deletedAt
            }
        }
        chosen.entries.removeAll {
            chosen.deletionDates[$0.id] != nil || chosen.deletionDates[$0.personID] != nil
        }
        return chosen
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
        guard deletionDates[person.id] == nil else { throw KithError.deletedRecord }
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
        let deletedAt = Date()
        for recordID in [id] + entries.filter({ $0.personID == id }).map(\.id) {
            if deletionDates[recordID] == nil { deletionDates[recordID] = deletedAt }
        }
        people.removeAll { $0.id == id }
        entries.removeAll { $0.personID == id }
        markSaved()
    }

    public mutating func add(_ entry: Entry) throws {
        guard deletionDates[entry.id] == nil, deletionDates[entry.personID] == nil else {
            throw KithError.deletedRecord
        }
        guard people.contains(where: { $0.id == entry.personID }) else {
            throw KithError.missingPerson
        }
        entries.append(entry)
        markSaved()
    }

    public mutating func removeEntry(id: UUID) {
        if deletionDates[id] == nil { deletionDates[id] = Date() }
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
