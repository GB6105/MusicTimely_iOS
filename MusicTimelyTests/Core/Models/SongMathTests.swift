import Foundation
import Testing

@testable import MusicTimely

struct SongMathTests {
    @Test("QA-02: 25분·평균 4분 → 약 7곡 분량, 목표는 그대로")
    func plannedUnits() {
        #expect(SongMath.plannedUnits(targetMs: 1_500_000, unitMs: 240_000) == 7)
        #expect(Allocation.bounded(minutes: 25, unitSeconds: 240, loopSeconds: nil).currentTargetMs == 1_500_000)
    }

    @Test("QA-14: 09:24 시점 25분 목표 → 약 4곡 분량 남음, 경과 약 2.4곡")
    func remainingAt924() {
        #expect(SongMath.remainingUnits(targetMs: 1_500_000, elapsedMs: 564_000, unitMs: 240_000) == 4)
        #expect(SongMath.format(SongMath.elapsedUnits(elapsedMs: 564_000, unitMs: 240_000)) == "2.4")
        #expect(SongMath.segmentIndex(elapsedMs: 564_000, unitMs: 240_000, correction: nil) == 3)
    }

    @Test("짧은 배정도 최소 1곡 분량")
    func minimumOneUnit() {
        #expect(SongMath.plannedUnits(targetMs: 120_000, unitMs: 240_000) == 1)
        #expect(SongMath.format(2.0) == "2")
    }

    @Test("QA-15: 보정은 표시 인덱스만 바꾼다")
    func correctionShiftsIndexOnly() {
        let correction = SessionCheckpoint.Correction(anchorIndex: 5, anchorActiveMs: 300_000)
        #expect(SongMath.segmentIndex(elapsedMs: 300_000, unitMs: 240_000, correction: correction) == 5)
        #expect(SongMath.segmentIndex(elapsedMs: 540_000, unitMs: 240_000, correction: correction) == 6)
    }

    @Test("칩: 채움·현재·빈칸, 목표 도달 시 모두 채움")
    func chips() {
        #expect(
            SongMath.chips(targetMs: 1_500_000, elapsedMs: 564_000, unitMs: 240_000)
                == [.filled, .filled, .current, .empty, .empty, .empty, .empty])
        #expect(
            SongMath.chips(targetMs: 1_500_000, elapsedMs: 1_500_000, unitMs: 240_000)
                == Array(repeating: .filled, count: 7))
    }

    @Test("FR-021: 8개를 넘으면 칩 대신 그룹 표시")
    func manyUnitsAreGrouped() {
        #expect(SongMath.chips(targetMs: 60 * 60_000, elapsedMs: 0, unitMs: 240_000) == nil)
    }

    @Test("M3: 목표 도달 후 구간 인덱스는 마지막 곡을 넘지 않는다")
    func indexClampedAtTarget() {
        #expect(SongMath.segmentIndex(elapsedMs: 1_200_000, unitMs: 240_000, correction: nil, targetMs: 1_200_000) == 5)
        #expect(SongMath.segmentIndex(elapsedMs: 1_199_000, unitMs: 240_000, correction: nil, targetMs: 1_200_000) == 5)
    }

    @Test("한국어 서수")
    func ordinals() {
        #expect(SongMath.koreanOrdinal(1) == "첫 번째")
        #expect(SongMath.koreanOrdinal(3) == "세 번째")
        #expect(SongMath.koreanOrdinal(12) == "12번째")
    }
}

struct CueTests {
    private let clock = FakeClock()

    private func started(minutes: Int) -> SessionCheckpoint {
        TimerMachine.start(
            title: nil, allocation: .bounded(minutes: minutes, unitSeconds: 240, loopSeconds: nil),
            sourceType: .externalD0, sourceProviderID: nil, displayMode: .playlist, now: clock.now())
    }

    @Test("QA-16: 남은 시간이 한 곡 이하가 되면 revision당 한 번")
    func cueOncePerRevision() {
        var cp = started(minutes: 25)
        clock.advance(seconds: 20 * 60)
        #expect(!TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
        clock.advance(seconds: 60)
        #expect(TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
        cp.lastCueKey = TimerMachine.cueKey(cp)
        clock.advance(seconds: 30)
        #expect(!TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
    }

    @Test("QA-17: 2분 배정은 시작 직후 예고하지 않는다")
    func noCueForShortAllocation() {
        let cp = started(minutes: 2)
        clock.advance(seconds: 1)
        #expect(!TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
    }

    @Test("FR-020: 곡 표시 OFF에서도 일반 끝 예고는 한 번 낸다")
    func genericCueInTimeOnly() {
        var cp = started(minutes: 25)
        cp.displayMode = .timeOnly
        clock.advance(seconds: 22 * 60)
        #expect(TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
    }

    @Test("M2: 짧은 배정은 시작 직후 마지막 분량으로 표시하지 않는다")
    func shortAllocationIsNotLastUnit() {
        let cp = started(minutes: 2)
        clock.advance(seconds: 1)
        #expect(!TimerMachine.isInLastUnit(cp, now: clock.now()))
    }

    @Test("연장 후 새 revision에서 예고가 다시 한 번 가능")
    func cueAfterExtension() throws {
        var cp = started(minutes: 25)
        clock.advance(seconds: 22 * 60)
        cp.lastCueKey = TimerMachine.cueKey(cp)
        clock.advance(seconds: 3 * 60)
        cp = try #require(TimerMachine.apply(.reachLimit, to: cp, now: clock.now())).checkpoint
        cp = try #require(TimerMachine.apply(.extend(minutes: 10), to: cp, now: clock.now())).checkpoint
        clock.advance(seconds: 7 * 60)
        #expect(TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
    }
}
