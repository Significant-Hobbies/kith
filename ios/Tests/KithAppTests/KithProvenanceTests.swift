import Foundation
import KithCore
import PersonalSyncKit
import XCTest
@testable import Kith

@MainActor
final class KithProvenanceTests: XCTestCase {
    func testCaseVariantCannotRekeyAnExistingNativeRecord() throws {
        let person = Person(id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!, name: "Native")
        var document = KithDocument(people: [person])
        XCTAssertThrowsError(try KithSyncProjection.bindName(person.id.uuidString, id: person.id, in: &document))
        XCTAssertTrue(document.syncRecordNames.isEmpty)
        XCTAssertEqual(try KithSyncProjection.records(document).map(\.name), [person.id.uuidString.lowercased()])
    }

    func testOldDocumentOwnerDoesNotApproveItsRecords() throws {
        let person = Person(name: "Retained person")
        let old = KithDocument(people: [person], hubAccountID: "a")
        let reopened = try KithStore.decode(KithStore.encode(old))
        XCTAssertTrue(try KithSyncProjection.records(reopened, transport: "hub").isEmpty)
        XCTAssertEqual(KithSyncProjection.pendingApprovalCount(reopened, owner: "a"), 1)
        XCTAssertEqual(try KithSyncProjection.records(reopened).count, 1)
    }

    func testApprovalIsContentBoundAndNeverClaimsForeignRecordsOrUnknownDeletes() throws {
        let mine = Person(name: "Mine"), foreign = Person(name: "Foreign")
        let unknownDelete = UUID()
        var document = KithDocument(people: [mine, foreign], deletionDates: [unknownDelete: .now],
                                    hubAccountID: "a", hubRecordOwners: [foreign.id: "b"])
        try KithSyncProjection.approve(&document, owner: "a")
        XCTAssertEqual(try KithSyncProjection.records(document, transport: "hub").map(\.name), [mine.id.uuidString.lowercased()])
        XCTAssertEqual(document.hubRecordOwners[foreign.id], "b")
        XCTAssertNil(document.hubRecordOwners[unknownDelete])
        document.people[0].standingNotes = "Cloud change awaiting approval"
        XCTAssertTrue(try KithSyncProjection.records(document, transport: "hub").isEmpty)
        XCTAssertEqual(document.hubRecordOwners[mine.id], "a")
    }

    func testNoteCannotExportUnapprovedParentDetails() throws {
        let person = Person(name: "Private name")
        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Approved note")
        var document = KithDocument(people: [person], entries: [note], hubAccountID: "a")
        let fingerprints = try KithSyncProjection.fingerprints(document)
        document.hubRecordOwners[note.id] = "a"
        document.hubApprovedFingerprints[note.id] = fingerprints[note.id]
        XCTAssertTrue(try KithSyncProjection.records(document, transport: "hub").isEmpty)
    }

    func testCloudChangeWaitsForApprovalAcrossReopenAndLocalEditing() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        var person = Person(name: "Approved person")
        var original = KithDocument(people: [person], hubAccountID: "a")
        try KithSyncProjection.approve(&original, owner: "a")
        try await store.save(original)
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        person.standingNotes = "New cloud text"
        let record = MirrorRecord(name: person.id.uuidString.lowercased(), modifiedAt: .now,
            payload: try JSONEncoder().encode(KithPlatformRecord.person(person)), hubOwnerID: "a")
        try await model.commitMirrorRecords([record], source: "cloudkit")
        XCTAssertEqual(model.document.hubRecordOwners[person.id], "a")
        XCTAssertTrue(try model.mirrorRecords(transportID: "hub").isEmpty)
        person.standingNotes = "Locally edited pending text"
        let saved = await model.savePerson(person)
        XCTAssertTrue(saved)
        XCTAssertTrue(try model.mirrorRecords(transportID: "hub").isEmpty)
        let reopened = AppModel(store: store, cloud: nil, mirror: nil)
        await reopened.load()
        XCTAssertTrue(try reopened.mirrorRecords(transportID: "hub").isEmpty)
        let approved = await reopened.approveLocalHubOwner("a")
        XCTAssertTrue(approved)
        XCTAssertEqual(try reopened.mirrorRecords(transportID: "hub").count, 1)
    }

    func testForeignAffiliationSurvivesCloudRestoreAndCannotBeApprovedToA() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let foreign = Person(name: "B only")
        try await model.commitMirrorRecords([
            MirrorRecord(name: foreign.id.uuidString.lowercased(), modifiedAt: .now,
                payload: try JSONEncoder().encode(KithPlatformRecord.person(foreign)), hubOwnerID: "b")
        ], source: "cloudkit")
        _ = await model.approveLocalHubOwner("a")
        XCTAssertTrue(try model.mirrorRecords(transportID: "hub").isEmpty)
        let disk = try await store.load()
        XCTAssertEqual(disk.hubRecordOwners[foreign.id], "b")
        XCTAssertEqual(try KithSyncProjection.records(disk).first?.hubOwnerID, "b")
    }

    func testCloudOwnerCollisionFailsWholeBatchAndKeepsDisk() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let person = Person(name: "A only")
        var original = KithDocument(people: [person], hubAccountID: "a")
        try KithSyncProjection.approve(&original, owner: "a")
        try await store.save(original)
        let before = try Data(contentsOf: root.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        do {
            try await model.commitMirrorRecords([
                MirrorRecord(name: person.id.uuidString.lowercased(), modifiedAt: .now, payload: nil, hubOwnerID: "b")
            ], source: "cloudkit")
            XCTFail("Foreign deletion must fail")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: root.appending(path: "people.json")), before)
        XCTAssertEqual(model.document.people.map(\.id), [person.id])
    }

    func testLocalDeleteRetainsApprovedOwnerAndCloudDeleteNeedsFreshApproval() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let local = Person(name: "Delete locally"), remote = Person(name: "Delete in cloud")
        var original = KithDocument(people: [local, remote], hubAccountID: "a")
        try KithSyncProjection.approve(&original, owner: "a")
        try await store.save(original)
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        _ = await model.deletePerson(id: local.id)
        try await model.commitMirrorRecords([
            MirrorRecord(name: remote.id.uuidString.lowercased(), modifiedAt: .now, payload: nil, hubOwnerID: "a")
        ], source: "cloudkit")
        let hub = try model.mirrorRecords(transportID: "hub")
        XCTAssertEqual(hub.map(\.name), [local.id.uuidString.lowercased()])
        XCTAssertTrue(hub.allSatisfy(\.isDeleted))
        let cloud = try model.mirrorRecords()
        XCTAssertTrue(cloud.allSatisfy { $0.hubOwnerID == "a" })
        _ = await model.approveLocalHubOwner("a")
        XCTAssertEqual(try model.mirrorRecords(transportID: "hub").count, 2)
    }

    func testApprovalRejectsDocumentChangedSinceSelection() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = AppModel(store: KithStore(fileURL: root.appending(path: "people.json")), cloud: nil, mirror: nil)
        await model.load()
        let selected = model.document
        _ = await model.savePerson(Person(name: "Arrived after selection"))
        let approved = await model.approveLocalHubOwner("a", expected: selected)
        XCTAssertFalse(approved)
        XCTAssertNil(model.document.hubAccountID)
        XCTAssertTrue(model.document.hubRecordOwners.isEmpty)
    }
}
