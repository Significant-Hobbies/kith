import Foundation
import KithCore
import PersonalSyncKit
import XCTest
@testable import Kith

@MainActor
final class KithCallerSyncTests: XCTestCase {
    func testCloudArrivalCannotReachHubUntilExplicitContentApproval() async throws {
        let person = Person(name: "Cloud-only private person")
        let record = MirrorRecord(name: person.id.uuidString.lowercased(), modifiedAt: .now,
                                  payload: try JSONEncoder().encode(KithPlatformRecord.person(person)))
        let f = try CallerFixture(cloudRecords: [record])
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        let approval = Task { await f.model.approvePlatformAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        // Arrive after the user's approval snapshot, through the next transport.
        f.released.continuation.finish()
        await approval.value
        await f.model.syncFromPlatform()
        XCTAssertNotNil(f.model.document.person(id: person.id))
        let firstNames = await f.requests.names()
        XCTAssertFalse(firstNames.contains(record.name))
        XCTAssertTrue(f.model.needsPlatformApproval)
        await f.model.approvePlatformAccount()
        let approvedNames = await f.requests.names()
        XCTAssertTrue(approvedNames.contains(record.name))
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubRecordOwners[person.id], "a")
        XCTAssertNotNil(reopened.hubApprovedFingerprints[person.id])
    }

    func testTrustedHubParentDeletionKeepsChildApprovalAndRejectsPendingChild() async throws {
        for pendingChild in [false, true] {
            let f = try CallerFixture()
            defer { f.cleanup() }
            await f.tokens.save("account-a")
            await f.model.load()
            let approval = Task { await f.model.approvePlatformAccount() }
            await fulfillment(of: [f.entered], timeout: 5)
            f.released.continuation.finish()
            await approval.value
            let person = try XCTUnwrap(f.model.document.people.first)
            let note = Entry(personID: person.id, kind: .note, happenedOn: .now, body: "Retain child")
            let verified = try await f.connection.identity.verifiedSyncAccount()
            if pendingChild {
                try await f.model.commitMirrorRecords([
                    MirrorRecord(name: note.id.uuidString.lowercased(), modifiedAt: .now,
                        payload: try JSONEncoder().encode(KithPlatformRecord.interaction(note, person: person)))
                ], source: "cloudkit")
            } else {
                try await f.model.commitMirrorRecords([
                    MirrorRecord(name: note.id.uuidString.lowercased(), modifiedAt: .now,
                        payload: try JSONEncoder().encode(KithPlatformRecord.interaction(note, person: person)))
                ], pass: f.model.makeMirrorPass(account: verified), source: "hub")
            }
            let pass = f.model.makeMirrorPass(account: verified)
            let deletion = MirrorRecord(name: person.id.uuidString.lowercased(), modifiedAt: .now, payload: nil)
            do {
                try await f.model.commitMirrorRecords([deletion], pass: pass, source: "hub")
                XCTAssertFalse(pendingChild)
                let records = try f.model.mirrorRecords(transportID: "hub")
                XCTAssertTrue(records.contains { $0.name == note.id.uuidString.lowercased() && $0.isDeleted })
                try await f.model.commitMirrorRecords([deletion], pass: pass, source: "hub")
            } catch {
                XCTAssertTrue(pendingChild)
                XCTAssertNotNil(f.model.document.person(id: person.id))
                XCTAssertTrue(f.model.document.entries.contains { $0.id == note.id })
            }
        }
    }

    func testAccountSwitchMidSyncKeepsBoundDocumentAndBlocksPushToNewAccount() async throws {
        let f = try CallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        let approval = Task { await f.model.approvePlatformAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        XCTAssertEqual(f.model.document.hubAccountID, "a")
        await f.tokens.save("account-b")
        await f.model.account?.restore()
        f.released.continuation.finish()
        await approval.value
        await f.model.approvePlatformAccount()
        await f.model.syncFromPlatform(recoverMissingRecords: true)
        XCTAssertEqual(f.model.account?.session?.userId, "b")
        XCTAssertEqual(f.model.document.hubAccountID, "a")
        // An account switch invalidates the held response before committing
        // any data or advancing the original account's receipt.
        XCTAssertTrue(f.model.document.people.isEmpty)
        XCTAssertNil(f.model.lastPlatformSyncAt)
        let requests = await f.requests.snapshot()
        XCTAssertTrue(requests.isEmpty, "No mutation may be pushed to the switched account")
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
        XCTAssertTrue(reopened.people.isEmpty)
        let pending = try await f.runtime.unpushedCount(
            transportID: "hub", records: f.model.mirrorRecords()
        )
        XCTAssertEqual(pending, 0, "The stale pull was never committed")
    }

    func testApprovalFailedDownloadCommitAndRetrySurviveReopen() async throws {
        let f = try CallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        let approval = Task { await f.model.approvePlatformAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        let file = f.root.appending(path: "people.json")
        let backup = f.root.appending(path: "retained.json")
        try FileManager.default.moveItem(at: file, to: backup)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
        f.released.continuation.finish()
        await approval.value
        XCTAssertTrue(f.model.document.people.isEmpty)
        XCTAssertNil(f.model.lastPlatformSyncAt)
        XCTAssertNotNil(f.model.platformSyncIssue)
        // The pull token stays at its start: an uncommitted download is never
        // acknowledged, so the next pass re-fetches the same page.
        let store = try MirrorBookkeepingStore(fileURL: f.root.appending(path: "sync/mirror.json"))
        let tokenAfterFail = try await store.load().pullTokens["hub"]
        XCTAssertNil(tokenAfterFail)
        try FileManager.default.removeItem(at: file)
        try FileManager.default.moveItem(at: backup, to: file)
        await f.model.syncFromPlatform(recoverMissingRecords: true)
        XCTAssertEqual(f.model.document.people.map(\.name), ["Synthetic remote person"])
        XCTAssertNotNil(f.model.lastPlatformSyncAt)
        XCTAssertNotNil(f.model.platformRecoveryNotice)
        XCTAssertNil(f.model.platformSyncIssue)
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
        XCTAssertEqual(reopened.people.map(\.name), ["Synthetic remote person"])
        let token = try await store.load().pullTokens["hub"]
        XCTAssertEqual(token.map { String(decoding: $0, as: UTF8.self) }, "10")
    }

    func testMalformedDownloadKeepsRecoveryFailureVisibleWithoutSuccessReceipt() async throws {
        // The pulled record's personId disagrees with its Hub record ID, so
        // the download is malformed: it must commit nothing, stay
        // unacknowledged, and never earn a recovery success receipt.
        let f = try CallerFixture(pullRecord: #"{"recordType":"person","personId":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","personName":"Mismatched remote person","circle":"close","closeness":4,"hue":"clay","createdAt":"2026-09-09"}"#)
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        let approval = Task { await f.model.approvePlatformAccount() }
        await fulfillment(of: [f.entered], timeout: 5)
        f.released.continuation.finish()
        await approval.value
        XCTAssertEqual(f.model.document.hubAccountID, "a")
        XCTAssertTrue(f.model.document.people.isEmpty, "The malformed pull must commit nothing")
        XCTAssertNil(f.model.lastPlatformSyncAt)
        XCTAssertNotNil(f.model.platformSyncIssue)
        await f.model.syncFromPlatform(recoverMissingRecords: true)
        XCTAssertNil(
            f.model.platformRecoveryNotice,
            "A failed recovery must not publish a success receipt"
        )
        XCTAssertNotNil(f.model.platformSyncIssue)
        XCTAssertNil(f.model.lastPlatformSyncAt)
        let persisted = try await f.store.load()
        XCTAssertEqual(persisted.hubAccountID, "a")
        XCTAssertTrue(persisted.people.isEmpty)
        let bookkeeping = try MirrorBookkeepingStore(fileURL: f.root.appending(path: "sync/mirror.json"))
        let pullToken = try await bookkeeping.load().pullTokens["hub"]
        XCTAssertNil(pullToken, "The malformed pull stays unacknowledged so the batch retries")
    }
}

private actor CallerTokens: PersonalBearerTokenStore {
    private var token: String?
    func load() -> String? { token }
    func save(_ token: String) { self.token = token }
    func delete() { token = nil }
}

private actor CallerRequests {
    private var pushes: [String] = []
    private var pushedNames: [String] = []
    func record(_ token: String, names: [String]) { pushes.append(token); pushedNames += names }
    func names() -> [String] { pushedNames }
    func snapshot() -> [String] { pushes }
}

private final class CallerProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) async -> String)?
    static func body(_ request: URLRequest) -> Data {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return Data() }
        stream.open()
        defer { stream.close() }
        var bytes = [UInt8](repeating: 0, count: 4096)
        var data = Data()
        while stream.hasBytesAvailable {
            let count = stream.read(&bytes, maxLength: bytes.count)
            guard count > 0 else { break }
            data.append(contentsOf: bytes.prefix(count))
        }
        return data
    }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task {
            guard let handler = Self.handler else { return }
            let body = await handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@MainActor
private final class CallerFixture {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let tokens = CallerTokens()
    let requests = CallerRequests()
    let entered = XCTestExpectation(description: "Actual caller reaches held pull")
    let released = AsyncStream<Void>.makeStream()
    let session: URLSession
    let runtime: MirrorRuntime
    let connection: PersonalMirrorConnection
    let store: KithStore
    let model: AppModel
    private let previousSuccess = UserDefaults.standard.object(forKey: AppModel.lastPlatformSyncKey)

    init(pullRecord: String? = nil, cloudRecords: [MirrorRecord] = []) throws {
        UserDefaults.standard.removeObject(forKey: AppModel.lastPlatformSyncKey)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallerProtocol.self]
        session = URLSession(configuration: configuration)
        let identity = PersonalIdentityClient(
            baseURL: URL(string: "https://identity.invalid")!,
            session: session, tokenStore: tokens
        )
        store = KithStore(fileURL: root.appending(path: "people.json"))
        let hub = HubMirrorTransport(
            domain: .kith,
            deviceId: "synthetic",
            client: PersonalSyncClient(baseURL: URL(string: "https://sync.invalid")!, session: session),
            versions: try SyncVersionStore(fileURL: root.appending(path: "sync/versions.json")),
            account: { try await identity.verifiedSyncAccount() },
            accountGate: { [store] verified in
                (try? await store.load())?.hubAccountID == verified.userID
            }
        )
        var transports: [any MirrorTransport] = [hub]
        if !cloudRecords.isEmpty { transports.append(CallerCloud(records: cloudRecords)) }
        runtime = MirrorRuntime(
            transports: transports,
            store: try MirrorBookkeepingStore(fileURL: root.appending(path: "sync/mirror.json"))
        )
        connection = PersonalMirrorConnection(
            identity: identity,
            runtime: runtime,
            account: PersonalAccountModel(
                identity: identity,
                callbackScheme: "kith",
                identityURL: URL(string: "https://identity.invalid")!
            )
        )
        model = AppModel(store: store, cloud: nil, mirror: connection)
        entered.assertForOverFulfill = false
        let entered = entered, released = released, requests = requests
        let record = pullRecord ?? #"{"recordType":"person","personId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","personName":"Synthetic remote person","circle":"close","closeness":4,"hue":"clay","createdAt":"2026-09-09"}"#
        CallerProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if request.url!.path.hasSuffix("session") {
                let id = token.contains("account-b") ? "b" : "a"
                return "{\"userId\":\"\(id)\",\"email\":\"\(id)@example.invalid\"}"
            }
            if request.url!.path.hasSuffix("push") {
                let body = try! JSONDecoder().decode(CallerPushRequest.self, from: CallerProtocol.body(request))
                await requests.record(token, names: body.mutations.map(\.id))
                let results = body.mutations.map { mutation in
                    ["idempotencyKey": mutation.idempotencyKey, "id": mutation.id,
                     "status": "accepted", "version": 2, "cursor": 11] as [String: Any]
                }
                return String(data: try! JSONSerialization.data(withJSONObject: ["results": results]), encoding: .utf8)!
            }
            entered.fulfill()
            for await _ in released.stream { break }
            return #"{"changes":[{"cursor":10,"changeId":"remote-person","domain":"kith","id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","operation":"upsert","version":1,"occurredAt":"2026-09-09","recordedAt":"2026-09-09T00:00:00.123Z","originDeviceId":"other","record":\#(record)}],"cursor":10,"hasMore":false}"#
        }
    }

    func cleanup() {
        released.continuation.finish()
        session.invalidateAndCancel()
        CallerProtocol.handler = nil
        UserDefaults.standard.set(previousSuccess, forKey: AppModel.lastPlatformSyncKey)
        try? FileManager.default.removeItem(at: root)
    }
}

private actor CallerCloud: MirrorTransport {
    nonisolated let id = "cloudkit"
    let records: [MirrorRecord]
    init(records: [MirrorRecord]) { self.records = records }
    func availability() -> MirrorAvailability { .available }
    private var pulls = 0
    func pull(since token: Data?) -> MirrorPullPage {
        pulls += 1
        return MirrorPullPage(records: pulls > 1 ? records : [], nextToken: Data("cloud".utf8))
    }
    func push(_ records: [MirrorRecord]) {}
}

private struct CallerPushRequest: Decodable { let mutations: [SyncMutation] }
