import XCTest

@testable import Kith

@MainActor
final class KithOnboardingReplayTests: XCTestCase {
    func testReplayOpensNonDestructiveTourMode() {
        let model = AppModel(platform: nil)

        model.replayOnboarding()

        XCTAssertTrue(model.isOnboardingPresented)
        XCTAssertTrue(model.isReplayingOnboarding)
        XCTAssertNil(model.onboardingPersonID)
    }
}
