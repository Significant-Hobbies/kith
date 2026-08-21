import PersonalSyncKit
import SwiftUI

struct KithConnectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "icloud")
                    .font(.system(size: 42))
                    .foregroundStyle(KithPalette.clay)
                Text("Keep Kith in sync")
                    .font(.title2.weight(.semibold))
                Text("Kith stays local-first. When connected, people and notes also sync through your private Significant Hobbies account.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(KithPalette.espresso.opacity(0.62))
                if let account = model.account {
                    if account.isSignedIn {
                        Label(account.session?.email ?? "Connected", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(KithPalette.sage)
                        Button("Sync now") {
                            Task { await model.syncFromPlatform() }
                        }
                        .buttonStyle(ClayButtonStyle())
                        Button("Sign out", role: .destructive) {
                            Task { await account.signOut() }
                        }
                    } else {
                        Button("Connect Significant Hobbies") {
                            Task {
                                await account.connect()
                                await model.syncFromPlatform()
                            }
                        }
                        .buttonStyle(ClayButtonStyle())
                        .disabled(account.isConnecting)
                    }
                    if account.isConnecting { ProgressView() }
                    if let error = account.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(KithPalette.rust)
                    }
                } else {
                    Text("Connection setup is unavailable.")
                        .foregroundStyle(KithPalette.rust)
                }
                Spacer()
            }
            .padding(28)
            .background(KithPalette.linen)
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
