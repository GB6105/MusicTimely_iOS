import SwiftUI

@main
struct MusicTimelyApp: App {
    @State private var store: SessionStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI 테스트는 격리된 저장소에서 새로 시작한다.
        if arguments.contains("-uiTesting") {
            let dir = FileManager.default.temporaryDirectory.appending(path: "uitest-\(UUID().uuidString)")
            let store = SessionStore(store: FileStateStore(directory: dir))
            if let index = arguments.firstIndex(of: "-uiTheme"), index + 1 < arguments.count,
                let theme = ThemeChoice(rawValue: arguments[index + 1])
            {
                store.updateSettings { $0.theme = theme }
            }
            _store = State(initialValue: store)
        } else {
            _store = State(initialValue: SessionStore())
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
        }
    }
}
