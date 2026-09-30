import Foundation

/// 호스트에 전달하는 시간 중심 결과 (명세서 §9.4 onSessionResult). 곡 수는 넣지 않는다.
nonisolated struct SessionResult: Equatable, Sendable {
    var sessionID: UUID
    var deliveryID: UUID
    var initialDurationMs: Int64?
    var activeDurationMs: Int64
    var endReason: EndReason
    var extensionUsed: Bool
}

/// 호스트 어댑터. 실패해도 세션 상태와 UI에 영향을 주지 않는다 (FR-040).
protocol SessionResultSink {
    func deliver(_ result: SessionResult) async -> Bool
}

/// 독립 실행용 기본 어댑터. 서버로 보내지 않는다.
final class StandaloneResultSink: SessionResultSink {
    private(set) var deliveredIDs: Set<UUID> = []

    func deliver(_ result: SessionResult) async -> Bool {
        deliveredIDs.insert(result.deliveryID)
        return true
    }
}
