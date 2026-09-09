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
        // No platform connection represents a local deletion before optional
        // sync can durably enqueue anything. Only the saved journal survives.
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let deleted = deletePerson ? await model.deletePerson(id: person.id) : await model.deleteEntry(id: note.id)
        XCTAssertTrue(deleted)
        let reopened = AppModel(store: store, cloud: nil, platform: nil)
        await reopened.load()
        let transport = KithDownloadTransport(person: person, note: note)
        let oldDownload = try await transport.pull(domain: .kith, cursor: 0, bearerToken: "synthetic")
        try await reopened.commitPlatformChanges(oldDownload.changes)
        let persisted = try await store.load()
        XCTAssertTrue(persisted.entries.isEmpty, "An older Hub note must not undo a saved deletion")
        XCTAssertEqual(persisted.people.count, deletePerson ? 0 : 1)
    }

    func testDeletionQueueWriteFailureRecoversFromReopenedDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Synthetic note")
        try await store.save(KithDocument(people: [person], entries: [note]))
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let deleted = await model.deletePerson(id: person.id)
        XCTAssertTrue(deleted)
        let syncRoot = root.appending(path: "sync")
        let identity = PersonalIdentityClient(baseURL: URL(string: "https://synthetic.invalid")!, tokenStore: KithTestTokenStore())
        let runtime = try PersonalSyncRuntime(domain: .kith, deviceId: "synthetic", supportDirectory: syncRoot,
                                             identity: identity, client: PersonalSyncClient(baseURL: URL(string: "https://synthetic.invalid")!))
        let outboxFile = syncRoot.appending(path: "personal-sync-outbox.json")
        try FileManager.default.createDirectory(at: outboxFile, withIntermediateDirectories: true)
        do {
            try await model.enqueueLocalRecords(using: runtime)
            XCTFail("A failed queue write must be reported")
        } catch { }
        let saved = try await store.load()
        XCTAssertEqual(Set(saved.deletionDates.keys), Set([person.id, note.id]))
        try FileManager.default.removeItem(at: outboxFile)
        let reopened = AppModel(store: store, cloud: nil, platform: nil)
        await reopened.load()
        try await reopened.enqueueLocalRecords(using: runtime)
        let queued = try await MutationOutbox(fileURL: outboxFile).pending(for: .kith)
        XCTAssertEqual(Set(queued.map { $0.mutation.id }), Set([person.id, note.id].map { $0.uuidString.lowercased() }))
        XCTAssertTrue(queued.allSatisfy { $0.mutation.operation == .delete })
        try await reopened.enqueueLocalRecords(using: runtime)
        let count = await runtime.pendingMutationCount()
        XCTAssertEqual(count, 2, "Replaying retained deletion markers must not duplicate durable work")
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

    func testUnseenDownloadedNoteForDeletedPersonIsAlsoQueuedForDeletion() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        var local = KithDocument(people: [person])
        local.removePerson(id: person.id)
        try await store.save(local)
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let unseen = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Unseen other-device note")
        let transport = KithDownloadTransport(person: person, note: unseen)
        let batch = try await transport.pull(domain: .kith, cursor: 0, bearerToken: "synthetic")
        try await model.commitPlatformChanges(batch.changes)
        let persisted = try await store.load()
        XCTAssertTrue(persisted.people.isEmpty)
        XCTAssertTrue(persisted.entries.isEmpty)
        XCTAssertNotNil(persisted.deletionDates[unseen.id])
        let remote = KithDocument(people: [person], entries: [unseen], savedAt: local.savedAt.addingTimeInterval(60))
        XCTAssertNotNil(KithDocument.newer(local, remote).deletionDates[unseen.id])
    }

    func testCloudRefreshMirrorsRetainedLocalDeletionsBackToCloud() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        var local = KithDocument(people: [person])
        local.removePerson(id: person.id)
        try await store.save(local)
        let remote = KithDocument(people: [person], savedAt: local.savedAt.addingTimeInterval(60))
        let cloud = KithDeletionMirror(remote)
        let model = AppModel(store: store, cloud: cloud, platform: nil)
        await model.load()
        XCTAssertTrue(model.document.people.isEmpty)
        let mirrored = await cloud.saved
        XCTAssertTrue(try XCTUnwrap(mirrored).people.isEmpty)
        XCTAssertNotNil(mirrored?.deletionDates[person.id])
    }

    func testRecoveryRestoresPreviouslyAcknowledgedNoteAndPreservesLocalPersonAfterRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "people.json")
        let backup = root.appending(path: "retained.json")
        let store = KithStore(fileURL: file)
        let remote = Person(name: "Older Hub name", closeness: 2, hue: .clay)
        var local = remote
        local.name = "Current local name"
        local.standingNotes = "Keep this local detail"
        try await store.save(KithDocument(people: [local], hubAccountID: "a"))
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let note = Entry(personID: remote.id, kind: .note, happenedOn: .now, body: "Previously skipped Hub memory")
        let transport = KithDownloadTransport(person: remote, note: note, timestamp: "2026-09-09T10:15:30.123Z")
        let cursorFile = root.appending(path: "cursor.json")
        let coordinator = try SyncCoordinator(
            client: transport, outbox: MutationOutbox(fileURL: root.appending(path: "outbox.json")),
            cursors: SyncCursorStore(fileURL: cursorFile),
            versions: SyncVersionStore(fileURL: root.appending(path: "versions.json")),
            fingerprints: SyncFingerprintStore(fileURL: root.appending(path: "fingerprints.json"))
        )
        // Simulate the old decoder bug: all metadata acknowledged but no app records applied.
        try await coordinator.synchronize(domain: .kith, deviceId: "fixture", bearerToken: "synthetic") { _ in }
        let oldCursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .kith)
        XCTAssertEqual(oldCursor, 2)
        let oldFingerprint = try await SyncFingerprintStore(fileURL: root.appending(path: "fingerprints.json")).fingerprint(for: note.id.uuidString.lowercased(), in: .kith)
        XCTAssertNotNil(oldFingerprint)
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let baseline = model.document
        do {
            try await coordinator.synchronize(domain: .kith, deviceId: "fixture", bearerToken: "synthetic", replayFromStart: true) { changes in
                try await model.commitRecoveredPlatformChanges(changes, ownerID: "a", baseline: baseline)
            }
            XCTFail("Failed recovery write must remain retryable")
        } catch KithSyncCommitError.localSaveFailed {}
        XCTAssertTrue(model.document.entries.isEmpty)
        let retainedCursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .kith)
        XCTAssertEqual(retainedCursor, 2)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        for _ in 0..<2 {
            try await coordinator.synchronize(domain: .kith, deviceId: "fixture", bearerToken: "synthetic", replayFromStart: true) { changes in
                try await model.commitRecoveredPlatformChanges(changes, ownerID: "a", baseline: baseline)
            }
        }
        let reopened = try await store.load()
        XCTAssertEqual(reopened.person(id: local.id)?.name, local.name)
        XCTAssertEqual(reopened.person(id: local.id)?.standingNotes, local.standingNotes)
        XCTAssertEqual(reopened.entries.map(\.body), [note.body])
        let calls = await transport.requestedCursors
        XCTAssertEqual(calls, [0, 0, 0, 0])
    }

    func testRecoveryKeepsTombstonesAndPeopleEditedDuringDownload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Local friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Old note")
        var document = KithDocument(people: [person], entries: [note], hubAccountID: "a")
        document.removeEntry(id: note.id)
        try await store.save(document)
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let baseline = model.document
        var edited = person
        edited.name = "Edited while downloading"
        let saved = await model.savePerson(edited)
        XCTAssertTrue(saved)
        let transport = KithDownloadTransport(person: person, note: note)
        let batch = try await transport.pull(domain: .kith, cursor: 0, bearerToken: "synthetic")
        try await model.commitRecoveredPlatformChanges(batch.changes, ownerID: "a", baseline: baseline)
        XCTAssertEqual(model.document.person(id: person.id)?.name, edited.name)
        XCTAssertTrue(model.document.entries.isEmpty)
        XCTAssertNotNil(model.document.deletionDates[note.id])
        let deleteJSON = "{\"cursor\":3,\"changeId\":\"delete\",\"domain\":\"kith\",\"id\":\"\(person.id.uuidString.lowercased())\",\"operation\":\"delete\",\"version\":2,\"occurredAt\":\"2026-09-09\",\"recordedAt\":\"2026-09-09\",\"originDeviceId\":\"fixture\",\"record\":null}"
        let deletion = try JSONDecoder().decode(SyncChange.self, from: Data(deleteJSON.utf8))
        try await model.commitRecoveredPlatformChanges([deletion], ownerID: "a", baseline: baseline)
        XCTAssertEqual(model.document.person(id: person.id)?.name, edited.name)
        do {
            try await model.commitRecoveredPlatformChanges(batch.changes, ownerID: "b", baseline: baseline)
            XCTFail("Another owner cannot recover into this document")
        } catch KithSyncCommitError.localSaveFailed {}
        let persisted = try await store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
        XCTAssertEqual(persisted.person(id: person.id)?.name, edited.name)
        XCTAssertNotNil(persisted.deletionDates[note.id])
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

    func testHubAcceptedDatesCommitBeforeCursorAdvancesAndSurviveReopen() async throws {
        // services/hub-backend/src/contracts.ts accepts dates, whole seconds,
        // and one to three fractional digits, with Z or a numeric offset.
        for timestamp in ["2026-09-09T10:15:30Z", "2026-09-09T10:15:30.123Z",
                          "2026-09-09T15:45:30.1+05:30", "2026-09-09"] {
            let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let store = KithStore(fileURL: root.appending(path: "people.json"))
            let model = AppModel(store: store, cloud: nil, platform: nil)
            await model.load()
            let person = Person(name: "Hub date fixture", closeness: 4, hue: .clay)
            let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Keep the dated memory")
            let transport = KithDownloadTransport(person: person, note: note, timestamp: timestamp)
            let cursorFile = root.appending(path: "cursor.json")
            let coordinator = try SyncCoordinator(
                client: transport, outbox: MutationOutbox(fileURL: root.appending(path: "outbox.json")),
                cursors: SyncCursorStore(fileURL: cursorFile),
                versions: SyncVersionStore(fileURL: root.appending(path: "versions.json")),
                fingerprints: SyncFingerprintStore(fileURL: root.appending(path: "fingerprints.json"))
            )
            try await coordinator.synchronize(domain: .kith, deviceId: "date-fixture", bearerToken: "synthetic") { changes in
                try await model.commitPlatformChanges(changes)
            }
            let persisted = try await store.load()
            XCTAssertEqual(persisted.person(id: person.id)?.name, person.name, timestamp)
            XCTAssertEqual(persisted.entries.map(\.body), [note.body], timestamp)
            XCTAssertNotNil(persisted.person(id: person.id)?.birthday, timestamp)
            let cursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .kith)
            XCTAssertEqual(cursor, 2)
            // Replaying the acknowledged batch must not duplicate either record.
            let batch = try await transport.pull(domain: .kith, cursor: 0, bearerToken: "synthetic")
            try await model.commitPlatformChanges(batch.changes)
            XCTAssertEqual(model.document.people.count, 1, timestamp)
            XCTAssertEqual(model.document.entries.count, 1, timestamp)
        }
    }

    func testDownloadedPersonAndNoteRetryAfterFailedAppWrite() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let appFile = root.appending(path: "people.json")
        let appStore = KithStore(fileURL: appFile)
        let model = AppModel(store: appStore, cloud: nil, platform: nil)
        await model.load()
        let person = Person(name: "Downloaded friend", closeness: 4, hue: .clay)
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Retain this downloaded memory")
        let transport = KithDownloadTransport(person: person, note: note)
        let cursorFile = root.appending(path: "cursor.json")
        let coordinator = try SyncCoordinator(
            client: transport,
            outbox: MutationOutbox(fileURL: root.appending(path: "outbox.json")),
            cursors: SyncCursorStore(fileURL: cursorFile),
            versions: SyncVersionStore(fileURL: root.appending(path: "versions.json")),
            fingerprints: SyncFingerprintStore(fileURL: root.appending(path: "fingerprints.json"))
        )
        try FileManager.default.createDirectory(at: appFile, withIntermediateDirectories: true)
        do {
            try await coordinator.synchronize(domain: .kith, deviceId: "test", bearerToken: "synthetic") { changes in
                try await model.commitPlatformChanges(changes)
            }
            XCTFail("A failed app save must not acknowledge the download")
        } catch KithSyncCommitError.localSaveFailed {}
        XCTAssertTrue(model.document.people.isEmpty)
        XCTAssertTrue(model.document.entries.isEmpty)
        let uncommittedCursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .kith)
        XCTAssertEqual(uncommittedCursor, 0)
        try FileManager.default.removeItem(at: appFile)

        try await coordinator.synchronize(domain: .kith, deviceId: "test", bearerToken: "synthetic") { changes in
            try await model.commitPlatformChanges(changes)
        }
        let reopened = AppModel(store: appStore, cloud: nil, platform: nil)
        await reopened.load()
        XCTAssertEqual(reopened.document.person(id: person.id)?.name, person.name)
        XCTAssertEqual(reopened.document.entries.map(\.body), [note.body])
        let committedCursor = try await SyncCursorStore(fileURL: cursorFile).cursor(for: .kith)
        XCTAssertEqual(committedCursor, 2)
        let calls = await transport.requestedCursors
        XCTAssertEqual(calls, [0, 0])

        // A bookkeeping failure can replay an already saved batch. Verify the
        // real Kith adapter keeps one person and one note on replay.
        let batch = try await transport.pull(domain: .kith, cursor: 0, bearerToken: "synthetic")
        try await reopened.commitPlatformChanges(batch.changes)
        let disk = try await appStore.load()
        XCTAssertEqual(disk.people.map(\.id), [person.id])
        XCTAssertEqual(disk.entries.map(\.id), [note.id])
    }
}

private actor KithDownloadTransport: PersonalSyncTransport {
    let person: Person
    let note: Entry
    private(set) var requestedCursors: [Int] = []
    let timestamp: String?
    init(person: Person, note: Entry, timestamp: String? = nil) {
        self.person = person; self.note = note; self.timestamp = timestamp
    }

    func push(domain: PersonalDomain, deviceId: String, mutations: [SyncMutation], bearerToken: String) async throws -> PushResponse {
        try JSONDecoder().decode(PushResponse.self, from: Data("{\"results\":[]}".utf8))
    }

    func pull(domain: PersonalDomain, cursor: Int, bearerToken: String) async throws -> PullResponse {
        requestedCursors.append(cursor)
        var personRecord = KithPlatformRecord.person(person).objectValue!
        var noteRecord = KithPlatformRecord.interaction(note, person: person).objectValue!
        if let timestamp {
            personRecord["createdAt"] = .string(timestamp)
            personRecord["birthday"] = .string(timestamp)
            noteRecord["occurredAt"] = .string(timestamp)
        }
        let records: [(UUID, JSONValue)] = [
            (person.id, .object(personRecord)),
            (note.id, .object(noteRecord)),
        ]
        let changes: [JSONValue] = cursor == 0 ? records.enumerated().map { index, record in
            .object([
                "cursor": .number(Double(index + 1)), "changeId": .string("change-\(index)"),
                "domain": .string("kith"), "id": .string(record.0.uuidString.lowercased()),
                "operation": .string("upsert"), "version": .number(1),
                "occurredAt": .string("2026-09-08"), "recordedAt": .string("2026-09-08"),
                "originDeviceId": .string("another-device"), "record": record.1,
            ])
        } : []
        let response = JSONValue.object(["changes": .array(changes), "cursor": .number(2), "hasMore": .bool(false)])
        return try JSONDecoder().decode(PullResponse.self, from: JSONEncoder().encode(response))
    }
}

private actor KithTestTokenStore: PersonalBearerTokenStore {
    func load() -> String? { nil }
    func save(_ token: String) { }
    func delete() { }
}

private actor KithDeletionMirror: KithCloudStorage {
    let remote: KithDocument
    private(set) var saved: KithDocument?
    init(_ remote: KithDocument) { self.remote = remote }
    func availability() -> CloudAvailability { .available }
    func fetch() -> KithDocument? { remote }
    func save(_ document: KithDocument) { saved = document }
}
