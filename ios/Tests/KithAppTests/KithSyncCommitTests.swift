import Foundation
import KithCore
import PersonalSyncKit
import XCTest
@testable import Kith

@MainActor
final class KithSyncCommitTests: XCTestCase {
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
