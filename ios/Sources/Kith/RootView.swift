import KithCore
import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            KithPalette.linen.ignoresSafeArea()
            if model.isLoading {
                ProgressView()
                    .tint(KithPalette.clay)
            } else if model.isOnboardingPresented {
                KithOnboardingView()
            } else if model.isShowingList {
                PeopleListView()
            } else {
                ConstellationView()
            }
        }
        .kithBackground()
        .sheet(isPresented: $model.isAddingPerson) {
            PersonEditor(person: nil)
        }
        .sheet(isPresented: $model.isShowingConnection) {
            KithConnectionView()
        }
        .sheet(item: selectedPersonBinding) { person in
            PersonPage(personID: person.id)
        }
        .alert("Kith", isPresented: Binding(
            get: { model.message != nil },
            set: { if !$0 { model.message = nil } }
        )) {
            Button("OK", role: .cancel) { model.message = nil }
        } message: {
            Text(model.message ?? "")
        }
    }

    private var selectedPersonBinding: Binding<Person?> {
        Binding(
            get: { model.selectedPerson },
            set: { model.selectedPersonID = $0?.id }
        )
    }
}

struct ConstellationView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if model.document.people.isEmpty {
                EmptyConstellation()
            } else {
                BubbleField(people: model.visiblePeople) { person in
                    model.selectedPersonID = person.id
                }
                if model.visiblePeople.isEmpty {
                    Text("No one matches that.")
                        .font(.body.weight(.medium))
                        .foregroundStyle(KithPalette.espresso.opacity(0.55))
                }
            }
            VStack {
                FieldChrome()
                Spacer()
            }
        }
    }
}

struct FieldChrome: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Text("Kith")
                    .font(.largeTitle.weight(.semibold))
                Spacer()
                Button {
                    model.isShowingConnection = true
                } label: {
                    Image(systemName: model.account?.isSignedIn == true ? "checkmark.icloud" : "icloud")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(KithPalette.cream, in: Circle())
                }
                .accessibilityLabel("Cloudflare connection")
                Button {
                    model.isShowingList.toggle()
                } label: {
                    Image(systemName: model.isShowingList ? "sparkles" : "list.bullet")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(KithPalette.cream, in: Circle())
                }
                .accessibilityLabel(model.isShowingList ? "Show constellation" : "Show list")
                if !model.document.people.isEmpty {
                    Button {
                        model.isAddingPerson = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(KithPalette.clay, in: Circle())
                    }
                    .accessibilityLabel("Add someone")
                    .accessibilityIdentifier("add-person")
                }
            }
            if !model.document.people.isEmpty {
                TextField("Find someone", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(KithPalette.cream, in: Capsule())
                    .accessibilityLabel("Find someone")
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}


struct EmptyConstellation: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(KithPalette.clay.opacity(0.22))
                    .frame(width: 132, height: 132)
                    .offset(x: -36, y: -8)
                Circle()
                    .fill(KithPalette.apricot.opacity(0.55))
                    .frame(width: 92, height: 92)
                    .offset(x: 44, y: 12)
                Circle()
                    .fill(KithPalette.honey.opacity(0.7))
                    .frame(width: 64, height: 64)
                    .offset(x: 10, y: 48)
            }
            .frame(height: 180)
            .accessibilityHidden(true)
            Text("Who do you want to keep close?")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text("Add someone. They’ll float here, larger when the relationship is closer.")
                .font(.body)
                .foregroundStyle(KithPalette.espresso.opacity(0.62))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Add someone") {
                model.isAddingPerson = true
            }
            .buttonStyle(ClayButtonStyle())
            .padding(.top, 6)
        }
        .padding(28)
    }
}

struct PeopleListView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            FieldChrome()
            if model.document.people.isEmpty {
                EmptyConstellation()
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(model.visiblePeople) { person in
                        Button {
                            model.selectedPersonID = person.id
                        } label: {
                            HStack(spacing: 14) {
                                LanternView(person: person, diameter: 52)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(person.name)
                                        .font(.headline)
                                    Text(person.circle.title)
                                        .font(.subheadline)
                                        .foregroundStyle(KithPalette.espresso.opacity(0.55))
                                }
                                Spacer()
                                Text("\(person.closeness)")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(KithPalette.clay)
                            }
                            .padding(.vertical, 6)
                        }
                        .listRowBackground(KithPalette.linen)
                        .listRowSeparatorTint(KithPalette.espresso.opacity(0.08))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

struct ClayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .background(KithPalette.clay, in: Capsule())
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
