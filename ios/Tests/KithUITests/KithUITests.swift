import XCTest

@MainActor
final class KithUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    func testEmptyLaunchInvitesAddingSomeone() {
        let app = launch(["--fresh-demo"])
        XCTAssertTrue(app.staticTexts["Who do you want to keep close?"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Add someone"].exists)
    }

    func testDemoConstellationOpensAPersonAndTheirLog() {
        let app = launch(["--ui-demo"])
        let maya = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Maya Rao")).firstMatch
        XCTAssertTrue(maya.waitForExistence(timeout: 4))
        maya.tap()
        XCTAssertTrue(app.staticTexts["Maya Rao"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Walked around Cubbon after rain. She is thinking about leaving the agency."].exists)
        app.buttons["Close"].tap()
    }

    func testAddingAPersonAndANote() {
        let app = launch(["--fresh-demo"])
        let add = app.buttons["Add someone"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Leela")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Leela"].waitForExistence(timeout: 3))
        app.buttons["Add"].tap()
        let body = app.textFields["A few words"]
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        body.tap()
        body.typeText("Coffee after the market.")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Coffee after the market."].waitForExistence(timeout: 3))
    }
}
