import Foundation
import KithCore
import Observation

/// Owns the one Kith document and every action that changes it.
///
/// People and logs stay on the device. There is no account and no request
/// between tapping a lantern and writing a note.
@MainActor
@Observable
final class AppModel {
    private(set) var document: KithDocument = .empty
    var isLoading = true
    var selectedPersonID: UUID?
    var isAddingPerson = false
    var isShowingList = false
    var searchText = ""
    var message: String?

    private let store: KithStore

    init(store: KithStore = KithStore()) {
        self.store = store
    }

    var visiblePeople: [Person] {
        document.matchingPeople(query: searchText)
    }

    var selectedPerson: Person? {
        selectedPersonID.flatMap { document.person(id: $0) }
    }

    func load() async {
        defer { isLoading = false }
        let arguments = ProcessInfo.processInfo.arguments
        do {
            if arguments.contains("--ui-demo") {
                document = .sample
            } else if arguments.contains("--fresh-demo") {
                document = .empty
            } else {
                document = try await store.load()
            }
        } catch {
            message = "Could not open your people."
            document = .empty
        }
    }

    func savePerson(_ person: Person) {
        do {
            try document.upsert(person)
            persist()
            selectedPersonID = person.id
            isAddingPerson = false
        } catch KithError.emptyName {
            message = "A person needs a name."
        } catch {
            message = "Could not save that person."
        }
    }

    func deletePerson(id: UUID) {
        document.removePerson(id: id)
        if selectedPersonID == id { selectedPersonID = nil }
        persist()
    }

    func addEntry(_ entry: Entry) {
        do {
            try document.add(entry)
            persist()
        } catch {
            message = "Could not save that note."
        }
    }

    func deleteEntry(id: UUID) {
        document.removeEntry(id: id)
        persist()
    }

    private func persist() {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--ui-demo") || arguments.contains("--fresh-demo") {
            return
        }
        let snapshot = document
        let store = store
        Task {
            do {
                try await store.save(snapshot)
            } catch {
                message = "Could not save."
            }
        }
    }
}
