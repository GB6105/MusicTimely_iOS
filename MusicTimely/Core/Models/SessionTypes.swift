import Foundation

/// 세션 타이머 상태 (명세서 §5.1).
nonisolated enum TimerState: String, Codable, Sendable {
    case ready
    case running
    case paused
    case limitReached = "limit_reached"
    case ended
    case recoveryRequired = "recovery_required"

    var isActive: Bool { self == .running || self == .paused || self == .limitReached }
}

/// 종료 사유 (명세서 §5.1).
nonisolated enum EndReason: String, Codable, Sendable {
    case completed
    case userEnded = "user_ended"
    case abandoned
}

/// 음악 소스 종류 (명세서 §9.1). 로컬 파일(O0)은 P3 범위라 정의만 둔다.
nonisolated enum SourceType: String, Codable, Sendable {
    case externalD0 = "external_d0"
    case builtinNoise = "builtin_noise"
    case localO0 = "local_o0"
    case none
}

/// 곡 표시 방식 (명세서 §9.1, §6.4).
nonisolated enum DisplayMode: String, Codable, Sendable, CaseIterable {
    case playlist
    case singleLoop = "single_loop"
    case timeOnly = "time_only"
}

/// 곡 분량 값의 출처 (명세서 §9.1).
nonisolated enum Confidence: String, Codable, Sendable {
    case estimated
    case observed
    case manual
    case mixed
    case unknown
}

/// 복구가 필요한 이유 (명세서 §8).
nonisolated enum RecoveryReason: String, Codable, Sendable {
    case clockDiscontinuity = "clock_discontinuity"
    case corruptCheckpoint = "corrupt_checkpoint"
    case staleCheckpoint = "stale_checkpoint"
    case longInfiniteGap = "long_infinite_gap"
}

/// 시계 판독값. 단조 시계는 기기 sleep을 포함한다 (명세서 §5.2).
nonisolated struct ClockReading: Equatable, Sendable {
    var monoMs: Int64
    var wallMs: Int64
    var bootID: String
}
