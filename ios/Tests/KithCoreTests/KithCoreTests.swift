import XCTest
@testable import KithCore

final class KithCoreTests: XCTestCase {
    func testClosenessIsClampedAndMapsToLanternSize() {
        XCTAssertEqual(Person.clampCloseness(0), 1)
        XCTAssertEqual(Person.clampCloseness(9), 5)
        XCTAssertLessThan(
            Person.lanternDiameter(closeness: 1),
            Person.lanternDiameter(closeness: 5)
        )
        XCTAssertEqual(Person(name: "Maya", closeness: 4).lanternDiameter, Person.lanternDiameter(closeness: 4))
    }

    func testEmptyNameIsRejected() {
        var document = KithDocument.empty
        XCTAssertThrowsError(try document.upsert(Person(name: "   "))) { error in
            XCTAssertEqual(error as? KithError, .emptyName)
        }
        XCTAssertTrue(document.people.isEmpty)
    }

    func testEntriesBelongToOnePersonAndSortNewestFirst() throws {
        var document = KithDocument.sample
        let maya = try XCTUnwrap(document.people.first { $0.name == "Maya Rao" })
        let older = document.lastContact(for: maya.id)

        try document.add(
            Entry(
                personID: maya.id,
                kind: .hangout,
                happenedOn: Date(timeIntervalSince1970: 1_800_000_000),
                body: "Late dinner"
            )
        )

        XCTAssertEqual(document.entries(for: maya.id).first?.body, "Late dinner")
        XCTAssertNotEqual(document.lastContact(for: maya.id), older)
        XCTAssertEqual(document.entries(for: maya.id).count, 3)
    }

    func testRemovingAPersonRemovesTheirLog() throws {
        var document = KithDocument.sample
        let maya = try XCTUnwrap(document.people.first { $0.name == "Maya Rao" })
        XCTAssertFalse(document.entries(for: maya.id).isEmpty)

        document.removePerson(id: maya.id)

        XCTAssertNil(document.person(id: maya.id))
        XCTAssertTrue(document.entries(for: maya.id).isEmpty)
    }

    func testSearchMatchesNameAndNotes() {
        let document = KithDocument.sample
        XCTAssertEqual(document.matchingPeople(query: "Maya Rao").map(\.firstName), ["Maya"])
        XCTAssertTrue(document.matchingPeople(query: "pune").contains { $0.name == "Priya Shah" })
        XCTAssertEqual(document.matchingPeople(query: "").count, document.people.count)
    }

    func testStoreRoundTripAndEmptyFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "kith-test-\(UUID().uuidString).json")
        let store = KithStore(fileURL: url)
        let loadedEmpty = try loadSync(store)
        XCTAssertEqual(loadedEmpty, .empty)

        try saveSync(store, .sample)
        let loaded = try loadSync(store)
        XCTAssertEqual(loaded.people.count, KithDocument.sample.people.count)
        XCTAssertEqual(loaded.entries.count, KithDocument.sample.entries.count)
        XCTAssertEqual(loaded.people.first?.name, KithDocument.sample.people.first?.name)
    }

    func testFutureSchemaIsRejected() {
        XCTAssertThrowsError(try KithStore.migrate(KithDocument(schemaVersion: 99))) { error in
            XCTAssertEqual(error as? KithError, .unsupportedSchema(99))
        }
    }

    func testOlderDocumentsWithoutSavedAtStillDecode() throws {
        let json = Data("""
        {"schemaVersion":1,"people":[],"entries":[]}
        """.utf8)
        let decoded = try KithStore.decode(json)
        XCTAssertEqual(decoded.savedAt, .distantPast)
    }

    func testNewerDocumentWinsForICloudMirror() {
        var older = KithDocument.sample
        older.savedAt = Date(timeIntervalSince1970: 100)
        var newer = KithDocument.empty
        newer.savedAt = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(KithDocument.newer(older, newer).savedAt, newer.savedAt)
        XCTAssertTrue(KithDocument.newer(older, newer).people.isEmpty)
    }

    private func loadSync(_ store: KithStore) throws -> KithDocument {
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do { box.value = .success(try await store.load()) }
            catch { box.value = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.value!.get()
    }

    private func saveSync(_ store: KithStore, _ document: KithDocument) throws {
        let box = ResultBox()
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                try await store.save(document)
                box.value = .success(.empty)
            } catch {
                box.value = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        _ = try box.value!.get()
    }
}

private final class ResultBox: @unchecked Sendable {
    var value: Result<KithDocument, Error>?
}
