import Foundation
import PersonalSyncKit
import XCTest
@testable import Kith

final class HubSyncIssueTests: XCTestCase {
    func testExpiredSessionsAskForReconnection() {
        XCTAssertEqual(
            HubSyncIssue(error: PersonalSyncError.server(status: 401, message: "expired")),
            .reconnect
        )
        XCTAssertEqual(
            HubSyncIssue(error: PersonalSyncError.server(status: 403, message: "scope")),
            .reconnect
        )
    }

    func testTransportAndServiceFailuresStayDistinct() {
        XCTAssertEqual(
            HubSyncIssue(error: URLError(.notConnectedToInternet)),
            .offline
        )
        XCTAssertEqual(
            HubSyncIssue(error: PersonalSyncError.server(status: 503, message: "later")),
            .serviceUnavailable
        )
        XCTAssertEqual(
            HubSyncIssue(error: PersonalSyncError.server(status: 422, message: "invalid")),
            .couldNotFinish
        )
    }
}
