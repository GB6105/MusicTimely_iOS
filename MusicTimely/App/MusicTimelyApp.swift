import SwiftUI

@main
struct MusicTimelyApp: App {
    @State private var store: SessionStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        // UI 테스트는 격리된 저장소에서 새로 시작한다.
        if arguments.contains("-uiTesting") {
            let dir = FileManager.default.temporaryDirectory.appending(path: "uitest-\(UUID().uuidString)")
            let fileStore = FileStateStore(directory: dir)
            if let index = arguments.firstIndex(of: "-uiSeed"), index + 1 < arguments.count {
                UITestSeed.apply(arguments[index + 1], to: fileStore)
            }
            let live = arguments.contains("-uiLiveActivity") ? LiveActivityController() : nil
            let store = SessionStore(store: fileStore, liveActivity: live)
            if let index = arguments.firstIndex(of: "-uiTheme"), index + 1 < arguments.count,
                let theme = ThemeChoice(rawValue: arguments[index + 1])
            {
                store.updateSettings { $0.theme = theme }
            }
            _store = State(initialValue: store)
        } else {
            _store = State(initialValue: SessionStore(liveActivity: LiveActivityController()))
        }
        // 잠금화면 버튼은 앱 프로세스에서 실행된다.
        let store = _store.wrappedValue
        IntentCommandCenter.handler = { command in store.handleIntent(command) }
    }

    var body: some Scene {
        WindowGroup {
            RootView().environment(store)
                .onOpenURL { _ in store.sceneBecameActive() }
        }
    }
}
