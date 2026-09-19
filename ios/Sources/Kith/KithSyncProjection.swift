import CryptoKit
import Foundation
import KithCore
import PersonalSyncKit

/// Approval belongs to saved content on this device, never merely a sign-in
/// or a document downloaded from iCloud. Wire names are retained independently
/// of the local UUID and of a person's reference ID.
enum KithSyncProjection {
    static func name(_ id: UUID, in document: KithDocument) -> String {
        document.syncRecordNames[id] ?? id.uuidString.lowercased()
    }

    static func reference(_ id: UUID, in document: KithDocument) -> String {
        document.syncPersonReferences[id] ?? id.uuidString.lowercased()
    }

    static func records(_ document: KithDocument, transport: String = "cloudkit") throws -> [MirrorRecord] {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var values: [(UUID, MirrorRecord)] = []
        for person in document.people where document.deletionDates[person.id] == nil {
            var payload = KithPlatformRecord.person(person).objectValue!
            payload["personId"] = .string(reference(person.id, in: document))
            values.append((person.id, MirrorRecord(name: name(person.id, in: document),
                modifiedAt: person.updatedAt, payload: try encoder.encode(JSONValue.object(payload)))))
        }
        for entry in document.entries where document.deletionDates[entry.id] == nil {
            guard document.deletionDates[entry.personID] == nil,
                  let person = document.person(id: entry.personID) else { continue }
            var payload = KithPlatformRecord.interaction(entry, person: person).objectValue!
            payload["personId"] = .string(reference(person.id, in: document))
            values.append((entry.id, MirrorRecord(name: name(entry.id, in: document),
                modifiedAt: entry.happenedOn, payload: try encoder.encode(JSONValue.object(payload)))))
        }
        for (id, date) in document.deletionDates {
            values.append((id, MirrorRecord(name: name(id, in: document), modifiedAt: date, payload: nil)))
        }
        guard Set(values.map { $0.1.name }).count == values.count else {
            throw KithSyncCommitError.malformedRecord("Conflicting saved wire identities")
        }
        guard transport == "hub" else {
            return values.map { id, record in
                var record = record
                record.hubOwnerID = document.hubRecordOwners[id]
                return record
            }
        }
        guard let owner = document.hubAccountID else { return [] }
        let approved = Set(values.filter { id, record in
            document.hubRecordOwners[id] == owner && document.hubApprovedFingerprints[id] == fingerprint(record)
        }.map(\.0))
        return values.filter { id, _ in
            guard approved.contains(id) else { return false }
            if let entry = document.entries.first(where: { $0.id == id }) {
                return approved.contains(entry.personID)
            }
            return true
        }.map(\.1)
    }

    static func fingerprint(_ record: MirrorRecord) -> String {
        guard let data = record.payload else { return "deleted" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func fingerprints(_ document: KithDocument) throws -> [UUID: String] {
        var result: [UUID: String] = [:]
        for record in try records(document) {
            let id = document.syncRecordNames.first(where: { $0.value == record.name })?.key
                ?? KithPlatformRecord.stableUUID(record.name)
            result[id] = fingerprint(record)
        }
        return result
    }

    static func pendingApprovalCount(_ document: KithDocument, owner: String) -> Int {
        guard let current = try? fingerprints(document) else { return 0 }
        return current.filter { id, digest in
            (document.deletionDates[id] == nil || document.hubRecordOwners[id] != nil)
                && (document.hubRecordOwners[id] == nil || document.hubRecordOwners[id] == owner)
                && document.hubApprovedFingerprints[id] != digest
        }.count
    }

    static func approve(_ document: inout KithDocument, owner: String) throws {
        guard document.hubAccountID == nil || document.hubAccountID == owner else { throw KithError.accountMismatch }
        let current = try fingerprints(document)
        for (id, digest) in current where document.hubRecordOwners[id] == nil || document.hubRecordOwners[id] == owner {
            // A hard deletion with no retained owner is not authority to erase
            // an arbitrary account's record, even during approval of live data.
            if document.deletionDates[id] != nil && document.hubRecordOwners[id] == nil { continue }
            document.hubRecordOwners[id] = owner
            document.hubApprovedFingerprints[id] = digest
        }
        document.hubAccountID = owner
        document.markSaved()
    }

    /// Only local authoring extends consent. Editing an unresolved import does
    /// not approve it; deleting one does not turn it into an approved tombstone.
    static func recordLocalChanges(from before: KithDocument, to after: inout KithDocument) throws {
        guard let owner = before.hubAccountID else { return }
        let old = try fingerprints(before)
        let new = try fingerprints(after)
        for (id, digest) in new {
            let wasApproved = before.hubRecordOwners[id] == owner && before.hubApprovedFingerprints[id] == old[id]
                && old[id] != nil
            let newlyAuthored = old[id] == nil && after.deletionDates[id] == nil
            if wasApproved || newlyAuthored {
                after.hubRecordOwners[id] = owner
                after.hubApprovedFingerprints[id] = digest
            }
        }
    }

    static func bindName(_ name: String, id: UUID, in document: inout KithDocument) throws {
        guard !name.isEmpty,
              !document.syncRecordNames.contains(where: { $0.key != id && $0.value == name }),
              document.syncRecordNames[id] == nil || document.syncRecordNames[id] == name else {
            throw KithSyncCommitError.malformedRecord(name)
        }
        // A raw alias may not silently capture an unrelated native UUID.
        if document.syncRecordNames[id] == nil, name != id.uuidString.lowercased(),
           document.person(id: id) != nil || document.entries.contains(where: { $0.id == id }) || document.deletionDates[id] != nil {
            throw KithSyncCommitError.malformedRecord(name)
        }
        document.syncRecordNames[id] = name
    }

    static func bindReference(_ reference: String, id: UUID, in document: inout KithDocument) throws {
        guard !reference.isEmpty,
              !document.syncPersonReferences.contains(where: { $0.key != id && $0.value == reference }),
              document.syncPersonReferences[id] == nil || document.syncPersonReferences[id] == reference else {
            throw KithSyncCommitError.malformedRecord(reference)
        }
        document.syncPersonReferences[id] = reference
    }
}
