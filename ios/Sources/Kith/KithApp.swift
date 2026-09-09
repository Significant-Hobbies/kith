import KithCore
import SwiftUI

@main
struct KithApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--ui-persistence-store") {
            guard arguments.indices.contains(index + 1),
                  let id = UUID(uuidString: arguments[index + 1]) else {
                fatalError("UI persistence tests require a valid fixture UUID")
            }
            let directory = FileManager.default.temporaryDirectory
                .appending(path: "KithUITests", directoryHint: .isDirectory)
                .appending(path: id.uuidString, directoryHint: .isDirectory)
            if arguments.contains("--ui-persistence-cleanup"),
               FileManager.default.fileExists(atPath: directory.path) {
                do { try FileManager.default.removeItem(at: directory) }
                catch { fatalError("Could not clean the scoped UI fixture: \(error)") }
            }
            _model = State(initialValue: AppModel(
                store: KithStore(fileURL: directory.appending(path: "people.json")),
                cloud: nil,
                platform: nil
            ))
            return
        }
        #endif
        _model = State(initialValue: AppModel())
    }

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
