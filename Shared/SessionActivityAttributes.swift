import ActivityKit
import Foundation

/// 잠금화면 Live Activity·Dynamic Island 데이터. 작업 제목·곡명은 넣지 않는다 (명세서 §7.1).
nonisolated struct SessionActivityAttributes: ActivityAttributes {
    nonisolated struct ContentState: Codable, Hashable, Sendable {
        enum Phase: String, Codable, Hashable, Sendable {
            case running
            case paused
            case limitReached
            case ended
        }

        var phase: Phase
        var isInfinite: Bool
        /// 잠금화면에 세부 정보를 숨긴다 (피그마 Private).
        var privateMode: Bool
        /// 곡 대신 시간만 표시한다.
        var timeOnly: Bool
        /// 경과 0초가 되는 가상의 시작 시각. 진행 중이면 이 시각부터 경과가 흐른다.
        var elapsedOrigin: Date
        /// 갱신 시점의 경과 (멈춤·종료 상태 표시용).
        var elapsedMs: Int64
        var targetMs: Int64?
        var initialMs: Int64?
        var unitMs: Int64
        var segmentIndex: Int
        var isLastUnit: Bool

        var targetEnd: Date? { targetMs.map { elapsedOrigin.addingTimeInterval(Double($0) / 1_000) } }
        var totalUnits: Int? {
            targetMs.map { max(1, Int(($0 + unitMs - 1) / unitMs)) }
        }
        var plannedUnits: Int? {
            initialMs.map { max(1, Int(($0 + unitMs - 1) / unitMs)) }
        }
    }

    var sessionID: String
}

/// 앱을 여는 딥링크. 잠금화면의 "결과 보기", "잠금 해제 후 확인"에서 쓴다.
nonisolated enum AppLink {
    static var session: URL { URL(string: "musictimely://session") ?? URL(filePath: "/") }
}
