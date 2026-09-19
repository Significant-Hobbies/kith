import Contacts
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
    private let storeGeneration = UUID()
    private var isReplacingStore = false
    private var localWriteWaiters: [CheckedContinuation<Void, Never>] = []
    var isOnboardingPresented = false
    private(set) var isExistingOwnerOrientation = false
    private(set) var onboardingPersonID: UUID?
    var selectedPersonID: UUID?
    var isAddingPerson = false
    var isImportingContacts = false
    var isShowingList = false
    var isShowingConnection = false
    var searchText = ""
    var message: String?
    private(set) var isPlatformSyncing = false
    private var platformSyncRequested = false
    private(set) var lastPlatformSyncAt: Date?
    private(set) var platformPendingMutationCount = 0
    private(set) var platformSyncIssue: HubSyncIssue?
    private(set) var platformRecoveryNotice: String?
    private(set) var platformAccountNotice: String?
    private(set) var cloudAccountNotice: String?

    var needsPlatformApproval: Bool {
        guard let owner = account?.session?.userId else { return false }
        return document.hubAccountID == nil || KithSyncProjection.pendingApprovalCount(document, owner: owner) > 0
    }
    var platformAccountMatches: Bool {
        guard let owner = document.hubAccountID else { return false }
        return account?.session?.userId == owner
    }

    private let store: KithStore
    /// The retired single-document iCloud mirror, kept only to import its
    /// contents once into an empty local document. Per-record CloudKit sync now
    /// goes through the mirror runtime's CloudKit transport.
    private let legacyCloud: (any KithCloudStorage)?
    private let mirror: PersonalMirrorConnection?
    let account: PersonalAccountModel?

    init(
        store: KithStore = KithStore(),
        cloud: (any KithCloudStorage)? = KithCloudStore(),
        mirror: PersonalMirrorConnection? = AppModel.makeMirrorConnection()
    ) {
        self.store = store
        self.mirror = mirror
        lastPlatformSyncAt = UserDefaults.standard.object(forKey: Self.lastPlatformSyncKey) as? Date
        account = mirror?.account
        let arguments = ProcessInfo.processInfo.arguments
        self.legacyCloud = Self.isDemoLaunch(arguments) ? nil : cloud
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
                await importLegacyCloudIfEmpty()
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

    /// One-shot import from the retired single-document iCloud mirror.
    ///
    /// It only ever fills an empty local document — the per-record CloudKit
    /// transport handles sync from here on, so the old blob is never read
    /// again once this device has data.
    func importLegacyCloudIfEmpty() async {
        guard let legacyCloud else { return }
        guard document.people.isEmpty, document.entries.isEmpty,
              document.deletionDates.isEmpty else { return }
        guard await legacyCloud.availability() == .available else { return }
        do {
            guard let remote = try await legacyCloud.fetch() else { return }
            // Merge additively inside the atomic commit: a save that landed
            // while the fetch was in flight is never overwritten, and the
            // remote's account binding only fills an unbound document.
            guard await commitLocal({ candidate in
                if let existing = candidate.hubAccountID, let incoming = remote.hubAccountID, existing != incoming {
                    throw KithError.accountMismatch
                }
                for person in remote.people where candidate.person(id: person.id) == nil {
                    try? candidate.upsert(person)
                }
                for entry in remote.entries where !candidate.entries.contains(where: { $0.id == entry.id }) {
                    try? candidate.add(entry)
                }
                for (id, deletedAt) in remote.deletionDates where candidate.deletionDates[id] == nil {
                    candidate.deletionDates[id] = deletedAt
                }
                if candidate.hubAccountID == nil { candidate.hubAccountID = remote.hubAccountID }
                // A cloud copy carries data, never this device's approval.
                // Preserve foreign affiliation, but require local consent again.
                for (id, owner) in remote.hubRecordOwners where candidate.hubRecordOwners[id] == nil {
                    candidate.hubRecordOwners[id] = owner
                }
            }, localAuthoring: false) else { return }
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

    /// Commit contacts chosen in the system picker as one atomic batch, so a
    /// failed save leaves the document untouched rather than half-imported.
    @discardableResult
    func importContacts(_ contacts: [CNContact]) async -> Bool {
        guard !contacts.isEmpty else { return true }
        let plan = ContactImport.plan(contacts: contacts, existing: document.people)
        guard !plan.people.isEmpty else {
            message = "No one was added — those contacts are already here or have no name."
            return false
        }
        guard await commitLocal({ candidate in
            for person in plan.people { try candidate.upsert(person) }
        }) else { return false }
        requestPlatformSync()
        isShowingList = false
        searchText = ""
        message = Self.importSummary(added: plan.people.count, skipped: plan.skipped)
        return true
    }

    private static func importSummary(added: Int, skipped: Int) -> String {
        let addedText = added == 1 ? "Added 1 person" : "Added \(added) people"
        return skipped > 0 ? "\(addedText) · skipped \(skipped)" : addedText
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

    /// Publish only committed local state. Each sync pass starts from the
    /// latest committed document, including changes arriving from synchronization.
    private func acquireLocalWrite() async {
        if isSaving { await withCheckedContinuation { localWriteWaiters.append($0) } }
        else { isSaving = true }
    }

    private func releaseLocalWrite() {
        if localWriteWaiters.isEmpty { isSaving = false }
        else { localWriteWaiters.removeFirst().resume() }
    }

    private func commitLocal(
        _ change: (inout KithDocument) async throws -> Void,
        localAuthoring: Bool = true
    ) async -> Bool {
        guard hasLoadedDocument else {
            message = "Your people could not be opened. Reopen them before saving; the existing file has not been changed."
            return false
        }
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        do {
            var candidate = document
            try await change(&candidate)
            if localAuthoring { try KithSyncProjection.recordLocalChanges(from: document, to: &candidate) }
            if !Self.isDemoLaunch(ProcessInfo.processInfo.arguments) {
                try await store.save(candidate)
            }
            document = candidate
            message = nil
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

    /// Atomically associate the retained document before any Hub backfill.
    /// Called only after an explicit account approval, with a verified user ID.
    func approveLocalHubOwner(_ userID: String, expected: KithDocument? = nil,
                              verified: PersonalSyncAccount? = nil) async -> Bool {
        guard !userID.isEmpty else { return false }
        return await commitLocal({ candidate in
            if let expected, candidate != expected { throw KithSyncCommitError.retryRequired }
            if let verified, let mirror { try await mirror.identity.requireCurrentAccount(verified) }
            guard candidate.hubAccountID == nil || candidate.hubAccountID == userID else {
                throw KithError.accountMismatch
            }
            try KithSyncProjection.approve(&candidate, owner: userID)
        }, localAuthoring: false)
    }

    func approvePlatformAccount() async {
        guard !isPlatformSyncing, let mirror else { return }
        let selected = document
        do {
            guard let verified = try await mirror.identity.verifiedSyncAccount(),
                  account?.session?.userId == verified.userID else { return }
            guard await approveLocalHubOwner(verified.userID, expected: selected, verified: verified) else { return }
            try await mirror.identity.requireCurrentAccount(verified)
            try await mirror.runtime.bindOwner(verified.userID)
            platformAccountNotice = nil
            await syncFromPlatform()
        } catch {
            platformAccountNotice = "Could not finish connecting this account. Saved approval stays with its original account; your local people and notes are preserved."
        }
    }

    func disconnectPlatform() async {
        platformAccountNotice = nil
        platformRecoveryNotice = nil
        lastPlatformSyncAt = nil
        UserDefaults.standard.removeObject(forKey: Self.lastPlatformSyncKey)
        await account?.signOut()
    }

    func syncFromPlatform(recoverMissingRecords: Bool = false) async {
        guard hasLoadedDocument else { return }
        guard !ProcessInfo.processInfo.arguments.contains("--sync-status-demo") else { return }
        guard let mirror else { return }
        guard !isPlatformSyncing else { platformSyncRequested = true; return }
        isPlatformSyncing = true
        platformRecoveryNotice = nil
        platformSyncIssue = nil
        defer { isPlatformSyncing = false }
        platformPendingMutationCount = (try? await mirror.runtime.unpushedCount(
            transportID: "hub", records: mirrorRecords(transportID: "hub")
        )) ?? 0
        if account?.isSignedIn == true {
            if needsPlatformApproval {
                platformAccountNotice = "Some people or notes need your approval before they can be included in this account’s Hub copy."
            } else if account?.session?.userId != document.hubAccountID {
                platformAccountNotice = "These people are connected to another Hub account. Sign in to that account to sync, or keep using Kith locally."
            }
        }
        do {
            if recoverMissingRecords { try await mirror.runtime.repullAll() }
            let verified = try? await mirror.identity.verifiedSyncAccount()
            let pass = makeMirrorPass(account: verified)
            let outcome = try await mirror.runtime.synchronize(recordsForTransport: { transportID in
                try await self.mirrorRecords(for: pass, transportID: transportID)
            }, validateLocalSnapshot: { transportID in
                try await self.validateMirrorPass(pass, transportID: transportID)
            }, applyFromTransport: { transportID, pulled in
                try await self.commitMirrorRecords(pulled, pass: pass, source: transportID)
            })
            platformPendingMutationCount = (try? await mirror.runtime.unpushedCount(
                transportID: "hub", records: mirrorRecords(transportID: "hub")
            )) ?? 0
            if outcome.transports.contains(where: { $0.transportID == "hub" && $0.failure == nil }) {
                try await validateMirrorPass(pass, transportID: "hub")
                let syncedAt = Date()
                lastPlatformSyncAt = syncedAt
                UserDefaults.standard.set(syncedAt, forKey: Self.lastPlatformSyncKey)
            }
            if let hubFailure = outcome.transports.first(where: { $0.transportID == "hub" })?.failure {
                platformSyncIssue = Self.syncIssue(forFailure: hubFailure)
            }
            // A partial pass is not a recovery: only a fully complete outcome
            // earns the success receipt, so a rejected batch stays a failure.
            if recoverMissingRecords, outcome.isComplete {
                platformRecoveryNotice = "Checked Hub and iCloud history for missing people and notes. Your existing local details were kept."
            }
        } catch {
            platformPendingMutationCount = (try? await mirror.runtime.unpushedCount(
                transportID: "hub", records: mirrorRecords(transportID: "hub")
            )) ?? 0
            if error is PersonalSyncOwnershipError {
                platformAccountNotice = "This connection needs your approval, or belongs to another account. Your people and waiting changes are preserved."
            } else { platformSyncIssue = HubSyncIssue(error: error) }
        }
    }

    private static func syncIssue(forFailure failure: String) -> HubSyncIssue? {
        if failure.contains("not signed in") { return nil }
        if failure.contains("offline") || failure.contains("network") { return .offline }
        return .couldNotFinish
    }

    /// Throw until the app's atomic save succeeds so neither remote can
    /// acknowledge records missing from this phone. A record Kith cannot apply
    /// fails the whole batch before anything is saved; replaying a batch is
    /// safe.
    func commitMirrorRecords(_ pulled: [MirrorRecord], pass: MirrorPass? = nil, source: String? = nil) async throws {
        if source == "hub", pass?.account == nil { throw KithError.accountMismatch }
        var applyError: Error?
        var committedCandidate: KithDocument?
        guard await commitLocal({ candidate in
            do {
                if let pass {
                    pass.transportID = source ?? pass.transportID
                    try await validateMirrorPassLocked(pass)
                }
                let before = try KithSyncProjection.fingerprints(candidate)
                // Parent records must precede notes that reference them.
                let ordered = pulled.sorted { Self.isPersonRecord($0) && !Self.isPersonRecord($1) }
                for record in ordered {
                    try Self.apply(record, to: &candidate, hubOwner: source == "hub" ? pass?.account?.userID : nil)
                }
                let after = try KithSyncProjection.fingerprints(candidate)
                if source != "hub" {
                    for (id, digest) in after where before[id] != digest {
                        candidate.hubApprovedFingerprints[id] = nil
                    }
                }
                committedCandidate = candidate
            } catch {
                applyError = error
                throw error
            }
        }, localAuthoring: false) else {
            if let applyError {
                // The save was never attempted — the download was unusable,
                // not unwritable. The sync issue carries the honest failure.
                message = nil
                throw applyError
            }
            throw KithSyncCommitError.localSaveFailed
        }
        if let pass, let committedCandidate {
            pass.expected = committedCandidate
            try await validateMirrorPass(pass, transportID: pass.transportID)
        }
    }

    func refreshPlatformStatus() async {
        guard !ProcessInfo.processInfo.arguments.contains("--sync-status-demo") else { return }
        guard let mirror else { return }
        platformPendingMutationCount = (try? await mirror.runtime.unpushedCount(
            transportID: "hub", records: mirrorRecords(transportID: "hub")
        )) ?? 0
    }

    /// The app's full syncable set: every live person and entry, plus a
    /// tombstone for every recorded deletion. Record names stay the bare UUID
    /// they already carry in the Hub, so existing remote records keep their
    /// identity.
    func mirrorRecords(from supplied: KithDocument? = nil, transportID: String = "cloudkit") throws -> [MirrorRecord] {
        try KithSyncProjection.records(supplied ?? document, transport: transportID)
    }

    @MainActor
    final class MirrorPass {
        var expected: KithDocument
        let generation: UUID
        let account: PersonalSyncAccount?
        var transportID = "cloudkit"
        init(document: KithDocument, generation: UUID, account: PersonalSyncAccount?) {
            expected = document
            self.generation = generation
            self.account = account
        }
    }

    func makeMirrorPass(account: PersonalSyncAccount? = nil) -> MirrorPass {
        MirrorPass(document: document, generation: storeGeneration, account: account)
    }

    private func mirrorRecords(for pass: MirrorPass, transportID: String) async throws -> [MirrorRecord] {
        guard !isReplacingStore, pass.generation == storeGeneration else {
            throw KithSyncCommitError.localSaveFailed
        }
        pass.expected = document
        pass.transportID = transportID
        return try mirrorRecords(from: pass.expected, transportID: transportID)
    }

    private func validateMirrorPass(_ pass: MirrorPass, transportID: String) async throws {
        await acquireLocalWrite()
        defer { releaseLocalWrite() }
        pass.transportID = transportID
        try await validateMirrorPassLocked(pass)
    }

    private func validateMirrorPassLocked(_ pass: MirrorPass) async throws {
        guard !isReplacingStore, pass.generation == storeGeneration, document == pass.expected else {
            throw KithSyncCommitError.localSaveFailed
        }
        if pass.transportID == "hub" {
            guard let verified = pass.account, let mirror, document.hubAccountID == verified.userID else {
                throw PersonalSyncOwnershipError.differentAccount
            }
            try await mirror.identity.requireCurrentAccount(verified)
        }
        guard !isReplacingStore, pass.generation == storeGeneration, document == pass.expected else {
            throw KithSyncCommitError.localSaveFailed
        }
    }

    private func requestPlatformSync() {
        // The saved document, including deletion markers, is the durable
        // source. A stopped task never loses an operation on the next launch.
        guard mirror != nil else { return }
        Task { await syncFromPlatform() }
    }

    /// Apply one downloaded record or fail the batch. Anything Kith cannot
    /// interpret or store throws, so the caller never acknowledges a record it
    /// silently dropped. Records already applied, or held back by a local
    /// tombstone, are intentional no-ops — not failures.
    private static func isPersonRecord(_ record: MirrorRecord) -> Bool {
        guard let data = record.payload else { return false }
        return (try? JSONDecoder().decode(JSONValue.self, from: data).objectValue?["recordType"]?.stringValue) == "person"
    }

    private static func apply(_ record: MirrorRecord, to document: inout KithDocument, hubOwner: String?) throws {
        let object = record.payload.flatMap { try? JSONDecoder().decode(JSONValue.self, from: $0).objectValue }
        let personReference = object?["personId"]?.stringValue
        let isPerson = object?["recordType"]?.stringValue == "person"
        let id = document.syncRecordNames.first(where: { $0.value == record.name })?.key
            ?? KithPlatformRecord.stableUUID(isPerson ? (personReference ?? record.name) : record.name)
        let before = try KithSyncProjection.fingerprints(document)
        let previouslyApproved = Set(before.compactMap { key, digest -> UUID? in
            guard let hubOwner, document.hubRecordOwners[key] == hubOwner,
                  document.hubApprovedFingerprints[key] == digest else { return nil }
            return key
        })
        if let incomingOwner = record.hubOwnerID {
            guard !incomingOwner.isEmpty,
                  document.hubRecordOwners[id] == nil || document.hubRecordOwners[id] == incomingOwner,
                  hubOwner == nil || hubOwner == incomingOwner else { throw KithError.accountMismatch }
            if !isPerson, let personReference {
                let parentID = KithPlatformRecord.stableUUID(personReference)
                if before[parentID] != nil, document.hubRecordOwners[parentID] != incomingOwner {
                    throw KithError.accountMismatch
                }
            }
            // CloudKit transports affiliation, never this device's consent.
            document.hubRecordOwners[id] = incomingOwner
        }
        if let hubOwner {
            guard document.hubAccountID == hubOwner else { throw KithError.accountMismatch }
            if let digest = before[id] {
                guard document.hubRecordOwners[id] == hubOwner,
                      document.hubApprovedFingerprints[id] == digest else { throw KithError.accountMismatch }
            }
            if let personReference, !isPerson {
                let parentID = KithPlatformRecord.stableUUID(personReference)
                if let digest = before[parentID] {
                    guard document.hubRecordOwners[parentID] == hubOwner,
                          document.hubApprovedFingerprints[parentID] == digest else { throw KithError.accountMismatch }
                }
            }
        }
        try KithSyncProjection.bindName(record.name, id: id, in: &document)
        if let personReference {
            try KithSyncProjection.bindReference(personReference,
                id: KithPlatformRecord.stableUUID(personReference), in: &document)
        }
        defer {
            if let hubOwner, let after = try? KithSyncProjection.fingerprints(document) {
                for (changedID, digest) in after where changedID == id || before[changedID] == nil || previouslyApproved.contains(changedID) {
                    document.hubRecordOwners[changedID] = hubOwner
                    document.hubApprovedFingerprints[changedID] = digest
                }
            }
        }
        if record.isDeleted {
            if hubOwner != nil, document.person(id: id) != nil {
                guard document.entries.filter({ $0.personID == id }).allSatisfy({ previouslyApproved.contains($0.id) }) else {
                    throw KithError.accountMismatch
                }
            }
            if document.people.contains(where: { $0.id == id }) { document.removePerson(id: id) }
            else { document.removeEntry(id: id) }
            // Keep the remote write time so the tombstone does not look
            // fresher than the delete actually was.
            document.deletionDates[id] = record.modifiedAt
            return
        }
        guard let object, let recordType = object["recordType"]?.stringValue else {
            throw KithSyncCommitError.malformedRecord(record.name)
        }
        switch recordType {
        case "person":
            guard var person = KithPlatformRecord.person(from: object), person.id == id,
                  (UUID(uuidString: record.name) == nil || UUID(uuidString: record.name) == id),
                  !document.entries.contains(where: { $0.id == id }) else {
                throw KithSyncCommitError.malformedRecord(record.name)
            }
            guard document.deletionDates[person.id] == nil else { return }
            person.updatedAt = record.modifiedAt
            if let index = document.people.firstIndex(where: { $0.id == person.id }) {
                document.people[index] = person
                document.markSaved()
            } else {
                try document.upsert(person)
            }
        case "interaction":
            guard let pair = KithPlatformRecord.interaction(from: object, recordId: record.name),
                  !pair.person.name.isEmpty,
                  pair.person.id != id,
                  !document.people.contains(where: { $0.id == id }),
                  !document.entries.contains(where: { $0.id == pair.person.id }) else {
                throw KithSyncCommitError.malformedRecord(record.name)
            }
            if document.deletionDates[pair.person.id] != nil {
                document.removeEntry(id: pair.entry.id)
                return
            }
            guard document.deletionDates[pair.entry.id] == nil else { return }
            if document.person(id: pair.person.id) == nil {
                try document.upsert(pair.person)
                if let owner = hubOwner ?? record.hubOwnerID { document.hubRecordOwners[pair.person.id] = owner }
            }
            if let index = document.entries.firstIndex(where: { $0.id == pair.entry.id }) {
                if document.entries[index] != pair.entry {
                    document.entries[index] = pair.entry
                    document.markSaved()
                }
            } else {
                try document.add(pair.entry)
            }
        default:
            throw KithSyncCommitError.unsupportedRecord(record.name)
        }
    }

    private static func makeMirrorConnection() -> PersonalMirrorConnection? {
        let defaults = UserDefaults.standard
        let key = "personal-platform-device-id"
        let deviceId = defaults.string(forKey: key) ?? UUID().uuidString.lowercased()
        defaults.set(deviceId, forKey: key)
        return try? PersonalMirrorConnection(
            domain: .kith,
            keychainService: "com.significanthobbies.kith",
            supportDirectory: KithFiles.supportDirectory,
            deviceId: deviceId,
            callbackScheme: "kith",
            cloudKitContainer: KithCloudStore.containerIdentifier,
            appendOnly: { _ in false },
            // The committed document owns the Hub binding. Until it is bound to
            // the verified account the Hub leg stays quiet; CloudKit still syncs.
            accountGate: { verified in
                (try? await KithStore().load())?.hubAccountID == verified.userID
            }
        )
    }
}

enum KithSyncCommitError: Error {
    case localSaveFailed
    case retryRequired
    case malformedRecord(String)
    case unsupportedRecord(String)
}

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
