import Foundation
import KithCore
import XCTest

@testable import Kith

@MainActor
final class KithLocalSaveTests: XCTestCase {
    func testFailedPersonSaveKeepsDocumentAndEditorUntilRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocked")
        try Data("not a directory".utf8).write(to: blocker)
        let store = KithStore(fileURL: blocker.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        model.isAddingPerson = true
        let person = Person(name: "Synthetic friend", closeness: 4, hue: .clay)
        await model.savePerson(person)
        XCTAssertNil(model.document.person(id: person.id))
        XCTAssertNil(model.selectedPersonID)
        XCTAssertTrue(model.isAddingPerson)
        XCTAssertNotNil(model.message)

        try FileManager.default.removeItem(at: blocker)
        await model.savePerson(person)
        XCTAssertEqual(model.document.person(id: person.id)?.name, person.name)
        XCTAssertFalse(model.isAddingPerson)
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.person(id: person.id)?.name, person.name)
    }

    func testFailedLoadCannotReplaceUnreadableDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "people.json")
        let original = Data("unreadable retained document".utf8)
        try original.write(to: file)
        let model = AppModel(store: KithStore(fileURL: file), cloud: nil, platform: nil)
        await model.load()
        await model.savePerson(Person(name: "Must not overwrite", closeness: 3, hue: .clay))
        XCTAssertTrue(model.document.people.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testFailedNoteAndDeletionPreservePreviousRecordsAndRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "people.json")
        let backup = root.appending(path: "retained.json")
        let store = KithStore(fileURL: file)
        let person = Person(name: "Existing friend", closeness: 4, hue: .clay)
        var original = KithDocument.empty
        try original.upsert(person)
        let existing = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Earlier memory")
        try original.add(existing)
        try await store.save(original)
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)

        let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Keep this draft")
        let added = await model.addEntry(note)
        let deletedNote = await model.deleteEntry(id: existing.id)
        let deletedPerson = await model.deletePerson(id: person.id)
        XCTAssertFalse(added)
        XCTAssertFalse(deletedNote)
        XCTAssertFalse(deletedPerson)
        XCTAssertEqual(model.document.entries.map(\.id), [existing.id])
        XCTAssertNotNil(model.document.person(id: person.id))

        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        let retried = await model.addEntry(note)
        XCTAssertTrue(retried)
        let reloaded = try await store.load()
        XCTAssertEqual(Set(reloaded.entries.map(\.id)), Set([existing.id, note.id]))
    }

    func testConcurrentSavesStartFromLatestCommittedDocument() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, platform: nil)
        await model.load()
        let first = Person(name: "First", closeness: 3, hue: .clay)
        let second = Person(name: "Second", closeness: 4, hue: .clay)
        async let one = model.savePerson(first)
        async let two = model.savePerson(second)
        let saved = await (one, two)
        XCTAssertTrue(saved.0 && saved.1)
        let reloaded = try await store.load()
        XCTAssertEqual(Set(reloaded.people.map(\.id)), Set([first.id, second.id]))
        XCTAssertEqual(Set(model.document.people.map(\.id)), Set([first.id, second.id]))
        XCTAssertFalse(model.isSaving)
    }

    func testOnboardingAdvancesOnlyAfterLocalCommit() async throws {
        let defaults = UserDefaults.standard
        let completion = defaults.object(forKey: AppModel.onboardingCompletionKey)
        let resume = defaults.object(forKey: AppModel.onboardingPersonKey)
        defer {
            defaults.set(completion, forKey: AppModel.onboardingCompletionKey)
            defaults.set(resume, forKey: AppModel.onboardingPersonKey)
        }
        defaults.removeObject(forKey: AppModel.onboardingCompletionKey)
        defaults.removeObject(forKey: AppModel.onboardingPersonKey)
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "people.json")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = AppModel(store: KithStore(fileURL: file), cloud: nil, platform: nil)
        await model.load()
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let person = Person(name: "Onboarding friend", closeness: 4, hue: .clay)
        let failed = await model.saveOnboardingPerson(person)
        XCTAssertFalse(failed)
        XCTAssertNil(model.onboardingPerson)
        XCTAssertNil(defaults.string(forKey: AppModel.onboardingPersonKey))
        try FileManager.default.removeItem(at: file)
        let saved = await model.saveOnboardingPerson(person)
        XCTAssertTrue(saved)
        let backup = root.appending(path: "retained.json")
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        let memory = await model.saveOnboardingEntry(kind: .note, happenedOn: .now, body: "Retained draft")
        XCTAssertFalse(memory)
        XCTAssertTrue(model.document.entries.isEmpty)
        XCTAssertFalse(defaults.bool(forKey: AppModel.onboardingCompletionKey))
        XCTAssertEqual(defaults.string(forKey: AppModel.onboardingPersonKey), person.id.uuidString)
    }

}
