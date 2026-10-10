import KithCore
import SaaSMakerUI
import SwiftUI

struct LogCard: View {
    var entry: Entry
    @Environment(\.smPalette) private var palette

    var body: some View {
        SMCard(padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        kindLabel.fixedSize()
                        Spacer(minLength: 8)
                        dateLabel.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        kindLabel
                        dateLabel
                    }
                }
                if !entry.body.isEmpty {
                    Text(entry.body)
                        .font(KithType.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .environment(\.smPalette, logPalette)
    }

    private var logPalette: SMPalette {
        var palette = self.palette
        palette.card = KithPalette.linen
        palette.radius = 16
        return palette
    }

    private var kindLabel: some View {
        Label(entry.kind.title.lowercased(), systemImage: entry.kind.symbolName)
            .accessibilityLabel(entry.kind.title)
            .font(KithType.subheadline.weight(.semibold))
            .foregroundStyle(KithPalette.clay)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var dateLabel: some View {
        Text(entry.happenedOn, format: .dateTime.month(.abbreviated).day().year())
            .font(KithType.subheadline)
            .foregroundStyle(KithPalette.espresso.opacity(0.5))
            .fixedSize(horizontal: false, vertical: true)
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
                if let message = model.message {
                    Section {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(KithPalette.rust)
                    }
                }
                Section {
                    Picker("Kind", selection: $kind) {
                        ForEach(LogKind.allCases, id: \.self) { option in
                            Label(option.title, systemImage: option.symbolName).tag(option)
                        }
                    }
                    DatePicker("When", selection: $happenedOn, displayedComponents: .date)
                    TextField("A few words", text: $bodyText, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("What happened")
                        .textCase(.lowercase)
                        .accessibilityLabel("What happened")
                }
            }
            .scrollContentBackground(.hidden)
            .background(KithPalette.cream)
            .kithNavigationTitle("For \(person.firstName)", displayTitle: "for \(person.firstName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Save")
                }
            }
        }
        .disabled(model.isSaving)
        .interactiveDismissDisabled(model.isSaving)
        .kithBackground()
    }

    private func save() {
        let entry = Entry(personID: person.id, kind: kind, happenedOn: happenedOn, body: bodyText)
        Task {
            if await model.addEntry(entry) { dismiss() }
        }
    }
}
