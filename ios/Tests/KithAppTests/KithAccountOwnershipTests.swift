import Foundation
import KithCore
import XCTest
@testable import Kith

@MainActor
final class KithAccountOwnershipTests: XCTestCase {
    func testApprovedOwnerSurvivesRestartAndCannotBeReassigned() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic A", closeness: 4, hue: .clay)
        try await store.save(KithDocument(people: [person]))
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let approved = await model.approveLocalHubOwner("a")
        XCTAssertTrue(approved)
        let reopened = AppModel(store: store, cloud: nil, platform: nil)
        await reopened.load()
        XCTAssertEqual(reopened.document.hubAccountID, "a")
        let reassigned = await reopened.approveLocalHubOwner("b")
        XCTAssertFalse(reassigned)
        let persisted = try await store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
        XCTAssertEqual(persisted.people.map(\.id), [person.id])
        do {
            try await reopened.commitPlatformChanges([], ownerID: "b")
            XCTFail("Wrong-account downloads must be rejected even before applying records")
        } catch {}
    }

    func testFailedApprovalWriteLeavesDocumentUnownedAndRetryable() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "people.json")
        let store = KithStore(fileURL: file)
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let failed = await model.approveLocalHubOwner("a")
        XCTAssertFalse(failed)
        XCTAssertNil(model.document.hubAccountID)
        try FileManager.default.removeItem(at: file)
        let retried = await model.approveLocalHubOwner("a")
        XCTAssertTrue(retried)
        let persisted = try await store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
    }

    func testCloudCopyCannotMixOwnersOrRemoveApproval() throws {
        let person = Person(name: "Synthetic A", closeness: 4, hue: .clay)
        let local = KithDocument(people: [person], savedAt: .now, hubAccountID: "a")
        for owner in [nil, "b"] as [String?] {
            let remote = KithDocument(savedAt: local.savedAt.addingTimeInterval(60), deletionDates: [person.id: .now], hubAccountID: owner)
            XCTAssertEqual(KithDocument.newer(local, remote), local)
        }
        let reopened = try KithStore.decode(KithStore.encode(local))
        XCTAssertEqual(reopened.hubAccountID, "a")
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: KithStore.encode(local)) as? [String: Any])
        legacy.removeValue(forKey: "hubAccountID")
        XCTAssertNil(try KithStore.decode(JSONSerialization.data(withJSONObject: legacy)).hubAccountID)
    }

    func testMismatchedCloudMirrorIsPausedWithoutOverwritingEitherCopy() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "Synthetic A", closeness: 4, hue: .clay)
        try await store.save(KithDocument(people: [person], hubAccountID: "a"))
        let cloud = OwnershipCloudFixture()
        let model = AppModel(store: store, cloud: cloud, platform: nil)
        await model.load()
        XCTAssertEqual(model.document.people.map(\.id), [person.id])
        XCTAssertNotNil(model.cloudAccountNotice)
        let saves = await cloud.saves
        XCTAssertEqual(saves, 0)
    }
}

private actor OwnershipCloudFixture: KithCloudStorage {
    private(set) var saves = 0
    func availability() -> CloudAvailability { .available }
    func fetch() -> KithDocument? { KithDocument(savedAt: .now, hubAccountID: "b") }
    func save(_ document: KithDocument) { saves += 1 }
}
