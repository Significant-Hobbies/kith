import Foundation
import KithCore
import Observation
import PersonalSyncKit

/// Owns the one Kith document and every action that changes it.
///
/// The phone is the working copy. CloudKit remains a transition mirror, while
/// an explicit Personal Platform sign-in synchronizes typed people and notes.
@MainActor
@Observable
final class AppModel {
    private(set) var document: KithDocument = .empty
    var isLoading = true
    var isOnboardingPresented = false
    private(set) var onboardingPersonID: UUID?
    var selectedPersonID: UUID?
    var isAddingPerson = false
    var isShowingList = false
    var isShowingConnection = false
    var searchText = ""
    var message: String?

    private let store: KithStore
    private let cloud: KithCloudStore?
    private let platform: PersonalPlatformConnection?
    let account: PersonalAccountModel?

    init(
        store: KithStore = KithStore(),
        cloud: KithCloudStore? = KithCloudStore(),
        platform: PersonalPlatformConnection? = AppModel.makePlatformConnection()
    ) {
        self.store = store
        self.platform = platform
        account = platform.map {
            PersonalAccountModel(identity: $0.identity, callbackScheme: "kith")
        }
        let arguments = ProcessInfo.processInfo.arguments
        self.cloud = Self.isDemoLaunch(arguments) ? nil : cloud
        if arguments.contains("--person-demo") {
            selectedPersonID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        }
    }

    private static func isDemoLaunch(_ arguments: [String]) -> Bool {
        arguments.contains("--ui-demo")
            || arguments.contains("--fresh-demo")
            || arguments.contains("--person-demo")
            || arguments.contains("--onboarding-demo")
            || arguments.contains("--onboarding-resume-demo")
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
            if arguments.contains("--ui-demo") || arguments.contains("--person-demo") {
                document = .sample
            } else if arguments.contains("--onboarding-resume-demo") {
                let person = Person(
                    id: Self.demoOnboardingPersonID,
                    name: "Leela",
                    circle: .close,
                    closeness: 4,
                    hue: .apricot
                )
                document = KithDocument(people: [person], savedAt: .now)
                onboardingPersonID = person.id
            } else if arguments.contains("--fresh-demo") {
                document = .empty
            } else if arguments.contains("--onboarding-demo") {
                document = .empty
                onboardingPersonID = nil
            } else {
                document = try await store.load()
                await syncFromCloud()
                await account?.restore()
                await syncFromPlatform()
            }
            configureOnboarding(arguments: arguments)
        } catch {
            message = "Could not open your people."
            document = .empty
        }
    }

    static let onboardingCompletionKey = "kith.onboarding.completed.v1"
    static let onboardingPersonKey = "kith.onboarding.person.v1"
    static let demoOnboardingPersonID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    var onboardingPerson: Person? {
        onboardingPersonID.flatMap { document.person(id: $0) }
    }

    static func shouldPresentOnboarding(
        document: KithDocument,
        completed: Bool,
        resumablePersonID: UUID?
    ) -> Bool {
        guard !completed else { return false }
        if document.people.isEmpty { return true }
        guard let resumablePersonID,
              document.person(id: resumablePersonID) != nil,
              document.entries(for: resumablePersonID).isEmpty else { return false }
        return true
    }

    private func configureOnboarding(arguments: [String]) {
        if arguments.contains("--fresh-demo") {
            isOnboardingPresented = false
            return
        }
        if arguments.contains("--onboarding-demo") {
            isOnboardingPresented = true
            return
        }
        if arguments.contains("--onboarding-resume-demo") {
            isOnboardingPresented = true
            return
        }
        let defaults = UserDefaults.standard
        if onboardingPersonID == nil,
           let rawID = defaults.string(forKey: Self.onboardingPersonKey) {
            onboardingPersonID = UUID(uuidString: rawID)
        }
        isOnboardingPresented = Self.shouldPresentOnboarding(
            document: document,
            completed: defaults.bool(forKey: Self.onboardingCompletionKey),
            resumablePersonID: onboardingPersonID
        )
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
        upsertPerson(person, selectAfterSave: true)
    }

    func saveOnboardingPerson(_ person: Person) {
        upsertPerson(person, selectAfterSave: false)
        guard document.person(id: person.id) != nil else { return }
        onboardingPersonID = person.id
        UserDefaults.standard.set(person.id.uuidString, forKey: Self.onboardingPersonKey)
    }

    private func upsertPerson(_ person: Person, selectAfterSave: Bool) {
        do {
            try document.upsert(person)
            persist()
            enqueue(person)
            if selectAfterSave { selectedPersonID = person.id }
            isAddingPerson = false
        } catch KithError.emptyName {
            message = "A person needs a name."
        } catch {
            message = "Could not save that person."
        }
    }

    func saveOnboardingEntry(kind: LogKind, happenedOn: Date, body: String) {
        guard let person = onboardingPerson else { return }
        addEntry(Entry(personID: person.id, kind: kind, happenedOn: happenedOn, body: body))
        guard !document.entries(for: person.id).isEmpty else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingCompletionKey)
        defaults.removeObject(forKey: Self.onboardingPersonKey)
        onboardingPersonID = person.id
    }

    func finishOnboarding(addAnother: Bool = false) {
        isOnboardingPresented = false
        onboardingPersonID = nil
        if addAnother { isAddingPerson = true }
    }

    func deletePerson(id: UUID) {
        let deletedIDs = [id] + document.entries.filter { $0.personID == id }.map(\.id)
        document.removePerson(id: id)
        if selectedPersonID == id { selectedPersonID = nil }
        persist()
        enqueueDeletions(deletedIDs)
    }

    func addEntry(_ entry: Entry) {
        do {
            try document.add(entry)
            persist()
            enqueue(entry)
        } catch {
            message = "Could not save that note."
        }
    }

    func deleteEntry(id: UUID) {
        document.removeEntry(id: id)
        persist()
        enqueueDeletions([id])
    }

    private func persist() {
        let arguments = ProcessInfo.processInfo.arguments
        if Self.isDemoLaunch(arguments) {
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

    func syncFromPlatform() async {
        guard let platform else { return }
        do {
            try await enqueueLocalRecords(using: platform)
            let changes = try await platform.sync.synchronize()
            guard !changes.isEmpty else { return }
            for change in changes { apply(change) }
            try await store.save(document)
        } catch {
            // The local document remains fully usable while offline.
        }
    }

    private func enqueueLocalRecords(using platform: PersonalPlatformConnection) async throws {
        for person in document.people {
            try await platform.sync.enqueue(
                recordId: person.id.uuidString.lowercased(),
                occurredAt: KithPlatformRecord.iso(person.updatedAt),
                record: KithPlatformRecord.person(person)
            )
        }
        for entry in document.entries {
            guard let person = document.person(id: entry.personID) else { continue }
            try await platform.sync.enqueue(
                recordId: entry.id.uuidString.lowercased(),
                occurredAt: KithPlatformRecord.iso(entry.happenedOn),
                record: KithPlatformRecord.interaction(entry, person: person)
            )
        }
    }

    private func enqueueDeletions(_ ids: [UUID]) {
        guard let platform, !ids.isEmpty else { return }
        Task {
            for id in ids {
                try? await platform.sync.enqueue(
                    recordId: id.uuidString.lowercased(),
                    operation: .delete,
                    occurredAt: KithPlatformRecord.iso(.now)
                )
            }
            _ = try? await platform.sync.synchronize()
        }
    }

    private func enqueue(_ person: Person) {
        guard let platform else { return }
        Task {
            do {
                try await platform.sync.enqueue(
                    recordId: person.id.uuidString.lowercased(),
                    occurredAt: KithPlatformRecord.iso(person.updatedAt),
                    record: KithPlatformRecord.person(person)
                )
                _ = try? await platform.sync.synchronize()
            } catch {}
        }
    }

    private func enqueue(_ entry: Entry) {
        guard let platform, let person = document.person(id: entry.personID) else { return }
        Task {
            do {
                try await platform.sync.enqueue(
                    recordId: entry.id.uuidString.lowercased(),
                    occurredAt: KithPlatformRecord.iso(entry.happenedOn),
                    record: KithPlatformRecord.interaction(entry, person: person)
                )
                _ = try? await platform.sync.synchronize()
            } catch {}
        }
    }

    private func apply(_ change: SyncChange) {
        switch change.operation {
        case .delete:
            guard let id = UUID(uuidString: change.id) else { return }
            if document.people.contains(where: { $0.id == id }) { document.removePerson(id: id) }
            else { document.removeEntry(id: id) }
        case .upsert:
            guard let object = change.record.objectValue,
                  let recordType = object["recordType"]?.stringValue else { return }
            if recordType == "person", let person = KithPlatformRecord.person(from: object) {
                if let index = document.people.firstIndex(where: { $0.id == person.id }) {
                    document.people[index] = person
                    document.markSaved()
                } else {
                    try? document.upsert(person)
                }
            } else if recordType == "interaction",
                      let pair = KithPlatformRecord.interaction(from: object, recordId: change.id) {
                if document.person(id: pair.person.id) == nil { try? document.upsert(pair.person) }
                if !document.entries.contains(where: { $0.id == pair.entry.id }) {
                    try? document.add(pair.entry)
                }
            }
        }
    }

    private static func makePlatformConnection() -> PersonalPlatformConnection? {
        let defaults = UserDefaults.standard
        let key = "personal-platform-device-id"
        let deviceId = defaults.string(forKey: key) ?? UUID().uuidString.lowercased()
        defaults.set(deviceId, forKey: key)
        return try? PersonalPlatformConnection(
            domain: .kith,
            keychainService: "com.significanthobbies.kith",
            supportDirectory: KithFiles.supportDirectory,
            deviceId: deviceId
        )
    }
}
