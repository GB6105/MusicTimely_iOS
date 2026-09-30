import SwiftUI

/// 상태에 따라 화면을 고르고 테마를 적용한다 (§9.4 openSession).
struct RootView: View {
    @Environment(SessionStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var browsingHome = false

    var body: some View {
        let palette = Palette.resolve(store.settings.theme, scheme: colorScheme)
        ZStack(alignment: .bottom) {
            Group {
                switch store.route {
                case .assign:
                    AssignView()
                case .session:
                    if browsingHome {
                        AssignView(activeSessionReturn: { browsingHome = false })
                    } else {
                        SessionView(onBrowseHome: { browsingHome = true })
                    }
                case .result:
                    ResultView()
                case .recovery:
                    RecoveryView()
                }
            }
            .animation(.easeInOut(duration: 0.25), value: store.route)
            if let toast = store.toast {
                ToastView(message: toast.message)
                    .padding(.bottom, 90)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        UIAccessibility.post(notification: .announcement, argument: toast.message)
                        try? await Task.sleep(for: .seconds(2.5))
                        if store.toast?.id == toast.id { store.toast = nil }
                    }
            }
        }
        .environment(\.palette, palette)
        .preferredColorScheme(palette.isDark ? .dark : (store.settings.theme == .system ? nil : .light))
        .tint(Palette.accentMid)
        .onChange(of: store.route) { _, route in if route != .session { browsingHome = false } }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active: store.sceneBecameActive()
            case .background: store.sceneMovedToBackground()
            default: break
            }
        }
    }
}
