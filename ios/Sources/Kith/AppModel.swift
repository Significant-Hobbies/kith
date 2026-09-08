import Foundation
import KithCore
import Observation
import PersonalSyncKit

/// Owns the one Kith document and every action that changes it.
///
/// The phone is the working copy. CloudKit remains a transition mirror, while
/// an explicit Hub sign-in synchronizes typed people and notes.
@MainActor
@Observable
final class AppModel {
    private(set) var document: KithDocument = .empty
    var isLoading = true
    private(set) var hasLoadedDocument = false
    private(set) var isSaving = false
    private var localWriteWaiters: [CheckedContinuation<Void, Never>] = []
    var isOnboardingPresented = false
    private(set) var isExistingOwnerOrientation = false
    private(set) var onboardingPersonID: UUID?
    var selectedPersonID: UUID?
    var isAddingPerson = false
    var isShowingList = false
    var isShowingConnection = false
    var searchText = ""
    var message: String?
    private(set) var isPlatformSyncing = false
    private var platformSyncRequested = false
    private(set) var lastPlatformSyncAt: Date?
    private(set) var platformPendingMutationCount = 0
    private(set) var platformSyncIssue: HubSyncIssue?

    private let store: KithStore
    private let cloud: (any KithCloudStorage)?
    private let platform: PersonalPlatformConnection?
    let account: PersonalAccountModel?

    init(
        store: KithStore = KithStore(),
        cloud: (any KithCloudStorage)? = KithCloudStore(),
        platform: PersonalPlatformConnection? = AppModel.makePlatformConnection()
    ) {
        self.store = store
        self.platform = platform
        lastPlatformSyncAt = UserDefaults.standard.object(forKey: Self.lastPlatformSyncKey) as? Date
        account = platform.map {
            PersonalAccountModel(identity: $0.identity, callbackScheme: "kith")
        }
        let arguments = ProcessInfo.processInfo.arguments
        self.cloud = Self.isDemoLaunch(arguments) ? nil : cloud
        if arguments.contains("--person-demo") {
            selectedPersonID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        }
        if arguments.contains("--sync-status-demo") {
            isShowingConnection = true
            platformPendingMutationCount = 2
            lastPlatformSyncAt = nil
        }
    }

    private static func isDemoLaunch(_ arguments: [String]) -> Bool {
        arguments.contains("--ui-demo")
            || arguments.contains("--fresh-demo")
            || arguments.contains("--person-demo")
            || arguments.contains("--onboarding-demo")
            || arguments.contains("--onboarding-resume-demo")
            || arguments.contains("--sync-status-demo")
    }

    var visiblePeople: [Person] {
        document.matchingPeople(query: searchText)
    }

    var selectedPerson: Person? {
        selectedPersonID.flatMap { document.person(id: $0) }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let arguments = ProcessInfo.processInfo.arguments
        do {
            if arguments.contains("--sync-status-demo") {
                document = .empty
            } else if arguments.contains("--ui-demo") || arguments.contains("--person-demo") {
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
            }
            hasLoadedDocument = true
            configureOnboarding(arguments: arguments)
            // Local people and notes are ready even if optional network work
            // stalls. Do not leave RootView behind its loading screen.
            isLoading = false
            if !Self.isDemoLaunch(arguments) {
                await syncFromCloud()
                await account?.restore()
                await syncFromPlatform()
            }
        } catch {
            hasLoadedDocument = false
            message = "Could not open your people. Your saved file has not been changed. Try opening it again."
        }
    }

    static let onboardingCompletionKey = "kith.illustrated-onboarding.seen.v1"
    static let onboardingPersonKey = "kith.onboarding.person.v1"
    static let lastPlatformSyncKey = "kith.hub.last-sync.v1"
    static let demoOnboardingPersonID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    var onboardingPerson: Person? {
        onboardingPersonID.flatMap { document.person(id: $0) }
    }

    static func shouldPresentOnboarding(
        document: KithDocument,
        completed: Bool,
        resumablePersonID: UUID?
    ) -> Bool {
        !completed
    }

    static func isExistingOwnerOrientation(
        document: KithDocument,
        resumablePersonID: UUID?
    ) -> Bool {
        guard !document.people.isEmpty else { return false }
        guard let resumablePersonID,
              document.person(id: resumablePersonID) != nil,
              document.entries(for: resumablePersonID).isEmpty else { return true }
        return false
    }

    private func configureOnboarding(arguments: [String]) {
        if arguments.contains("--fresh-demo") {
            isOnboardingPresented = false
            isExistingOwnerOrientation = false
            return
        }
        if arguments.contains("--onboarding-demo") {
            isOnboardingPresented = true
            isExistingOwnerOrientation = false
            return
        }
        if arguments.contains("--onboarding-resume-demo") {
            isOnboardingPresented = true
            isExistingOwnerOrientation = false
            return
        }
        let defaults = UserDefaults.standard
        if onboardingPersonID == nil,
           let rawID = defaults.string(forKey: Self.onboardingPersonKey) {
            onboardingPersonID = UUID(uuidString: rawID)
        }
        isExistingOwnerOrientation = Self.isExistingOwnerOrientation(
            document: document,
            resumablePersonID: onboardingPersonID
        )
        isOnboardingPresented = Self.shouldPresentOnboarding(
            document: document,
            completed: defaults.bool(forKey: Self.onboardingCompletionKey),
            resumablePersonID: onboardingPersonID
        )
    }

    func syncFromCloud() async {
        guard hasLoadedDocument else { return }
        guard let cloud else { return }
        guard await cloud.availability() == .available else { return }
        do {
            if let remote = try await cloud.fetch() {
                let chosen = KithDocument.newer(document, remote)
                if chosen != document {
                    guard await commitLocal(mirror: false, { candidate in
                        candidate = KithDocument.newer(candidate, remote)
                    }) else { return }
                }
                if document != remote { try await cloud.save(document) }
            } else if document.savedAt > .distantPast {
                try await cloud.save(document)
            }
        } catch {
            // Local notes stay usable when iCloud is signed out or unreachable.
        }
    }

    @discardableResult
    func savePerson(_ person: Person) async -> Bool {
        guard await upsertPerson(person) else { return false }
        selectedPersonID = person.id
        isAddingPerson = false
        return true
    }

    @discardableResult
    func saveOnboardingPerson(_ person: Person) async -> Bool {
        guard await upsertPerson(person) else { return false }
        onboardingPersonID = person.id
        UserDefaults.standard.set(person.id.uuidString, forKey: Self.onboardingPersonKey)
        return true
    }

    private func upsertPerson(_ person: Person) async -> Bool {
        guard await commitLocal({ try $0.upsert(person) }) else { return false }
        requestPlatformSync()
        return true
    }

    @discardableResult
    func saveOnboardingEntry(kind: LogKind, happenedOn: Date, body: String) async -> Bool {
        guard let person = onboardingPerson else { return false }
        guard await addEntry(Entry(personID: person.id, kind: kind, happenedOn: happenedOn, body: body)) else {
            return false
        }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.onboardingCompletionKey)
        defaults.removeObject(forKey: Self.onboardingPersonKey)
        onboardingPersonID = person.id
        return true
    }

    func finishOnboarding(addAnother: Bool = false) {
        guard !isSaving else { return }
        UserDefaults.standard.set(true, forKey: Self.onboardingCompletionKey)
        UserDefaults.standard.removeObject(forKey: Self.onboardingPersonKey)
        isOnboardingPresented = false
        isExistingOwnerOrientation = false
        onboardingPersonID = nil
        if addAnother { isAddingPerson = true }
    }

    @discardableResult
    func deletePerson(id: UUID) async -> Bool {
        guard await commitLocal({ $0.removePerson(id: id) }) else { return false }
        if selectedPersonID == id { selectedPersonID = nil }
        requestPlatformSync()
        return true
    }

    @discardableResult
    func addEntry(_ entry: Entry) async -> Bool {
        guard await commitLocal({ try $0.add(entry) }) else { return false }
        requestPlatformSync()
        return true
    }

    @discardableResult
    func deleteEntry(id: UUID) async -> Bool {
        guard await commitLocal({ $0.removeEntry(id: id) }) else { return false }
        requestPlatformSync()
        return true
    }

    /// Publish only committed local state. Each queued mutation starts from the
    /// latest committed document, including changes arriving from synchronization.
    private func commitLocal(
        mirror: Bool = true,
        _ change: (inout KithDocument) throws -> Void
    ) async -> Bool {
        guard hasLoadedDocument else {
            message = "Your people could not be opened. Reopen them before saving; the existing file has not been changed."
            return false
        }
        if isSaving {
            await withCheckedContinuation { localWriteWaiters.append($0) }
        } else {
            isSaving = true
        }
        defer {
            if localWriteWaiters.isEmpty { isSaving = false }
            else { localWriteWaiters.removeFirst().resume() }
        }
        do {
            var candidate = document
            try change(&candidate)
            if !Self.isDemoLaunch(ProcessInfo.processInfo.arguments) {
                try await store.save(candidate)
            }
            document = candidate
            message = nil
            if mirror, let cloud {
                Task {
                    do { try await cloud.save(candidate) }
                    catch { message = "Saved on this iPhone. iCloud did not update." }
                }
            }
            return true
        } catch KithError.deletedRecord {
            message = "This person or note was deleted. Add a new person or note to start again."
        } catch KithError.emptyName {
            message = "A person needs a name."
        } catch {
            message = "Could not save on this iPhone. Please try again."
        }
        return false
    }

    func syncFromPlatform() async {
        guard hasLoadedDocument else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--sync-status-demo") else { return }
        guard let platform else { return }
        guard !isPlatformSyncing else { platformSyncRequested = true; return }
        isPlatformSyncing = true
        defer { isPlatformSyncing = false }
        platformPendingMutationCount = await platform.sync.pendingMutationCount()
        guard account?.isSignedIn == true else {
            isPlatformSyncing = false
            platformSyncIssue = nil
            return
        }
        platformSyncIssue = nil
        do {
            var attempts = 0
            repeat {
                attempts += 1
                platformSyncRequested = false
                try await enqueueLocalRecords(using: platform.sync)
                try await platform.sync.synchronize { changes in
                    try await self.commitPlatformChanges(changes)
                }
                // A conflicting remote upsert can replace the delete fingerprint.
                // Re-stage saved deletions at the newly learned server version.
                try await enqueueDeletionRecords(using: platform.sync)
                let pending = await platform.sync.pendingMutationCount()
                if pending > 0 { platformSyncRequested = true }
                if attempts >= 3, platformSyncRequested { throw KithSyncCommitError.retryRequired }
            } while platformSyncRequested
            platformPendingMutationCount = await platform.sync.pendingMutationCount()
            let syncedAt = Date()
            lastPlatformSyncAt = syncedAt
            UserDefaults.standard.set(syncedAt, forKey: Self.lastPlatformSyncKey)
        } catch {
            platformPendingMutationCount = await platform.sync.pendingMutationCount()
            platformSyncIssue = HubSyncIssue(error: error)
        }
    }

    /// Throw until the app's atomic save succeeds so the Hub cursor cannot
    /// acknowledge records missing from this phone. Replaying a batch is safe.
    func commitPlatformChanges(_ changes: [SyncChange]) async throws {
        guard await commitLocal(mirror: false, { candidate in
            for change in changes { Self.apply(change, to: &candidate) }
        }) else { throw KithSyncCommitError.localSaveFailed }
    }

    func refreshPlatformStatus() async {
        guard !ProcessInfo.processInfo.arguments.contains("--sync-status-demo") else { return }
        guard let platform else { return }
        platformPendingMutationCount = await platform.sync.pendingMutationCount()
    }

    func enqueueLocalRecords(using sync: PersonalSyncRuntime) async throws {
        let snapshot = document
        try await enqueueDeletionRecords(using: sync)
        for person in snapshot.people where snapshot.deletionDates[person.id] == nil {
            try await sync.enqueue(
                recordId: person.id.uuidString.lowercased(),
                occurredAt: KithPlatformRecord.iso(person.updatedAt),
                record: KithPlatformRecord.person(person)
            )
        }
        for entry in snapshot.entries where snapshot.deletionDates[entry.id] == nil {
            guard snapshot.deletionDates[entry.personID] == nil,
                  let person = snapshot.person(id: entry.personID) else { continue }
            try await sync.enqueue(
                recordId: entry.id.uuidString.lowercased(),
                occurredAt: KithPlatformRecord.iso(entry.happenedOn),
                record: KithPlatformRecord.interaction(entry, person: person)
            )
        }
    }

    private func enqueueDeletionRecords(using sync: PersonalSyncRuntime) async throws {
        let snapshot = document
        for (id, deletedAt) in snapshot.deletionDates {
            try await sync.enqueue(
                recordId: id.uuidString.lowercased(), operation: .delete,
                occurredAt: KithPlatformRecord.iso(deletedAt)
            )
        }
    }

    private func requestPlatformSync() {
        // The saved document, including deletion markers, is the durable
        // source. A stopped task never loses an operation on the next launch.
        guard platform != nil else { return }
        Task { await syncFromPlatform() }
    }

    private static func apply(_ change: SyncChange, to document: inout KithDocument) {
        switch change.operation {
        case .delete:
            guard let id = UUID(uuidString: change.id) else { return }
            if document.people.contains(where: { $0.id == id }) { document.removePerson(id: id) }
            else { document.removeEntry(id: id) }
        case .upsert:
            guard let object = change.record.objectValue,
                  let recordType = object["recordType"]?.stringValue else { return }
            if recordType == "person", let person = KithPlatformRecord.person(from: object) {
                guard document.deletionDates[person.id] == nil else { return }
                if let index = document.people.firstIndex(where: { $0.id == person.id }) {
                    document.people[index] = person
                    document.markSaved()
                } else {
                    try? document.upsert(person)
                }
            } else if recordType == "interaction",
                      let pair = KithPlatformRecord.interaction(from: object, recordId: change.id) {
                if document.deletionDates[pair.person.id] != nil {
                    document.removeEntry(id: pair.entry.id)
                    return
                }
                guard document.deletionDates[pair.entry.id] == nil else { return }
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

enum KithSyncCommitError: Error { case localSaveFailed, retryRequired }

enum HubSyncIssue: Equatable {
    case reconnect
    case offline
    case serviceUnavailable
    case couldNotFinish

    init(error: Error) {
        if let syncError = error as? PersonalSyncError {
            switch syncError {
            case let .server(status, _):
                if status == 401 || status == 403 {
                    self = .reconnect
                } else if status >= 500 {
                    self = .serviceUnavailable
                } else {
                    self = .couldNotFinish
                }
            case .invalidResponse:
                self = .serviceUnavailable
            }
            return
        }
        if let urlError = error as? URLError,
           [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code) {
            self = .offline
            return
        }
        self = .couldNotFinish
    }

    var message: String {
        switch self {
        case .reconnect:
            "Your connection expired. Sign in again to resume Hub sync."
        case .offline:
            "Kith is offline. Your changes are safe and will retry when you reconnect."
        case .serviceUnavailable:
            "The Hub is temporarily unavailable. Your changes are safe on this iPhone."
        case .couldNotFinish:
            "Hub sync could not finish. Your changes are safe and ready to retry."
        }
    }
}
