import AuthenticationServices
import PersonalSyncKit
import SaaSMakerUI
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
                            .textCase(.lowercase)
                            .accessibilityLabel("Your people, where you need them")
                            .font(KithType.title2.weight(.semibold))
                        Text("Kith works without an account. Connecting adds a private Hub copy of approved people and dated notes.")
                            .foregroundStyle(KithPalette.espresso.opacity(0.62))
                    }

                    SMCard(padding: 18) {
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
                    }

                    if let notice = model.cloudAccountNotice {
                        Text(notice).font(KithType.footnote).foregroundStyle(KithPalette.rust)
                    }
                    if let account = model.account {
                        SMCard(padding: 18) {
                            VStack(alignment: .leading, spacing: 14) {
                                if account.isSignedIn {
                                    Label(
                                        account.session?.email ?? "Significant Hobbies connected",
                                        systemImage: "checkmark.circle.fill"
                                    )
                                    .foregroundStyle(KithPalette.sage)

                                    if model.isPlatformSyncing {
                                        SMStatusPill("syncing with your Hub…", tone: .brand)
                                            .accessibilityLabel("Syncing with your Hub…")
                                    }
                                    syncDetails

                                    if let notice = model.platformAccountNotice {
                                        Text(notice).font(KithType.subheadline).foregroundStyle(KithPalette.rust)
                                    }
                                    if model.needsPlatformApproval || (model.platformAccountMatches && model.platformAccountNotice != nil) {
                                        Text("Approve the current people and notes on this iPhone for the account shown above? New or changed iCloud copies will wait for another approval. Records connected to another account stay separate.")
                                            .font(KithType.subheadline)
                                        Button("Approve these people and notes") {
                                            Task { await model.approvePlatformAccount() }
                                        }
                                        .textCase(.lowercase)
                                        .accessibilityLabel("Approve these people and notes")
                                        .buttonStyle(SMButtonStyle(.brand))
                                        .disabled(model.isPlatformSyncing)
                                        Button("Keep using Kith locally") { dismiss() }
                                            .textCase(.lowercase)
                                            .accessibilityLabel("Keep using Kith locally")
                                    }
                                    Button("Sync now") {
                                        Task { await model.syncFromPlatform() }
                                    }
                                    .textCase(.lowercase)
                                    .accessibilityLabel("Sync now")
                                    .buttonStyle(SMButtonStyle(.brand))
                                    .disabled(model.isPlatformSyncing || !model.platformAccountMatches)
                                    Button("Recover missing Hub records") {
                                        Task { await model.syncFromPlatform(recoverMissingRecords: true) }
                                    }
                                    .textCase(.lowercase)
                                    .accessibilityLabel("Recover missing Hub records")
                                    .disabled(model.isPlatformSyncing || !model.platformAccountMatches)
                                    Text("Checks this account’s history for people or notes an older app may have missed. Existing local details and deletions are kept.")
                                        .font(KithType.footnote)
                                        .foregroundStyle(KithPalette.espresso.opacity(0.62))
                                    if let notice = model.platformRecoveryNotice {
                                        Text(notice).font(KithType.footnote)
                                    }
                                    Button("Sign out", role: .destructive) {
                                        Task {
                                            await model.disconnectPlatform()
                                            await model.refreshPlatformStatus()
                                        }
                                    }
                                    .textCase(.lowercase)
                                    .accessibilityLabel("Sign out")
                                } else {
                                    Text("Connect your Significant Hobbies account")
                                        .textCase(.lowercase)
                                        .accessibilityLabel("Connect your Significant Hobbies account")
                                        .font(KithType.headline)
                                    Text("Your people stay on this iPhone. Kith asks before connecting them to a Hub account, and keeps an existing connection tied to its original account.")
                                        .font(KithType.subheadline)
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
                                    .textCase(.lowercase)
                                    .accessibilityLabel("Use Google instead")
                                    .buttonStyle(SMButtonStyle(.brand))
                                    .disabled(account.isConnecting)
                                }

                                if account.isConnecting { ProgressView() }
                                if let error = account.errorMessage {
                                    Text(error).font(KithType.footnote).foregroundStyle(KithPalette.rust)
                                }
                            }
                        }
                    } else {
                        Text("Connection setup is unavailable in this build.")
                            .foregroundStyle(KithPalette.rust)
                    }

                    Link("privacy policy", destination: URL(string: "https://kith.significanthobbies.com/privacy")!)
                        .accessibilityLabel("Privacy policy")
                        .font(KithType.footnote)
                }
                .padding(28)
            }
            .background(KithPalette.linen)
            .kithNavigationTitle("Connection")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .textCase(.lowercase)
                        .accessibilityLabel("Done")
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
            .font(KithType.footnote)
            .foregroundStyle(KithPalette.espresso.opacity(0.72))
        }
        if let issue = model.platformSyncIssue {
            Label(issue.message, systemImage: "exclamationmark.triangle.fill")
                .font(KithType.footnote)
                .foregroundStyle(KithPalette.rust)
        }
        if let lastSync = model.lastPlatformSyncAt {
            HStack(spacing: 4) {
                Text("Last Hub sync")
                Text(lastSync, style: .relative)
            }
            .font(KithType.footnote)
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
                Text(title.lowercased()).font(KithType.subheadline.weight(.semibold))
                    .accessibilityLabel(title)
                Text(detail)
                    .font(KithType.footnote)
                    .foregroundStyle(KithPalette.espresso.opacity(0.58))
            }
        }
    }
}
