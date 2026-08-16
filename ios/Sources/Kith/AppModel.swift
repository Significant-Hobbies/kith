import Foundation
import KithCore
import Observation

/// Owns the one Kith document and every action that changes it.
///
/// The phone is the working copy. Personal iCloud (private CloudKit on the
/// Sarthak Agrawal team) mirrors it when the owner is signed in. There is no
/// Kith account and no Kith server.
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
    private let cloud: KithCloudStore?

    init(store: KithStore = KithStore(), cloud: KithCloudStore? = KithCloudStore()) {
        self.store = store
        let arguments = ProcessInfo.processInfo.arguments
        self.cloud = Self.isDemoLaunch(arguments) ? nil : cloud
    }

    private static func isDemoLaunch(_ arguments: [String]) -> Bool {
        arguments.contains("--ui-demo") || arguments.contains("--fresh-demo")
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
                await syncFromCloud()
            }
        } catch {
            message = "Could not open your people."
            document = .empty
        }
    }

    func syncFromCloud() async {
        guard let cloud else { return }
        guard await cloud.availability() == .available else { return }
        do {
            if let remote = try await cloud.fetch() {
                let chosen = KithDocument.newer(document, remote)
                if chosen.savedAt != document.savedAt {
                    document = chosen
                    try await store.save(chosen)
                }
            } else if document.savedAt > .distantPast {
                try await cloud.save(document)
            }
        } catch {
            // Local notes stay usable when iCloud is signed out or unreachable.
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
        let cloud = cloud
        Task {
            do {
                try await store.save(snapshot)
                try await cloud?.save(snapshot)
            } catch {
                message = "Could not save."
            }
        }
    }
}
