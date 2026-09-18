import Contacts
import Foundation
import KithCore
import XCTest

@testable import Kith

@MainActor
final class KithContactImportTests: XCTestCase {
    private func contact(
        given: String = "",
        family: String = "",
        birthday: DateComponents? = nil,
        phone: String? = nil,
        email: String? = nil,
        organization: String = "",
        city: String? = nil,
        state: String = ""
    ) -> CNMutableContact {
        let contact = CNMutableContact()
        contact.givenName = given
        contact.familyName = family
        contact.organizationName = organization
        contact.birthday = birthday
        if let phone {
            contact.phoneNumbers = [CNLabeledValue(
                label: CNLabelPhoneNumberMobile,
                value: CNPhoneNumber(stringValue: phone)
            )]
        }
        if let email {
            contact.emailAddresses = [CNLabeledValue(
                label: CNLabelHome,
                value: email as NSString
            )]
        }
        if let city {
            let address = CNMutablePostalAddress()
            address.city = city
            address.state = state
            contact.postalAddresses = [CNLabeledValue(label: CNLabelHome, value: address)]
        }
        return contact
    }

    private func makeModel() async throws -> (AppModel, KithStore, URL) {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let store = KithStore(fileURL: root.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        return (model, store, root)
    }

    func testContactMapsToPersonWithDefaultsAndDetails() {
        let imported = ContactImport.person(from: contact(
            given: "Leela", family: "Rao",
            birthday: DateComponents(year: 1990, month: 3, day: 14),
            phone: "+91 98000 12345", email: "leela@example.com"
        ))
        XCTAssertEqual(imported?.name, "Leela Rao")
        XCTAssertEqual(imported?.circle, .friends)
        XCTAssertEqual(imported?.closeness, 3)
        XCTAssertEqual(
            imported?.standingNotes,
            "Phone: +91 98000 12345\nEmail: leela@example.com"
        )
        let birthday = imported?.birthday
        let components = Calendar.current.dateComponents([.year, .month, .day], from: birthday!)
        XCTAssertEqual(components.year, 1990)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.day, 14)
    }

    func testYearlessBirthdayKeepsMonthDayAndDisplaysWithoutYear() {
        let imported = ContactImport.person(from: contact(
            given: "Sam", birthday: DateComponents(month: 11, day: 2)
        ))
        let birthday = imported?.birthday
        XCTAssertNotNil(birthday)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: birthday!)
        XCTAssertEqual(components.year, ContactImport.yearlessBirthdayYear)
        XCTAssertEqual(components.month, 11)
        XCTAssertEqual(components.day, 2)
        XCTAssertEqual(ContactImport.birthdayText(birthday!), "November 2")
        let full = Calendar.current.date(from: DateComponents(year: 1988, month: 11, day: 2))!
        XCTAssertEqual(ContactImport.birthdayText(full), "November 2, 1988")
    }

    func testOrganizationWithoutPersonNameImportsByOrganizationName() {
        let contact = CNMutableContact()
        contact.contactType = .organization
        contact.organizationName = "Cubbon Reads"
        XCTAssertEqual(ContactImport.person(from: contact)?.name, "Cubbon Reads")
    }

    func testImportPrefillsWorkAndPlaceDetails() {
        let imported = ContactImport.person(from: contact(
            given: "Dev", family: "Anand",
            organization: "The Agency", city: "Bengaluru", state: "Karnataka"
        ))
        let details = Dictionary(uniqueKeysWithValues: (imported?.details ?? []).map { ($0.key, $0.value) })
        XCTAssertEqual(details[Person.detailKeyWhereTheyWork], "The Agency")
        XCTAssertEqual(details[Person.detailKeyWhereTheyAre], "Bengaluru, Karnataka")
    }

    func testOrganizationContactDoesNotSelfReportAWorkplace() {
        let contact = CNMutableContact()
        contact.contactType = .organization
        contact.organizationName = "Cubbon Reads"
        XCTAssertTrue((ContactImport.person(from: contact)?.details ?? []).isEmpty)
    }

    func testNamelessContactsAreSkipped() {
        XCTAssertNil(ContactImport.person(from: CNMutableContact()))
        let plan = ContactImport.plan(contacts: [CNMutableContact()], existing: [])
        XCTAssertTrue(plan.people.isEmpty)
        XCTAssertEqual(plan.skipped, 1)
    }

    func testImportCommitsAllNewContactsAndSkipsDuplicates() async throws {
        let (model, store, root) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        await model.savePerson(Person(name: "Maya Rao", closeness: 4))
        model.message = nil
        let contacts = [
            contact(given: "Maya", family: "Rao"),
            contact(given: "  maya   rao "),
            contact(given: "Leela", family: "Kapoor", phone: "+91 11111 22222"),
            contact(family: "Iyer"),
            CNMutableContact(),
        ]
        let imported = await model.importContacts(contacts)
        XCTAssertTrue(imported)
        XCTAssertEqual(model.document.people.count, 3)
        XCTAssertNotNil(model.document.people.first { $0.name == "Leela Kapoor" })
        XCTAssertNotNil(model.document.people.first { $0.name == "Iyer" })
        XCTAssertEqual(model.message, "Added 2 people · skipped 3")
        let reloaded = try await store.load()
        XCTAssertEqual(reloaded.people.count, 3)
        XCTAssertEqual(
            reloaded.people.first { $0.name == "Leela Kapoor" }?.standingNotes,
            "Phone: +91 11111 22222"
        )
    }

    func testImportWithOnlyDuplicatesAddsNoOne() async throws {
        let (model, _, root) = try await makeModel()
        defer { try? FileManager.default.removeItem(at: root) }
        await model.savePerson(Person(name: "Maya Rao", closeness: 4))
        model.message = nil
        let imported = await model.importContacts([contact(given: "Maya", family: "Rao")])
        XCTAssertFalse(imported)
        XCTAssertEqual(model.document.people.count, 1)
        XCTAssertEqual(model.message, "No one was added — those contacts are already here or have no name.")
    }

    func testFailedImportSaveLeavesDocumentUnchanged() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let blocker = root.appending(path: "blocked")
        try Data("not a directory".utf8).write(to: blocker)
        let store = KithStore(fileURL: blocker.appending(path: "people.json"))
        let model = AppModel(store: store, cloud: nil, mirror: nil)
        await model.load()
        let imported = await model.importContacts([contact(given: "Leela")])
        XCTAssertFalse(imported)
        XCTAssertTrue(model.document.people.isEmpty)
        XCTAssertEqual(model.message, "Could not save on this iPhone. Please try again.")
    }
}
