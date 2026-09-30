import AppIntents
import Foundation

/// 잠금화면·Dynamic Island 버튼 명령. 실행은 앱 프로세스에서 한다 (LiveActivityIntent).
nonisolated enum SessionIntentCommand: Sendable {
    case pause
    case resume
    case finish
}

/// 앱이 시작될 때 명령 처리기를 등록한다. 위젯 확장에서는 비어 있다.
@MainActor
enum IntentCommandCenter {
    static var handler: ((SessionIntentCommand) -> Void)?
}

nonisolated struct PauseSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "세션 멈춤"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandCenter.handler?(.pause)
        return .result()
    }
}

nonisolated struct ResumeSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "세션 재개"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandCenter.handler?(.resume)
        return .result()
    }
}

nonisolated struct FinishSessionIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "마치기"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentCommandCenter.handler?(.finish)
        return .result()
    }
}
