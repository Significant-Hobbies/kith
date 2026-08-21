import KithCore
import SwiftUI

@main
struct KithApp: App {
    @State private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .task { await model.load() }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await model.syncFromCloud()
                        await model.syncFromPlatform()
                    }
                }
        }
    }
}
