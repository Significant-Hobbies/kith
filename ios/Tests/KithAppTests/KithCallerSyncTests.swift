import Foundation
import KithCore
import PersonalSyncKit
import XCTest
@testable import Kith

@MainActor
final class KithCallerSyncTests: XCTestCase {
    func testApprovalAndHeldResponseCannotSendAQueueOrCommitARecordsAfterSwitchToB() async throws {
        let f = try CallerFixture()
        defer { f.cleanup() }
        await f.tokens.save("account-a")
        await f.model.load()
        try await f.connection.sync.enqueue(recordId: "queued-a", occurredAt: "2026-09-09", record: .string("A only"))
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
        XCTAssertTrue(f.model.document.people.isEmpty)
        XCTAssertNil(f.model.lastPlatformSyncAt)
        XCTAssertNil(f.model.platformRecoveryNotice)
        let pending = await f.connection.sync.pendingMutationCount()
        XCTAssertEqual(pending, 1)
        let requests = await f.requests.snapshot()
        XCTAssertEqual(requests, ["Bearer account-a"])
        let reopened = try await f.store.load()
        XCTAssertEqual(reopened.hubAccountID, "a")
        XCTAssertTrue(reopened.people.isEmpty)
        let cursor = try await SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json")).cursor(for: .kith)
        XCTAssertEqual(cursor, 0)
    }

    func testActualApprovalFailedDownloadCommitAndRetrySurviveReopen() async throws {
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
        let cursors = try SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json"))
        let failedCursor = await cursors.cursor(for: .kith)
        XCTAssertEqual(failedCursor, 0)
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
        let committedCursor = try await SyncCursorStore(fileURL: f.root.appending(path: "sync/personal-sync-cursors.json")).cursor(for: .kith)
        XCTAssertEqual(committedCursor, 10)
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
    func record(_ token: String) { pushes.append(token) }
    func snapshot() -> [String] { pushes }
}

private final class CallerProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) async -> String)?
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
    let connection: PersonalPlatformConnection
    let store: KithStore
    let model: AppModel
    private let previousSuccess = UserDefaults.standard.object(forKey: AppModel.lastPlatformSyncKey)

    init() throws {
        UserDefaults.standard.removeObject(forKey: AppModel.lastPlatformSyncKey)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [CallerProtocol.self]
        session = URLSession(configuration: configuration)
        let identity = PersonalIdentityClient(baseURL: URL(string: "https://identity.invalid")!, session: session, tokenStore: tokens)
        let sync = try PersonalSyncRuntime(domain: .kith, deviceId: "synthetic", supportDirectory: root.appending(path: "sync"), identity: identity, client: PersonalSyncClient(baseURL: URL(string: "https://sync.invalid")!, session: session))
        connection = PersonalPlatformConnection(identity: identity, sync: sync)
        store = KithStore(fileURL: root.appending(path: "people.json"))
        model = AppModel(store: store, cloud: nil, platform: connection)
        let entered = entered, released = released, requests = requests
        CallerProtocol.handler = { request in
            let token = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if request.url!.path.hasSuffix("session") {
                let id = token.contains("account-b") ? "b" : "a"
                return "{\"userId\":\"\(id)\",\"email\":\"\(id)@example.invalid\"}"
            }
            if request.url!.path.hasSuffix("push") {
                await requests.record(token)
                return #"{"results":[]}"#
            }
            entered.fulfill()
            for await _ in released.stream { break }
            return #"{"changes":[{"cursor":10,"changeId":"remote-person","domain":"kith","id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","operation":"upsert","version":1,"occurredAt":"2026-09-09","recordedAt":"2026-09-09","originDeviceId":"other","record":{"recordType":"person","personId":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","personName":"Synthetic remote person","circle":"close","closeness":4,"hue":"clay","createdAt":"2026-09-09"}}],"cursor":10,"hasMore":false}"#
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
