import Foundation

/// D0 곡 분량 환산 (명세서 §6.1, §6.2). 표시 전용이며 타이머 목표를 바꾸지 않는다.
nonisolated enum SongMath {
    static let maxVisibleChips = 8

    enum Chip: Equatable, Sendable {
        case filled
        case current
        case empty
    }

    /// 배정 표시 N = max(1, ceil(T / d)).
    static func plannedUnits(targetMs: Int64, unitMs: Int64) -> Int {
        max(1, Int(ceilDiv(targetMs, unitMs)))
    }

    /// 잔여 표시 R = max(0, ceil((G - E) / d)).
    static func remainingUnits(targetMs: Int64, elapsedMs: Int64, unitMs: Int64) -> Int {
        max(0, Int(ceilDiv(max(0, targetMs - elapsedMs), unitMs)))
    }

    /// 경과 분량 U = E / d, 소수 첫째 자리 반올림.
    static func elapsedUnits(elapsedMs: Int64, unitMs: Int64) -> Double {
        (Double(elapsedMs) / Double(unitMs) * 10).rounded() / 10
    }

    /// "2.4" 또는 정수면 "2".
    static func format(_ units: Double) -> String {
        units == units.rounded() ? String(Int(units)) : String(format: "%.1f", units)
    }

    /// 구간 인덱스 I = floor(E / d) + 1. 보정이 있으면 k + floor((E - anchor) / d).
    /// 목표에 도달하면 다음 구간을 새로 표시하지 않는다 (§6.1).
    static func segmentIndex(
        elapsedMs: Int64, unitMs: Int64, correction: SessionCheckpoint.Correction?, targetMs: Int64? = nil
    ) -> Int {
        var elapsed = elapsedMs
        if let targetMs, elapsed >= targetMs { elapsed = max(0, targetMs - 1) }
        guard let correction else { return Int(elapsed / unitMs) + 1 }
        return correction.anchorIndex + Int(max(0, elapsed - correction.anchorActiveMs) / unitMs)
    }

    /// 진행 칩. 목표 분량이 8개를 넘으면 nil (그룹 표시, FR-021).
    static func chips(targetMs: Int64, elapsedMs: Int64, unitMs: Int64) -> [Chip]? {
        let count = plannedUnits(targetMs: targetMs, unitMs: unitMs)
        guard count <= maxVisibleChips else { return nil }
        let filled = elapsedMs >= targetMs ? count : min(count, Int(elapsedMs / unitMs))
        return (0..<count).map { index in
            if index < filled { return .filled }
            return index == filled ? .current : .empty
        }
    }

    /// 한국어 서수 ("첫 번째", "세 번째", "12번째").
    static func koreanOrdinal(_ n: Int) -> String {
        let words = ["첫", "두", "세", "네", "다섯", "여섯", "일곱", "여덟", "아홉", "열"]
        return (1...words.count).contains(n) ? "\(words[n - 1]) 번째" : "\(n)번째"
    }

    private static func ceilDiv(_ a: Int64, _ b: Int64) -> Int64 {
        (a + b - 1) / b
    }
}
