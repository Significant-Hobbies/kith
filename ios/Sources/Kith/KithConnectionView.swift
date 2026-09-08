import AuthenticationServices
import PersonalSyncKit
import SwiftUI

struct KithConnectionView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 42))
                            .foregroundStyle(KithPalette.clay)
                        Text("Your people, where you need them")
                            .font(.title2.weight(.semibold))
                        Text("Kith works without an account. Connecting adds a private Hub copy of approved people and dated notes.")
                            .foregroundStyle(KithPalette.espresso.opacity(0.62))
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        role(
                            icon: "iphone",
                            title: "Saved on this iPhone",
                            detail: "Every edit appears here immediately, even offline."
                        )
                        role(
                            icon: "icloud",
                            title: "Kept across your Apple devices",
                            detail: "iCloud mirrors the full Kith app while the Hub transition is underway."
                        )
                        role(
                            icon: "square.grid.2x2",
                            title: "Visible in your private Hub",
                            detail: "Your Significant Hobbies account syncs approved people and dated notes."
                        )
                    }
                    .padding(18)
                    .background(KithPalette.cream, in: RoundedRectangle(cornerRadius: 22))

                    if let notice = model.cloudAccountNotice {
                        Text(notice).font(.footnote).foregroundStyle(KithPalette.rust)
                    }
                    if let account = model.account {
                        VStack(alignment: .leading, spacing: 14) {
                            if account.isSignedIn {
                                Label(
                                    account.session?.email ?? "Significant Hobbies connected",
                                    systemImage: "checkmark.circle.fill"
                                )
                                .foregroundStyle(KithPalette.sage)

                                if model.isPlatformSyncing {
                                    Label("Syncing with your Hub…", systemImage: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(KithPalette.espresso.opacity(0.7))
                                }
                                syncDetails

                                if let notice = model.platformAccountNotice {
                                    Text(notice).font(.subheadline).foregroundStyle(KithPalette.rust)
                                }
                                if model.needsPlatformApproval || (model.platformAccountMatches && model.platformAccountNotice != nil) {
                                    Text("Connect the people and notes on this iPhone to the account shown above? They will be included in its private Hub copy.")
                                        .font(.subheadline)
                                    Button("Connect these people to this account") {
                                        Task { await model.approvePlatformAccount() }
                                    }
                                    .buttonStyle(ClayButtonStyle())
                                    .disabled(model.isPlatformSyncing)
                                    Button("Keep using Kith locally") { dismiss() }
                                }
                                Button("Sync now") {
                                    Task { await model.syncFromPlatform() }
                                }
                                .buttonStyle(ClayButtonStyle())
                                .disabled(model.isPlatformSyncing || !model.platformAccountMatches)
                                Button("Sign out", role: .destructive) {
                                    Task {
                                        await model.disconnectPlatform()
                                        await model.refreshPlatformStatus()
                                    }
                                }
                            } else {
                                Text("Connect your Significant Hobbies account")
                                    .font(.headline)
                                Text("Your people stay on this iPhone. Kith asks before connecting them to a Hub account, and keeps an existing connection tied to its original account.")
                                    .font(.subheadline)
                                    .foregroundStyle(KithPalette.espresso.opacity(0.62))
                                syncDetails

                                SignInWithAppleButton(.continue) { request in
                                    account.prepareApple(request)
                                } onCompletion: { result in
                                    Task {
                                        await account.completeApple(result)
                                        if account.isSignedIn { await model.syncFromPlatform() }
                                    }
                                }
                                .signInWithAppleButtonStyle(.black)
                                .frame(minHeight: 46)
                                .disabled(account.isConnecting)
                                Button("Use Google instead") {
                                    Task {
                                        await account.connect()
                                        if account.isSignedIn { await model.syncFromPlatform() }
                                    }
                                }
                                .buttonStyle(ClayButtonStyle())
                                .disabled(account.isConnecting)
                            }

                            if account.isConnecting { ProgressView() }
                            if let error = account.errorMessage {
                                Text(error).font(.footnote).foregroundStyle(KithPalette.rust)
                            }
                        }
                        .padding(18)
                        .background(KithPalette.cream, in: RoundedRectangle(cornerRadius: 22))
                    } else {
                        Text("Connection setup is unavailable in this build.")
                            .foregroundStyle(KithPalette.rust)
                    }

                }
                .padding(28)
            }
            .background(KithPalette.linen)
            .navigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await model.refreshPlatformStatus() }
        }
    }

    @ViewBuilder
    private var syncDetails: some View {
        if model.platformPendingMutationCount > 0 {
            Label(
                waitingText(model.platformPendingMutationCount),
                systemImage: "clock.arrow.circlepath"
            )
            .font(.footnote)
            .foregroundStyle(KithPalette.espresso.opacity(0.72))
        }
        if let issue = model.platformSyncIssue {
            Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                .font(.footnote)
                .foregroundStyle(KithPalette.rust)
        }
        if let lastSync = model.lastPlatformSyncAt {
            HStack(spacing: 4) {
                Text("Last Hub sync")
                Text(lastSync, style: .relative)
            }
            .font(.footnote)
            .foregroundStyle(KithPalette.espresso.opacity(0.55))
        }
    }

    private func waitingText(_ count: Int) -> String {
        count == 1
            ? "1 change is waiting safely"
            : "\(count) changes are waiting safely"
    }

    private func role(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundStyle(KithPalette.clay)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(KithPalette.espresso.opacity(0.58))
            }
        }
    }
}
