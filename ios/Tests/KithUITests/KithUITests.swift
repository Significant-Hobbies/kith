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
        let app = launch(["--ui-demo", "-kith.illustrated-onboarding.seen.v1", "YES"])
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

    func testPersonAndMemoryEditsAndDeletionsSurviveRelaunch() {
        let arguments = ["--ui-persistence-store", UUID().uuidString,
                         "-kith.illustrated-onboarding.seen.v1", "YES"]
        let app = launch(arguments)
        defer {
            app.terminate()
            app.launchArguments = arguments + ["--ui-persistence-cleanup"]
            app.launch()
            XCTAssertTrue(app.buttons["Add someone"].firstMatch.waitForExistence(timeout: 5))
            app.terminate()
        }
        let addButton = app.buttons["Add someone"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        let name = app.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Synthetic Leela")
        app.buttons["Closeness 4"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic Leela"].waitForExistence(timeout: 4))

        for note in ["Keep this synthetic memory.", "Delete this synthetic memory."] {
            app.buttons["Add"].tap()
            let body = app.textFields["A few words"]
            XCTAssertTrue(body.waitForExistence(timeout: 3))
            body.tap()
            body.typeText(note)
            app.buttons["Save"].tap()
            XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 4))
        }
        app.buttons["Edit"].tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        app.buttons["Closeness 5"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Synthetic Leela"].waitForExistence(timeout: 4))

        func reopenPerson() {
            app.terminate()
            app.launchArguments = arguments
            app.launch()
            let person = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Synthetic Leela")).firstMatch
            XCTAssertTrue(person.waitForExistence(timeout: 5))
            person.tap()
            XCTAssertTrue(app.staticTexts["Synthetic Leela"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts["Friends · closeness 5"].exists)
        }
        reopenPerson()
        XCTAssertTrue(app.staticTexts["Keep this synthetic memory."].exists)
        let removedNote = app.staticTexts["Delete this synthetic memory."]
        if !removedNote.isHittable { app.swipeUp() }
        XCTAssertTrue(removedNote.waitForExistence(timeout: 3))
        removedNote.press(forDuration: 1)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(removedNote.waitForNonExistence(timeout: 4))
        reopenPerson()
        XCTAssertTrue(app.staticTexts["Keep this synthetic memory."].exists)
        XCTAssertFalse(app.staticTexts["Delete this synthetic memory."].exists)
        let retained = XCTAttachment(screenshot: app.screenshot())
        retained.name = "Synthetic person and memory after relaunch"
        retained.lifetime = .keepAlways
        add(retained)

        let removePerson = app.buttons["Remove Synthetic"]
        if !removePerson.isHittable { app.swipeUp() }
        XCTAssertTrue(removePerson.waitForExistence(timeout: 3))
        removePerson.tap()
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.buttons["Add someone"].firstMatch.waitForExistence(timeout: 4))
        app.terminate()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons["Add someone"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Synthetic Leela")).firstMatch.exists)
        let empty = XCTAttachment(screenshot: app.screenshot())
        empty.name = "Deleted synthetic person stays removed after relaunch"
        empty.lifetime = .keepAlways
        add(empty)
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

    func testOnboardingCanOpenKithWithoutCreatingAPerson() {
        let app = launch(["--onboarding-demo"])

        let openKith = app.buttons["Open Kith first"]
        XCTAssertTrue(openKith.waitForExistence(timeout: 4))
        openKith.tap()

        XCTAssertTrue(app.staticTexts["Who do you want to keep close?"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["Add someone"].exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Leela")).firstMatch.exists)
    }

    func testOnboardingResumesAtContextForItsSavedPerson() {
        let app = launch(["--onboarding-resume-demo"])

        XCTAssertTrue(app.navigationBars["One thing to keep"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Leela"].exists)
        XCTAssertFalse(app.textFields["Their name"].exists)
    }

    func testExistingPeopleBypassOnboarding() {
        let app = launch(["--ui-demo", "-kith.illustrated-onboarding.seen.v1", "YES"])

        XCTAssertTrue(app.staticTexts["Kith"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts["The people you keep close."].exists)
    }

    func testConnectionExplainsStorageRolesAndWaitingChanges() {
        let app = launch(["--sync-status-demo"])

        XCTAssertTrue(app.navigationBars["Connection"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Saved on this iPhone"].exists)
        XCTAssertTrue(app.staticTexts["Kept across your Apple devices"].exists)
        XCTAssertTrue(app.staticTexts["Visible in your private Hub"].exists)
        XCTAssertTrue(app.staticTexts["2 changes are waiting safely"].exists)
    }
}
