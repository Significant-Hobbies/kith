import KithCore
import SwiftUI

private enum KithOnboardingStep {
    case person
    case context
    case constellation
}

struct KithOnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step: KithOnboardingStep = .person
    @State private var name = ""
    @State private var circle: CircleKind = .friends
    @State private var closeness = 3
    @State private var hue: PersonHue = .clay
    @State private var kind: LogKind = .note
    @State private var happenedOn = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .person: personStep
                case .context: contextStep
                case .constellation: constellationStep
                }
            }
            .onAppear {
                guard let person = model.onboardingPerson else { return }
                name = person.name
                circle = person.circle
                closeness = person.closeness
                hue = person.hue
                step = model.document.entries(for: person.id).isEmpty ? .context : .constellation
            }
        }
        .kithBackground()
    }

    private var personStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                introduction
                lanternPreview
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Their name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.name)
                        .accessibilityLabel("Their name")
                    Picker("Circle", selection: $circle) {
                        ForEach(CircleKind.allCases, id: \.self) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How close are you?")
                            .font(.headline)
                        ClosenessRow(value: $closeness)
                        Text("You choose this value. Kith never infers closeness from recency, notes, or circle.")
                            .font(.footnote)
                            .foregroundStyle(KithPalette.espresso.opacity(0.62))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lantern colour").font(.headline)
                        HueRow(hue: $hue)
                    }
                }
                .padding(20)
                .background(KithPalette.cream, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Button("Place in my constellation") { savePerson() }
                    .buttonStyle(ClayButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                Text("No Contacts permission. This is saved on your iPhone first and works offline.")
                    .font(.footnote)
                    .foregroundStyle(KithPalette.espresso.opacity(0.58))
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: 620)
            .padding(24)
        }
        .navigationTitle("Kith")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("The people you keep close.")
                .font(.largeTitle.weight(.semibold))
            Text("Begin with one real person. A name, the closeness you choose, and one thing worth remembering are enough.")
                .font(.body)
                .foregroundStyle(KithPalette.espresso.opacity(0.66))
        }
    }

    private var lanternPreview: some View {
        let preview = Person(
            name: name.isEmpty ? "Someone" : name,
            circle: circle,
            closeness: closeness,
            hue: hue
        )
        return VStack(spacing: 10) {
            LanternView(person: preview, diameter: CGFloat(preview.lanternDiameter))
                .animation(reduceMotion ? nil : .spring(response: 0.3), value: closeness)
            Text("Closeness \(closeness) of 5 · \(circle.title)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KithPalette.espresso.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(preview.name), \(circle.title), closeness \(closeness) of 5")
    }

    private var contextStep: some View {
        Form {
            if let person = model.onboardingPerson {
                Section {
                    HStack(spacing: 16) {
                        LanternView(person: person, diameter: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(person.name).font(.title2.weight(.semibold))
                            Text("\(person.circle.title) · closeness \(person.closeness)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text("Placed in your constellation")
                }
            }
            Section("What do you want to remember?") {
                Picker("Kind", selection: $kind) {
                    ForEach(LogKind.allCases, id: \.self) { option in
                        Label(option.title, systemImage: option.symbolName).tag(option)
                    }
                }
                DatePicker("When", selection: $happenedOn, displayedComponents: .date)
                TextField("A few words", text: $note, axis: .vertical)
                    .lineLimit(3...7)
            }
            Section {
                Text("This becomes a real dated entry in their chronological log. You can edit the person or add more entries later.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(KithPalette.linen)
        .navigationTitle("One thing to keep")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Save this memory") {
                model.saveOnboardingEntry(kind: kind, happenedOn: happenedOn, body: note)
                guard let person = model.onboardingPerson,
                      !model.document.entries(for: person.id).isEmpty else { return }
                step = .constellation
            }
            .buttonStyle(ClayButtonStyle())
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.regularMaterial)
        }
    }

    private var constellationStep: some View {
        ZStack {
            BubbleField(people: model.document.people) { _ in }
                .accessibilityHidden(false)
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your constellation has begun.")
                        .font(.largeTitle.weight(.semibold))
                    Text("One person and one honest memory are enough. Add others when they naturally come to mind.")
                        .font(.body)
                        .foregroundStyle(KithPalette.espresso.opacity(0.65))
                }
                .padding(24)
                .background(.regularMaterial)
                Spacer()
                VStack(spacing: 10) {
                    Text("Saved on this iPhone. Signing in later adds an optional private Cloudflare copy; Kith stays usable without it.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(KithPalette.espresso.opacity(0.62))
                    Button("Open Kith") { model.finishOnboarding() }
                        .buttonStyle(ClayButtonStyle())
                    Button("Add another person") { model.finishOnboarding(addAnother: true) }
                        .font(.headline)
                        .frame(minHeight: 44)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
        }
        .navigationBarHidden(true)
    }

    private func savePerson() {
        let person = Person(name: name, circle: circle, closeness: closeness, hue: hue)
        model.saveOnboardingPerson(person)
        guard model.onboardingPerson != nil else { return }
        step = .context
    }
}
