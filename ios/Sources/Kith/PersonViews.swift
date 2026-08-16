import KithCore
import SwiftUI

struct PersonPage: View {
    var personID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isLogging = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Group {
                if let person = model.document.person(id: personID) {
                    personContent(person)
                } else {
                    ContentUnavailableView("That person is gone", systemImage: "person.slash")
                }
            }
            .background(KithPalette.cream.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                PersonEditor(person: model.document.person(id: personID))
            }
            .sheet(isPresented: $isLogging) {
                if let person = model.document.person(id: personID) {
                    LogEditor(person: person)
                }
            }
            .confirmationDialog("Remove this person?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    model.deletePerson(id: personID)
                    dismiss()
                }
            } message: {
                Text("Their notes go with them. This stays on this phone.")
            }
        }
        .kithBackground()
        .presentationDetents([.large])
    }

    @ViewBuilder
    private func personContent(_ person: Person) -> some View {
        let entries = model.document.entries(for: person.id)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header(person)
                if !person.howWeMet.isEmpty {
                    labeled("How you met", person.howWeMet)
                }
                if !person.standingNotes.isEmpty {
                    labeled("Keep in mind", person.standingNotes)
                }
                if let birthday = person.birthday {
                    labeled("Birthday", birthday.formatted(.dateTime.month(.wide).day().year()))
                }
                HStack {
                    Text("Log")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Button("Add") { isLogging = true }
                        .font(.body.weight(.semibold))
                }
                .padding(.top, 8)
                if entries.isEmpty {
                    Text("Nothing written yet. A dinner, a call, a thing to remember.")
                        .foregroundStyle(KithPalette.espresso.opacity(0.55))
                } else {
                    ForEach(entries) { entry in
                        LogCard(entry: entry)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    model.deleteEntry(id: entry.id)
                                }
                            }
                    }
                }
                Button("Remove \(person.firstName)", role: .destructive) {
                    confirmDelete = true
                }
                .font(.subheadline.weight(.medium))
                .padding(.top, 16)
            }
            .padding(24)
        }
    }

    private func header(_ person: Person) -> some View {
        VStack(spacing: 12) {
            LanternView(person: person, diameter: CGFloat(person.lanternDiameter))
            Text(person.name)
                .font(.largeTitle.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("\(person.circle.title) · closeness \(person.closeness)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KithPalette.espresso.opacity(0.58))
            if let last = model.document.lastContact(for: person.id) {
                Text("Last note \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.footnote)
                    .foregroundStyle(KithPalette.espresso.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private func labeled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(KithPalette.espresso.opacity(0.5))
            Text(body)
                .font(.body)
        }
    }
}

struct PersonEditor: View {
    var person: Person?
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var howWeMet: String
    @State private var standingNotes: String
    @State private var circle: CircleKind
    @State private var closeness: Int
    @State private var hue: PersonHue
    @State private var hasBirthday: Bool
    @State private var birthday: Date

    init(person: Person?) {
        self.person = person
        _name = State(initialValue: person?.name ?? "")
        _howWeMet = State(initialValue: person?.howWeMet ?? "")
        _standingNotes = State(initialValue: person?.standingNotes ?? "")
        _circle = State(initialValue: person?.circle ?? .friends)
        _closeness = State(initialValue: person?.closeness ?? 3)
        _hue = State(initialValue: person?.hue ?? .clay)
        _hasBirthday = State(initialValue: person?.birthday != nil)
        _birthday = State(initialValue: person?.birthday ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Who") {
                    TextField("Name", text: $name)
                    Picker("Circle", selection: $circle) {
                        ForEach(CircleKind.allCases, id: \.self) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Closeness")
                        ClosenessRow(value: $closeness)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Colour")
                        HueRow(hue: $hue)
                    }
                }
                Section("About them") {
                    TextField("How you met", text: $howWeMet, axis: .vertical)
                    TextField("Things to keep in mind", text: $standingNotes, axis: .vertical)
                    Toggle("Birthday", isOn: $hasBirthday)
                    if hasBirthday {
                        DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(KithPalette.cream)
            .navigationTitle(person == nil ? "Someone new" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .kithBackground()
    }

    private func save() {
        var next = person ?? Person(name: name, closeness: closeness, hue: hue)
        next.name = name
        next.howWeMet = howWeMet
        next.standingNotes = standingNotes
        next.circle = circle
        next.closeness = closeness
        next.hue = hue
        next.birthday = hasBirthday ? birthday : nil
        model.savePerson(next)
        dismiss()
    }
}
