import Foundation

public extension KithDocument {
    static var sample: KithDocument {
        let calendar = Calendar(identifier: .gregorian)
        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        let maya = Person(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Maya Rao",
            howWeMet: "College hostel, first week",
            circle: .close,
            closeness: 5,
            hue: .clay,
            birthday: day(1996, 3, 14),
            standingNotes: "Hates being late. Always orders the extra chai.",
            createdAt: day(2024, 1, 8),
            updatedAt: day(2026, 8, 10)
        )
        let arjun = Person(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Arjun Mehta",
            howWeMet: "Through Maya, Diwali 2018",
            circle: .family,
            closeness: 5,
            hue: .honey,
            standingNotes: "Ask about the new apartment plants.",
            createdAt: day(2024, 1, 8),
            updatedAt: day(2026, 8, 2)
        )
        let priya = Person(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Priya Shah",
            howWeMet: "Design critique group",
            circle: .friends,
            closeness: 4,
            hue: .apricot,
            birthday: day(1994, 11, 2),
            standingNotes: "Moving to Pune in October.",
            createdAt: day(2024, 6, 1),
            updatedAt: day(2026, 7, 20)
        )
        let dev = Person(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Dev Iyer",
            howWeMet: "First job, neighbouring desk",
            circle: .work,
            closeness: 3,
            hue: .sage,
            standingNotes: "Good at unblocking product arguments.",
            createdAt: day(2025, 2, 12),
            updatedAt: day(2026, 6, 4)
        )
        let nora = Person(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            name: "Nora Klein",
            howWeMet: "A wedding in Goa",
            circle: .friends,
            closeness: 2,
            hue: .rose,
            standingNotes: "Sends voice notes, almost never texts.",
            createdAt: day(2025, 9, 18),
            updatedAt: day(2026, 5, 1)
        )
        let amma = Person(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            name: "Amma",
            howWeMet: "",
            circle: .family,
            closeness: 5,
            hue: .rust,
            birthday: day(1968, 8, 22),
            standingNotes: "Call on Sunday evenings. Wants the recipe book back.",
            createdAt: day(2024, 1, 8),
            updatedAt: day(2026, 8, 14)
        )

        let people = [maya, arjun, priya, dev, nora, amma]
        let entries = [
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1")!,
                personID: maya.id,
                kind: .hangout,
                happenedOn: day(2026, 8, 10),
                body: "Walked around Cubbon after rain. She is thinking about leaving the agency.",
                createdAt: day(2026, 8, 10)
            ),
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2")!,
                personID: maya.id,
                kind: .remember,
                happenedOn: day(2026, 6, 2),
                body: "Her mum’s knee surgery is in September.",
                createdAt: day(2026, 6, 2)
            ),
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3")!,
                personID: arjun.id,
                kind: .call,
                happenedOn: day(2026, 8, 2),
                body: "Twenty minutes about the landlord. He sounded lighter than last month.",
                createdAt: day(2026, 8, 2)
            ),
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4")!,
                personID: priya.id,
                kind: .gift,
                happenedOn: day(2026, 7, 20),
                body: "Sent the small brass bowl she liked at the Sunday market.",
                createdAt: day(2026, 7, 20)
            ),
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa5")!,
                personID: amma.id,
                kind: .call,
                happenedOn: day(2026, 8, 14),
                body: "Told her about the new place. She wants photos of the kitchen window.",
                createdAt: day(2026, 8, 14)
            ),
            Entry(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa6")!,
                personID: dev.id,
                kind: .note,
                happenedOn: day(2026, 6, 4),
                body: "Mentioned his sister is applying to the same studio programme.",
                createdAt: day(2026, 6, 4)
            ),
        ]

        return KithDocument(people: people, entries: entries)
    }
}
