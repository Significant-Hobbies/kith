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
        XCTAssertTrue(app.staticTexts.ci("Who do you want to keep close?").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons.ci("Add someone").exists)
    }

    func testAddMenuOffersManualEntryAndContactImport() {
        let app = launch(["--ui-demo", "-kith.illustrated-onboarding.seen.v1", "YES"])
        let add = app.buttons.ci("add-person")
        XCTAssertTrue(add.waitForExistence(timeout: 4))
        add.tap()
        XCTAssertTrue(app.buttons.ci("add-from-contacts").waitForExistence(timeout: 3))
        app.buttons.ci("add-manual").tap()
        XCTAssertTrue(app.textFields.ci("Name").waitForExistence(timeout: 3))
    }

    func testDemoConstellationOpensAPersonAndTheirLog() {
        let app = launch(["--ui-demo", "-kith.illustrated-onboarding.seen.v1", "YES"])
        let maya = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Maya Rao")).firstMatch
        XCTAssertTrue(maya.waitForExistence(timeout: 4))
        maya.tap()
        XCTAssertTrue(app.staticTexts.ci("Maya Rao").waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.ci("Walked around Cubbon after rain. She is thinking about leaving the agency.").exists)
        app.buttons.ci("Close").tap()
    }

    func testAddingAPersonAndANote() {
        let app = launch(["--fresh-demo"])
        let add = app.buttons.ci("Add someone").firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()
        let name = app.textFields.ci("Name")
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Leela")
        app.buttons.ci("Save").tap()
        XCTAssertTrue(app.staticTexts.ci("Leela").waitForExistence(timeout: 3))
        app.buttons.ci("Add").tap()
        let body = app.textFields.ci("A few words")
        XCTAssertTrue(body.waitForExistence(timeout: 3))
        body.tap()
        body.typeText("Coffee after the market.")
        app.buttons.ci("Save").tap()
        XCTAssertTrue(app.staticTexts.ci("Coffee after the market.").waitForExistence(timeout: 3))
    }

    func testPersonAndMemoryEditsAndDeletionsSurviveRelaunch() {
        let arguments = ["--ui-persistence-store", UUID().uuidString,
                         "-kith.illustrated-onboarding.seen.v1", "YES"]
        let app = launch(arguments)
        defer {
            app.terminate()
            app.launchArguments = arguments + ["--ui-persistence-cleanup"]
            app.launch()
            XCTAssertTrue(app.buttons.ci("Add someone").firstMatch.waitForExistence(timeout: 5))
            app.terminate()
        }
        let addButton = app.buttons.ci("Add someone").firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        let name = app.textFields.ci("Name")
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        name.tap()
        name.typeText("Synthetic Leela")
        app.buttons.ci("Closeness 4").tap()
        app.buttons.ci("Save").tap()
        XCTAssertTrue(app.staticTexts.ci("Synthetic Leela").waitForExistence(timeout: 4))

        for note in ["Keep this synthetic memory.", "Delete this synthetic memory."] {
            app.buttons.ci("Add").tap()
            let body = app.textFields.ci("A few words")
            XCTAssertTrue(body.waitForExistence(timeout: 3))
            body.tap()
            body.typeText(note)
            app.buttons.ci("Save").tap()
            XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 4))
        }
        app.buttons.ci("Edit").tap()
        XCTAssertTrue(name.waitForExistence(timeout: 3))
        app.buttons.ci("Closeness 5").tap()
        app.buttons.ci("Save").tap()
        XCTAssertTrue(app.staticTexts.ci("Synthetic Leela").waitForExistence(timeout: 4))

        func reopenPerson() {
            app.terminate()
            app.launchArguments = arguments
            app.launch()
            let person = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Synthetic Leela")).firstMatch
            XCTAssertTrue(person.waitForExistence(timeout: 5))
            person.tap()
            XCTAssertTrue(app.staticTexts.ci("Synthetic Leela").waitForExistence(timeout: 3))
            XCTAssertTrue(app.staticTexts.ci("Friends · closeness 5").exists)
        }
        reopenPerson()
        XCTAssertTrue(app.staticTexts.ci("Keep this synthetic memory.").exists)
        let removedNote = app.staticTexts.ci("Delete this synthetic memory.")
        if !removedNote.isHittable { app.swipeUp() }
        XCTAssertTrue(removedNote.waitForExistence(timeout: 3))
        removedNote.press(forDuration: 1)
        let delete = app.buttons.ci("Delete")
        XCTAssertTrue(delete.waitForExistence(timeout: 3))
        delete.tap()
        XCTAssertTrue(removedNote.waitForNonExistence(timeout: 4))
        reopenPerson()
        XCTAssertTrue(app.staticTexts.ci("Keep this synthetic memory.").exists)
        XCTAssertFalse(app.staticTexts.ci("Delete this synthetic memory.").exists)
        let retained = XCTAttachment(screenshot: app.screenshot())
        retained.name = "Synthetic person and memory after relaunch"
        retained.lifetime = .keepAlways
        add(retained)

        let removePerson = app.buttons.ci("Remove Synthetic")
        if !removePerson.isHittable { app.swipeUp() }
        XCTAssertTrue(removePerson.waitForExistence(timeout: 3))
        removePerson.tap()
        app.buttons.ci("Remove").tap()
        XCTAssertTrue(app.buttons.ci("Add someone").firstMatch.waitForExistence(timeout: 4))
        app.terminate()
        app.launchArguments = arguments
        app.launch()
        XCTAssertTrue(app.buttons.ci("Add someone").firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Synthetic Leela")).firstMatch.exists)
        let empty = XCTAttachment(screenshot: app.screenshot())
        empty.name = "Deleted synthetic person stays removed after relaunch"
        empty.lifetime = .keepAlways
        add(empty)
    }

    func testOnboardingCreatesARealPersonAndDatedEntry() {
        let app = launch(["--onboarding-demo"])

        XCTAssertTrue(app.staticTexts.ci("The people you keep close.").waitForExistence(timeout: 4))
        let name = app.textFields.ci("Their name")
        name.tap()
        name.typeText("Leela")
        app.buttons.ci("Closeness 4").tap()
        app.buttons.ci("Place in my constellation").tap()

        XCTAssertTrue(app.navigationBars.ci("One thing to keep").waitForExistence(timeout: 4))
        let note = app.textFields.ci("A few words")
        note.tap()
        note.typeText("Coffee after the market.")
        app.buttons.ci("Save this memory").tap()

        XCTAssertTrue(app.staticTexts.ci("Your constellation has begun.").waitForExistence(timeout: 4))
        app.buttons.ci("Open Kith").tap()
        let leela = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Leela")).firstMatch
        XCTAssertTrue(leela.waitForExistence(timeout: 4))
        leela.tap()
        XCTAssertTrue(app.staticTexts.ci("Coffee after the market.").waitForExistence(timeout: 4))
    }

    func testOnboardingCanOpenKithWithoutCreatingAPerson() {
        let app = launch(["--onboarding-demo"])

        let openKith = app.buttons.ci("Open Kith first")
        XCTAssertTrue(openKith.waitForExistence(timeout: 4))
        openKith.tap()

        XCTAssertTrue(app.staticTexts.ci("Who do you want to keep close?").waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons.ci("Add someone").exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Leela")).firstMatch.exists)
    }

    func testOnboardingResumesAtContextForItsSavedPerson() {
        let app = launch(["--onboarding-resume-demo"])

        XCTAssertTrue(app.navigationBars.ci("One thing to keep").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.ci("Leela").exists)
        XCTAssertFalse(app.textFields.ci("Their name").exists)
    }

    func testExistingPeopleBypassOnboarding() {
        let app = launch(["--ui-demo", "-kith.illustrated-onboarding.seen.v1", "YES"])

        XCTAssertTrue(app.staticTexts.ci("Kith").waitForExistence(timeout: 4))
        XCTAssertFalse(app.staticTexts.ci("The people you keep close.").exists)
    }

    func testConnectionExplainsStorageRolesAndWaitingChanges() {
        let app = launch(["--sync-status-demo"])

        XCTAssertTrue(app.navigationBars.ci("Connection").waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts.ci("Saved on this iPhone").exists)
        XCTAssertTrue(app.staticTexts.ci("Kept across your Apple devices").exists)
        XCTAssertTrue(app.staticTexts.ci("Visible in your private Hub").exists)
        XCTAssertTrue(app.staticTexts.ci("2 changes are waiting safely").exists)
    }
}
