import CryptoKit
import Foundation
import KithCore
import PersonalSyncKit

enum KithPlatformRecord {
    static func person(_ person: Person) -> JSONValue {
        .object([
            "recordType": .string("person"),
            "personId": .string(person.id.uuidString.lowercased()),
            "personName": .string(person.name),
            "circle": .string(person.circle.rawValue),
            "closeness": .number(Double(person.closeness)),
            "hue": .string(person.hue.rawValue),
            "birthday": person.birthday.map { .string(iso($0)) } ?? .null,
            "howWeMet": person.howWeMet.isEmpty ? .null : .string(person.howWeMet),
            "standingNotes": person.standingNotes.isEmpty ? .null : .string(person.standingNotes),
            "createdAt": .string(iso(person.createdAt)),
        ])
    }

    static func interaction(_ entry: Entry, person: Person) -> JSONValue {
        .object([
            "recordType": .string("interaction"),
            "personId": .string(person.id.uuidString.lowercased()),
            "personName": .string(person.name),
            "kind": .string(entry.kind.rawValue),
            "occurredAt": .string(iso(entry.happenedOn)),
            "note": entry.body.isEmpty ? .null : .string(entry.body),
            "followUpAt": .null,
        ])
    }

    static func person(from value: [String: JSONValue]) -> Person? {
        guard let idText = value["personId"]?.stringValue,
              let name = value["personName"]?.stringValue,
              let circleText = value["circle"]?.stringValue,
              let circle = CircleKind(rawValue: circleText),
              let hueText = value["hue"]?.stringValue,
              let hue = PersonHue(rawValue: hueText),
              let createdText = value["createdAt"]?.stringValue,
              let createdAt = date(createdText) else { return nil }
        return Person(
            id: stableUUID(idText),
            name: name,
            howWeMet: value["howWeMet"]?.stringValue ?? "",
            circle: circle,
            closeness: Int(value["closeness"]?.numberValue ?? 3),
            hue: hue,
            birthday: value["birthday"]?.stringValue.flatMap(date),
            standingNotes: value["standingNotes"]?.stringValue ?? "",
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }

    static func interaction(
        from value: [String: JSONValue],
        recordId: String
    ) -> (person: Person, entry: Entry)? {
        guard let personId = value["personId"]?.stringValue,
              let personName = value["personName"]?.stringValue,
              let occurredText = value["occurredAt"]?.stringValue,
              let occurredAt = date(occurredText) else { return nil }
        let person = Person(id: stableUUID(personId), name: personName)
        let entry = Entry(
            id: stableUUID(recordId),
            personID: person.id,
            kind: value["kind"]?.stringValue.flatMap(LogKind.init(rawValue:)) ?? .note,
            happenedOn: occurredAt,
            body: value["note"]?.stringValue ?? "",
            createdAt: occurredAt
        )
        return (person, entry)
    }

    static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func date(_ text: String) -> Date? {
        ISO8601DateFormatter().date(from: text)
    }

    private static func stableUUID(_ value: String) -> UUID {
        if let uuid = UUID(uuidString: value) { return uuid }
        let bytes = Array(SHA256.hash(data: Data(value.utf8)).prefix(16))
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

extension JSONValue {
    var objectValue: [String: JSONValue]? {
        guard case let .object(value) = self else { return nil }
        return value
    }

    var stringValue: String? {
        guard case let .string(value) = self else { return nil }
        return value
    }

    var numberValue: Double? {
        guard case let .number(value) = self else { return nil }
        return value
    }
}
