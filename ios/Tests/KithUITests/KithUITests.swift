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

    func testOnboardingCreatesARealPersonAndDatedEntry() {
        let app = launch(["--onboarding-demo"])

        XCTAssertTrue(app.staticTexts["The people you keep close."].waitForExistence(timeout: 4))
        let name = app.textFields["Their name"]
        name.tap()
        name.typeText("Leela")
        app.buttons["Closeness 4"].tap()
        app.buttons["Place in my constellation"].tap()

        XCTAssertTrue(app.navigationBars["One thing to keep"].waitForExistence(timeout: 4))
        let note = app.textFields["A few words"]
        note.tap()
        note.typeText("Coffee after the market.")
        app.buttons["Save this memory"].tap()

        XCTAssertTrue(app.staticTexts["Your constellation has begun."].waitForExistence(timeout: 4))
        app.buttons["Open Kith"].tap()
        let leela = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Leela")).firstMatch
        XCTAssertTrue(leela.waitForExistence(timeout: 4))
        leela.tap()
        XCTAssertTrue(app.staticTexts["Coffee after the market."].waitForExistence(timeout: 4))
    }

    func testOnboardingResumesAtContextForItsSavedPerson() {
        let app = launch(["--onboarding-resume-demo"])

        XCTAssertTrue(app.navigationBars["One thing to keep"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Leela"].exists)
        XCTAssertFalse(app.textFields["Their name"].exists)
    }

    func testExistingPeopleBypassOnboarding() {
        let app = launch(["--ui-demo"])

        XCTAssertTrue(app.staticTexts["Kith"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["The people you keep close."].exists)
    }
}
