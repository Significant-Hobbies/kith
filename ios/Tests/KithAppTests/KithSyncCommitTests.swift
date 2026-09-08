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
    init(person: Person, note: Entry) { self.person = person; self.note = note }

    func push(domain: PersonalDomain, deviceId: String, mutations: [SyncMutation], bearerToken: String) async throws -> PushResponse {
        try JSONDecoder().decode(PushResponse.self, from: Data("{\"results\":[]}".utf8))
    }

    func pull(domain: PersonalDomain, cursor: Int, bearerToken: String) async throws -> PullResponse {
        requestedCursors.append(cursor)
        let records: [(UUID, JSONValue)] = [
            (person.id, KithPlatformRecord.person(person)),
            (note.id, KithPlatformRecord.interaction(note, person: person)),
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
