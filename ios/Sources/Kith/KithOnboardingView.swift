import KithCore
import SaaSMakerUI
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
                Image("KithOnboarding")
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 220)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("A hand-drawn figure ties one remembered moment to the lantern of someone close.")
                if model.isExistingOwnerOrientation {
                    existingOwnerActions
                } else {
                    lanternPreview
                    SMCard {
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
                                    .textCase(.lowercase)
                                    .accessibilityLabel("How close are you?")
                                    .font(KithType.headline)
                                ClosenessRow(value: $closeness)
                                Text("You choose this value. Kith never infers closeness from recency, notes, or circle.")
                                    .font(KithType.footnote)
                                    .foregroundStyle(KithPalette.espresso.opacity(0.62))
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Lantern colour").font(KithType.headline)
                                    .textCase(.lowercase)
                                    .accessibilityLabel("Lantern colour")
                                HueRow(hue: $hue)
                            }
                        }
                    }

                    Button("Place in my constellation") { savePerson() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Place in my constellation")
                        .buttonStyle(SMButtonStyle(.brand))
                        .frame(maxWidth: .infinity)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    Button("Open Kith first") { model.finishOnboarding() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Open Kith first")
                        .font(KithType.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)

                    Text("No Contacts permission. This is saved on your iPhone first and works offline.")
                        .font(KithType.footnote)
                        .foregroundStyle(KithPalette.espresso.opacity(0.58))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(maxWidth: 620)
            .padding(24)
        }
        .kithNavigationTitle("Kith")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var existingOwnerActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your existing constellation stays exactly as it is.")
                .font(KithType.body)
                .foregroundStyle(KithPalette.espresso.opacity(0.66))
            Button("Return to Kith") { model.finishOnboarding() }
                .textCase(.lowercase)
                .accessibilityLabel("Return to Kith")
                .buttonStyle(SMButtonStyle(.brand))
                .frame(maxWidth: .infinity)
            Button("Add someone in Kith") { model.finishOnboarding(addAnother: true) }
                .textCase(.lowercase)
                .accessibilityLabel("Add someone in Kith")
                .font(KithType.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 10) {
            SMSectionHeader("The people you keep close.", size: 34)
                .accessibilityLabel("The people you keep close.")
            Text("Begin with one real person. A name, the closeness you choose, and one thing worth remembering are enough.")
                .font(KithType.body)
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
                .animation(reduceMotion ? nil : SMMotion.state, value: closeness)
            Text("Closeness \(closeness) of 5 · \(circle.title)")
                .font(KithType.subheadline.weight(.medium))
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
                            Text(person.name).font(KithType.title2.weight(.semibold))
                            Text("\(person.circle.title) · closeness \(person.closeness)")
                                .font(KithType.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                } header: {
                    Text("Placed in your constellation")
                        .textCase(.lowercase)
                        .accessibilityLabel("Placed in your constellation")
                }
            }
            Section {
                Picker("Kind", selection: $kind) {
                    ForEach(LogKind.allCases, id: \.self) { option in
                        Label(option.title, systemImage: option.symbolName).tag(option)
                    }
                }
                DatePicker("When", selection: $happenedOn, displayedComponents: .date)
                TextField("A few words", text: $note, axis: .vertical)
                    .lineLimit(3...7)
            } header: {
                Text("What do you want to remember?")
                    .textCase(.lowercase)
                    .accessibilityLabel("What do you want to remember?")
            }
            Section {
                Text("This becomes a real dated entry in their chronological log. You can edit the person or add more entries later.")
                    .font(KithType.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(KithPalette.linen)
        .kithNavigationTitle("One thing to keep")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button("Save this memory") {
                Task {
                    if await model.saveOnboardingEntry(kind: kind, happenedOn: happenedOn, body: note) {
                        step = .constellation
                    }
                }
            }
            .textCase(.lowercase)
            .accessibilityLabel("Save this memory")
            .buttonStyle(SMButtonStyle(.brand))
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
                        .textCase(.lowercase)
                        .accessibilityLabel("Your constellation has begun.")
                        .font(KithType.largeTitle.weight(.semibold))
                    Text("One person and one honest memory are enough. Add others when they naturally come to mind.")
                        .font(KithType.body)
                        .foregroundStyle(KithPalette.espresso.opacity(0.65))
                }
                .padding(24)
                .background(.regularMaterial)
                Spacer()
                VStack(spacing: 10) {
                    Text("Saved on this iPhone. Signing in later adds an optional private Cloudflare copy; Kith stays usable without it.")
                        .font(KithType.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(KithPalette.espresso.opacity(0.62))
                    Button("Open Kith") { model.finishOnboarding() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Open Kith")
                        .buttonStyle(SMButtonStyle(.brand))
                    Button("Add another person") { model.finishOnboarding(addAnother: true) }
                        .textCase(.lowercase)
                        .accessibilityLabel("Add another person")
                        .font(KithType.headline)
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
        Task {
            if await model.saveOnboardingPerson(person) { step = .context }
        }
    }
}
