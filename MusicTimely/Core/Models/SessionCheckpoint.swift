import Foundation

/// 영속 저장하는 세션 상태 (명세서 §9.1). 곡 메타데이터는 넣지 않는다.
nonisolated struct SessionCheckpoint: Codable, Equatable, Sendable {
    struct Extension: Codable, Equatable, Sendable {
        var addedMs: Int64
        var acceptedAtEpochMs: Int64
    }

    struct Correction: Codable, Equatable, Sendable {
        var anchorIndex: Int
        var anchorActiveMs: Int64
    }

    static let currentSchemaVersion = 1

    var schemaVersion: Int = SessionCheckpoint.currentSchemaVersion
    var sessionID: UUID
    var state: TimerState
    var taskTitle: String?
    var allocation: Allocation
    var accumulatedActiveMs: Int64
    /// 마지막으로 확정 저장한 활성 경과 (백그라운드 진입·주기 저장 시). 복구 때 이 지점까지만 인정한다.
    var confirmedActiveMs: Int64?
    var runningAnchorMonoMs: Int64?
    var anchorWallEpochMs: Int64?
    var bootID: String
    var startedAtEpochMs: Int64
    var updatedAtEpochMs: Int64
    var endedAtEpochMs: Int64?
    var sourceType: SourceType
    var sourceProviderID: String?
    var displayMode: DisplayMode
    var lastCueKey: String?
    var extensions: [Extension] = []
    var correction: Correction?
    /// 결과 화면에서 사용자가 고친 전체 곡 분량. 설정되면 출처는 manual.
    var resultCorrectedUnits: Int?
    var perceivedMinutes: Int?
    var endReason: EndReason?
    var recoveryReason: RecoveryReason?
    var deliveryID: UUID
    var resultFinalized: Bool = false
    /// 최근 처리한 명령 ID (멱등 처리, 명세서 §5.1).
    var processedCommandIDs: [UUID] = []

    var confidence: Confidence {
        if resultCorrectedUnits != nil { return .manual }
        return correction == nil ? .estimated : .mixed
    }

    var extensionUsed: Bool { !extensions.isEmpty }
}
