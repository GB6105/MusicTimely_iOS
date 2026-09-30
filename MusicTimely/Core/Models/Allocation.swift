import Foundation

/// 시간 배정 (명세서 §9.1). 모든 시간 단위는 밀리초다.
nonisolated struct Allocation: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case bounded
        case infinite
    }

    var kind: Kind
    var initialDurationMs: Int64?
    var currentTargetMs: Int64?
    var durationPerUnitMs: Int64
    var loopDurationMs: Int64?
    var targetRevision: Int
    /// 현재 목표 revision이 시작된 시점의 활성 경과. 마지막 분량 예고 자격 판단에 쓴다.
    var revisionBaseElapsedMs: Int64

    static let minMinutes = 1
    static let maxMinutes = 240
    static let presetMinutes = [10, 25, 40]
    static let defaultMinutes = 25

    static func bounded(minutes: Int, unitSeconds: Int, loopSeconds: Int?) -> Allocation {
        let target = Int64(minutes) * 60_000
        return Allocation(
            kind: .bounded,
            initialDurationMs: target,
            currentTargetMs: target,
            durationPerUnitMs: Int64(unitSeconds) * 1_000,
            loopDurationMs: loopSeconds.map { Int64($0) * 1_000 },
            targetRevision: 0,
            revisionBaseElapsedMs: 0
        )
    }

    static func infinite(unitSeconds: Int, loopSeconds: Int?) -> Allocation {
        Allocation(
            kind: .infinite,
            initialDurationMs: nil,
            currentTargetMs: nil,
            durationPerUnitMs: Int64(unitSeconds) * 1_000,
            loopDurationMs: loopSeconds.map { Int64($0) * 1_000 },
            targetRevision: 0,
            revisionBaseElapsedMs: 0
        )
    }

    var isBounded: Bool { kind == .bounded }

    /// 표시 계산에 쓰는 한 단위 길이 d (명세서 §6.4).
    var unitMs: Int64 { max(1, loopDurationMs ?? durationPerUnitMs) }

    /// 직접 입력한 분 값을 검증한다 (FR-002). 1~240 정수만 허용.
    static func validateMinutes(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.allSatisfy(\.isASCIIDigit), let value = Int(trimmed) else { return nil }
        return (minMinutes...maxMinutes).contains(value) ? value : nil
    }
}

nonisolated extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
