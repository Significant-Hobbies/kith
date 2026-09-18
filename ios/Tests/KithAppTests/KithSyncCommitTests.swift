import Foundation
import KithCore
import PersonalSyncKit
import XCTest
@testable import Kith

@MainActor
final class KithSyncCommitTests: XCTestCase {
    func testDeletedPersonAndNotesDoNotReturnFromAnOldDownloadAfterRestart() async throws {
        try await checkDeletionSurvivesRestart(deletePerson: true)
    }

    func testDeletedNoteDoesNotReturnFromAnOldDownloadAfterRestart() async throws {
        try await checkDeletionSurvivesRestart(deletePerson: false)
    }

    private func checkDeletionSurvivesRestart(deletePerson: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Delete this synthetic note")
        try await store.save(KithDocument(people: [person], entries: [note]))
        // No mirror connection represents a local deletion before optional
        // sync can durably record anything. Only the saved journal survives.
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let deleted = deletePerson ? await model.deletePerson(id: person.id) : await model.deleteEntry(id: note.id)
        XCTAssertTrue(deleted)
        let reopened = AppModel(store: store, cloud: nil, mirror: nil)
        await reopened.load()
        // A stale remote copy arriving after the deletion must stay dead: the
        // tombstone guards in the apply path refuse the older upserts.
        try await reopened.commitMirrorRecords(
            KithPullFixture.records(person: person, note: note, modifiedAt: .distantPast)
        )
        let persisted = try await store.load()
        XCTAssertTrue(persisted.entries.isEmpty, "An older remote note must not undo a saved deletion")
        XCTAssertEqual(persisted.people.count, deletePerson ? 0 : 1)
    }

    func testDeletionMarkersBecomeTombstoneRecordsAfterReopen() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Synthetic note")
        try await store.save(KithDocument(people: [person], entries: [note]))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let deleted = await model.deletePerson(id: person.id)
        XCTAssertTrue(deleted)
        let reopened = AppModel(store: store, cloud: nil, mirror: nil)
        await reopened.load()
        let records = try reopened.mirrorRecords()
        XCTAssertEqual(
            Set(records.map(\.name)),
            Set([person.id, note.id].map { $0.uuidString.lowercased() })
        )
        XCTAssertTrue(records.allSatisfy(\.isDeleted), "Retained deletion markers must surface as tombstones")
    }

    func testNewerCloudCopyCannotDiscardLocalDeletionMarkers() throws {
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Synthetic note")
        var local = KithDocument(people: [person], entries: [note])
        local.removePerson(id: person.id)
        let remote = KithDocument(people: [person], entries: [note], savedAt: local.savedAt.addingTimeInterval(60))
        for merged in [KithDocument.newer(local, remote), KithDocument.newer(remote, local)] {
            XCTAssertTrue(merged.people.isEmpty)
            XCTAssertTrue(merged.entries.isEmpty)
            XCTAssertEqual(Set(merged.deletionDates.keys), Set([person.id, note.id]))
            let reopened = try KithStore.decode(KithStore.encode(merged))
            XCTAssertEqual(Set(reopened.deletionDates.keys), Set(merged.deletionDates.keys))
            for (id, date) in reopened.deletionDates {
                let expected = try XCTUnwrap(merged.deletionDates[id])
                XCTAssertEqual(date.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1,
                               "The journal's ISO-8601 format preserves dates to whole seconds")
            }
        }
    }

    func testUnseenDownloadedNoteForDeletedPersonIsAlsoTombstoned() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        var local = KithDocument(people: [person])
        local.removePerson(id: person.id)
        try await store.save(local)
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let unseen = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Unseen other-device note")
        try await model.commitMirrorRecords(
            KithPullFixture.records(person: person, note: unseen)
        )
        let persisted = try await store.load()
        XCTAssertTrue(persisted.people.isEmpty)
        XCTAssertTrue(persisted.entries.isEmpty)
        XCTAssertNotNil(persisted.deletionDates[unseen.id])
        let remote = KithDocument(people: [person], entries: [unseen], savedAt: local.savedAt.addingTimeInterval(60))
        XCTAssertNotNil(KithDocument.newer(local, remote).deletionDates[unseen.id])
    }

    func testLegacyCloudMirrorNeverOverwritesATombstoneOnlyDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        var local = KithDocument(people: [person])
        local.removePerson(id: person.id)
        try await store.save(local)
        let remote = KithDocument(people: [person], savedAt: local.savedAt.addingTimeInterval(60))
        let cloud = KithDeletionMirror(remote)
        let model = AppModel(store: store, cloud: cloud, mirror: nil)
        await model.load()
        XCTAssertTrue(model.document.people.isEmpty)
        XCTAssertNotNil(model.document.deletionDates[person.id])
        let saves = await cloud.saves
        XCTAssertEqual(saves, 0, "The retired blob mirror is import-only and must never be written")
    }

    func testEmptyDocumentAdoptsTheLegacyCloudMirrorOnce() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Restored friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Restored note")
        let remote = KithDocument(people: [person], entries: [note], savedAt: .now)
        let cloud = KithDeletionMirror(remote)
        let model = AppModel(store: store, cloud: cloud, mirror: nil)
        await model.load()
        XCTAssertEqual(model.document.people.map(\.id), [person.id])
        XCTAssertEqual(model.document.entries.map(\.id), [note.id])
        let persisted = try await store.load()
        XCTAssertEqual(persisted.people.map(\.id), [person.id])
    }

    func testMergedSnapshotCarriesPeopleNotesAndTombstones() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let living = Person(name: "Living friend", closeness: 4, hue: .clay)
        let departed = Person(name: "Departed friend", closeness: 2, hue: .sage)
        let note = Entry(personID: living.id, kind: .note, happenedOn: .now, body: "Synthetic note")
        var document = KithDocument(people: [living, departed], entries: [note])
        document.removePerson(id: departed.id)
        try await store.save(document)
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let records = try model.mirrorRecords()
        let byName = Dictionary(uniqueKeysWithValues: records.map { ($0.name, $0) })
        XCTAssertEqual(byName.count, 3)
        let livePerson = try XCTUnwrap(byName[living.id.uuidString.lowercased()])
        XCTAssertFalse(livePerson.isDeleted)
        XCTAssertEqual(livePerson.modifiedAt.timeIntervalSince1970,
                       living.updatedAt.timeIntervalSince1970, accuracy: 1)
        let liveNote = try XCTUnwrap(byName[note.id.uuidString.lowercased()])
        XCTAssertFalse(liveNote.isDeleted)
        let tombstone = try XCTUnwrap(byName[departed.id.uuidString.lowercased()])
        XCTAssertTrue(tombstone.isDeleted)
        let deletedAt = try XCTUnwrap(document.deletionDates[departed.id])
        XCTAssertEqual(tombstone.modifiedAt.timeIntervalSince1970,
                       deletedAt.timeIntervalSince1970, accuracy: 1)
    }

    func testDownloadedPersonAndNoteRetryAfterFailedAppWrite() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let appFile = root.appending(path: "people.json")
        let appStore = KithStore(fileURL: appFile)
        let model = AppModel(store: appStore, cloud: nil, mirror: nil)
        await model.load()
        let person = Person(name: "Downloaded friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Retain this downloaded memory")
        let transport = KithPullFixture(person: person, note: note)
        let runtime = MirrorRuntime(
            transports: [transport],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )
        try FileManager.default.createDirectory(at: appFile, withIntermediateDirectories: true)
        let failedOutcome = try await runtime.synchronize(records: {
            try await model.mirrorRecords()
        }) { pulled in
            try await model.commitMirrorRecords(pulled)
        }
        XCTAssertFalse(failedOutcome.isComplete, "A failed app save must not acknowledge the download")
        XCTAssertTrue(model.document.people.isEmpty)
        XCTAssertTrue(model.document.entries.isEmpty)
        // The pull token must not advance while the local write is uncommitted.
        try FileManager.default.removeItem(at: appFile)

        _ = try await runtime.synchronize(records: {
            try await model.mirrorRecords()
        }) { pulled in
            try await model.commitMirrorRecords(pulled)
        }
        let reopened = AppModel(store: appStore, cloud: nil, mirror: nil)
        await reopened.load()
        XCTAssertEqual(reopened.document.person(id: person.id)?.name, person.name)
        XCTAssertEqual(reopened.document.entries.map(\.body), [note.body])
        // Both synchronize calls saw an empty pull token — the failed first
        // apply kept the download retryable.
        let pullTokens = await transport.pullTokens
        XCTAssertEqual(pullTokens, [nil, nil])
    }

    func testLocalWinnersAreNotOverwrittenByOlderDownloads() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Local friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Old note")
        var document = KithDocument(people: [person], entries: [note], hubAccountID: "a")
        document.removeEntry(id: note.id)
        try await store.save(document)
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        var edited = person
        edited.name = "Edited locally"
        let saved = await model.savePerson(edited)
        XCTAssertTrue(saved)
        // The remote serves the pre-edit person and the deleted note. Both are
        // older than the local winners, so the merge keeps local state and
        // pushes the winners back instead.
        let transport = KithPullFixture(person: person, note: note, modifiedAt: .distantPast)
        let runtime = MirrorRuntime(
            transports: [transport],
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
        )
        _ = try await runtime.synchronize(records: {
            try await model.mirrorRecords()
        }) { pulled in
            try await model.commitMirrorRecords(pulled)
        }
        XCTAssertEqual(model.document.person(id: person.id)?.name, "Edited locally")
        XCTAssertTrue(model.document.entries.isEmpty)
        XCTAssertNotNil(model.document.deletionDates[note.id])
        let pushed = await transport.pushed
        let pushedNames = Set(pushed.map(\.name))
        XCTAssertTrue(pushedNames.contains(person.id.uuidString.lowercased()))
        XCTAssertTrue(pushedNames.contains(note.id.uuidString.lowercased()))
        XCTAssertTrue(pushed.first { $0.name == note.id.uuidString.lowercased() }?.isDeleted == true)
    }

    func testMalformedRequiredDatesStillRejectDownloadedRecords() throws {
        let person = Person(name: "Date validation fixture")
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Fixture")
        for invalid in ["not-a-date", "2026-09-09T", "2026-09-09T10:15:30", ""] {
            var personRecord = try XCTUnwrap(KithPlatformRecord.person(person).objectValue)
            personRecord["createdAt"] = .string(invalid)
            XCTAssertNil(KithPlatformRecord.person(from: personRecord), invalid)
            var noteRecord = try XCTUnwrap(KithPlatformRecord.interaction(note, person: person).objectValue)
            noteRecord["occurredAt"] = .string(invalid)
            XCTAssertNil(KithPlatformRecord.interaction(from: noteRecord, recordId: note.id.uuidString), invalid)
        }
    }

    func testHubAcceptedDatesCommitBeforePullTokenAdvancesAndSurviveReopen() async throws {
        // services/hub-backend/src/contracts.ts accepts dates, whole seconds,
        // and one to three fractional digits, with Z or a numeric offset.
        for timestamp in ["2026-09-09T10:15:30Z", "2026-09-09T10:15:30.123Z",
                          "2026-09-09T15:45:30.1+05:30", "2026-09-09"] {
            let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = KithStore(fileURL: root.appending(path: "people.json"))
            let model = AppModel(store: store, cloud: nil, mirror: nil)
            await model.load()
            let person = Person(name: "Hub date fixture", closeness: 4, hue: .clay)
            let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Keep the dated memory")
            let transport = KithPullFixture(person: person, note: note, timestamp: timestamp)
            let runtime = MirrorRuntime(
                transports: [transport],
                store: try MirrorBookkeepingStore(fileURL: root.appending(path: "mirror.json"))
            )
            _ = try await runtime.synchronize(records: {
                try await model.mirrorRecords()
            }) { pulled in
                try await model.commitMirrorRecords(pulled)
            }
            let persisted = try await store.load()
            XCTAssertEqual(persisted.person(id: person.id)?.name, person.name, timestamp)
            XCTAssertEqual(persisted.entries.map(\.body), [note.body], timestamp)
            XCTAssertNotNil(persisted.person(id: person.id)?.birthday, timestamp)
            // Replaying the acknowledged batch must not duplicate either record.
            try await model.commitMirrorRecords(
                KithPullFixture.records(person: person, note: note, timestamp: timestamp)
            )
            XCTAssertEqual(model.document.people.count, 1, timestamp)
            XCTAssertEqual(model.document.entries.count, 1, timestamp)
        }
    }
}

private actor KithPullFixture: MirrorTransport {
    let id = "hub"
    let person: Person
    let note: Entry
    let timestamp: String?
    let modifiedAt: Date
    private(set) var pullTokens: [Data?] = []
    private(set) var pushed: [MirrorRecord] = []

    init(person: Person, note: Entry, timestamp: String? = nil, modifiedAt: Date = .now) {
        self.person = person
        self.note = note
        self.timestamp = timestamp
        self.modifiedAt = modifiedAt
    }

    static func records(
        person: Person,
        note: Entry,
        timestamp: String? = nil,
        modifiedAt: Date = .now
    ) -> [MirrorRecord] {
        var personRecord = KithPlatformRecord.person(person).objectValue!
        var noteRecord = KithPlatformRecord.interaction(note, person: person).objectValue!
        if let timestamp {
            personRecord["createdAt"] = .string(timestamp)
            personRecord["birthday"] = .string(timestamp)
            noteRecord["occurredAt"] = .string(timestamp)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return [
            MirrorRecord(
                name: person.id.uuidString.lowercased(), modifiedAt: modifiedAt,
                payload: try! encoder.encode(JSONValue.object(personRecord))
            ),
            MirrorRecord(
                name: note.id.uuidString.lowercased(), modifiedAt: modifiedAt,
                payload: try! encoder.encode(JSONValue.object(noteRecord))
            ),
        ]
    }

    func availability() async -> MirrorAvailability { .available }

    func pull(since token: Data?) async throws -> MirrorPullPage {
        pullTokens.append(token)
        if token == nil {
            return MirrorPullPage(
                records: Self.records(person: person, note: note, timestamp: timestamp, modifiedAt: modifiedAt),
                nextToken: Data("1".utf8)
            )
        }
        return MirrorPullPage(records: [], nextToken: token)
    }

    func push(_ records: [MirrorRecord]) async throws {
        pushed.append(contentsOf: records)
    }
}

private actor KithDeletionMirror: KithCloudStorage {
    let remote: KithDocument
    private(set) var saves = 0
    init(_ remote: KithDocument) { self.remote = remote }
    func availability() -> CloudAvailability { .available }
    func fetch() -> KithDocument? { remote }
    func save(_ document: KithDocument) { saves += 1 }
}
