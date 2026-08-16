import KithCore
import SwiftUI

struct LogCard: View {
    var entry: Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: entry.kind.symbolName)
                    .foregroundStyle(KithPalette.clay)
                Text(entry.kind.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(entry.happenedOn, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline)
                    .foregroundStyle(KithPalette.espresso.opacity(0.5))
            }
            if !entry.body.isEmpty {
                Text(entry.body)
                    .font(.body)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KithPalette.linen, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct LogEditor: View {
    var person: Person
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var kind: LogKind = .note
    @State private var happenedOn = Date()
    @State private var bodyText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("What happened") {
                    Picker("Kind", selection: $kind) {
                        ForEach(LogKind.allCases, id: \.self) { option in
                            Label(option.title, systemImage: option.symbolName).tag(option)
                        }
                    }
                    DatePicker("When", selection: $happenedOn, displayedComponents: .date)
                    TextField("A few words", text: $bodyText, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(KithPalette.cream)
            .navigationTitle("For \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
        }
        .kithBackground()
    }

    private func save() {
        model.addEntry(
            Entry(personID: person.id, kind: kind, happenedOn: happenedOn, body: bodyText)
        )
        dismiss()
    }
}
