import Foundation
import KithCore
import XCTest

@testable import Kith

@MainActor
final class KithPersonFieldsTests: XCTestCase {
    func testEditorSeedsTheFourEverydayDetailKeys() {
        let seeded = PersonEditor.seededDetails([])
        XCTAssertEqual(
            seeded.map(\.key),
            [
                Person.detailKeyRelationship, Person.detailKeyWhereTheyAre,
                Person.detailKeyWhereTheyWork, Person.detailKeyLastContact,
            ]
        )
        XCTAssertTrue(seeded.allSatisfy { $0.value.isEmpty })
    }

    func testEditorKeepsCustomKeysAlongsideSeededOnes() {
        let seeded = PersonEditor.seededDetails([
            PersonDetail(key: "Sister's dog", value: "Mochi"),
        ])
        XCTAssertEqual(seeded.count, 5)
        XCTAssertEqual(seeded.first?.key, "Sister's dog")
        XCTAssertEqual(seeded.first?.value, "Mochi")
    }

    func testDetailsAndListSurviveSaveAndReload() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let person = Person(
            name: "Field friend",
            details: [
                PersonDetail(key: Person.detailKeyRelationship, value: "College roommate"),
                PersonDetail(key: Person.detailKeyLastContact, value: "Coffee in June"),
            ],
            listItems: [
                PersonListItem(text: "Likes filter coffee"),
                PersonListItem(text: "Moving soon"),
            ]
        )
        let saved = await model.savePerson(person)
        XCTAssertTrue(saved)
        let reloaded = try await store.load()
        let loaded = try XCTUnwrap(reloaded.person(id: person.id))
        XCTAssertEqual(
            loaded.details.map(\.key),
            [Person.detailKeyRelationship, Person.detailKeyLastContact]
        )
        XCTAssertEqual(loaded.details.map(\.value), ["College roommate", "Coffee in June"])
        XCTAssertEqual(loaded.listItems.map(\.text), ["Likes filter coffee", "Moving soon"])
    }

    func testPersonRecordRoundTripsNewFields() throws {
        let person = Person(
            name: "Sync friend",
            details: [PersonDetail(key: Person.detailKeyWhereTheyWork, value: "Studio")],
            listItems: [PersonListItem(text: "Two sugars")]
        )
        let record = try XCTUnwrap(KithPlatformRecord.person(person).objectValue)
        let parsed = try XCTUnwrap(KithPlatformRecord.person(from: record))
        XCTAssertEqual(parsed.details.map(\.key), [Person.detailKeyWhereTheyWork])
        XCTAssertEqual(parsed.details.map(\.value), ["Studio"])
        XCTAssertEqual(parsed.listItems.map(\.text), ["Two sugars"])
    }

    func testPersonRecordWithoutNewFieldsParsesEmpty() throws {
        var record = try XCTUnwrap(
            KithPlatformRecord.person(Person(name: "Old friend")).objectValue
        )
        record.removeValue(forKey: "details")
        record.removeValue(forKey: "listItems")
        let parsed = try XCTUnwrap(KithPlatformRecord.person(from: record))
        XCTAssertTrue(parsed.details.isEmpty)
        XCTAssertTrue(parsed.listItems.isEmpty)
    }
}
