import KithCore
import XCTest

@testable import Kith

@MainActor
final class KithOnboardingPresentationTests: XCTestCase {
    func testExistingOwnerGetsSafeIllustratedOrientationUntilSeen() throws {
        let person = Person(
            id: UUID(),
            name: "Rahul",
            circle: .friends,
            closeness: 4,
            hue: .clay
        )
        var document = KithDocument.empty
        try document.upsert(person)

        XCTAssertTrue(AppModel.shouldPresentOnboarding(
            document: document,
            completed: false,
            resumablePersonID: nil
        ))
        XCTAssertTrue(AppModel.isExistingOwnerOrientation(
            document: document,
            resumablePersonID: nil
        ))
        XCTAssertFalse(AppModel.shouldPresentOnboarding(
            document: document,
            completed: true,
            resumablePersonID: nil
        ))
    }
}
