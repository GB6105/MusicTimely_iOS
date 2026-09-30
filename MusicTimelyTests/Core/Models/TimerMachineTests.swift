import Foundation
import Testing

@testable import MusicTimely

struct TimerMachineTests {
    private let clock = FakeClock()

    private func started(minutes: Int = 25, infinite: Bool = false) -> SessionCheckpoint {
        TimerMachine.start(
            title: "기획안",
            allocation: infinite
                ? .infinite(unitSeconds: 240, loopSeconds: nil)
                : .bounded(minutes: minutes, unitSeconds: 240, loopSeconds: nil),
            sourceType: .externalD0, sourceProviderID: nil, displayMode: .playlist, now: clock.now())
    }

    private func apply(_ command: SessionCommand, _ cp: SessionCheckpoint) throws -> SessionCheckpoint {
        try #require(TimerMachine.apply(command, to: cp, now: clock.now())).checkpoint
    }

    @Test("QA-05: 60초 진행, 30초 정지, 60초 진행 = 120초")
    func pauseResumeCountsOnlyActiveTime() throws {
        var cp = started()
        clock.advance(seconds: 60)
        cp = try apply(.pause, cp)
        clock.advance(seconds: 30)
        cp = try apply(.resume, cp)
        clock.advance(seconds: 60)
        #expect(TimerMachine.elapsedMs(cp, now: clock.now()) == 120_000)
    }

    @Test("QA-04: 이미 진행 중이면 같은 명령은 무시된다 (멱등)")
    func repeatedCommandsAreIdempotent() throws {
        let cp = started()
        #expect(TimerMachine.apply(.resume, to: cp, now: clock.now()) == nil)
        let id = UUID()
        let paused = try #require(TimerMachine.apply(.pause, to: cp, now: clock.now(), commandID: id)).checkpoint
        #expect(TimerMachine.apply(.pause, to: paused, now: clock.now(), commandID: id) == nil)
        #expect(TimerMachine.apply(.resume, to: paused, now: clock.now(), commandID: id) == nil)
    }

    @Test("FR-010: 목표 이후에는 경과가 목표에서 멈춘다")
    func elapsedClampsAtTarget() throws {
        let cp = started(minutes: 1)
        clock.advance(seconds: 200)
        #expect(TimerMachine.elapsedMs(cp, now: clock.now()) == 60_000)
        #expect(TimerMachine.hasReachedLimit(cp, now: clock.now()))
        let limit = try apply(.reachLimit, cp)
        #expect(limit.state == .limitReached)
        #expect(limit.accumulatedActiveMs == 60_000)
    }

    @Test("QA-09: 도달 후 2분 대기, +5분, 3분 후 마침 → 최초 25분, 활성 28분")
    func extensionExcludesWaitingTime() throws {
        var cp = started(minutes: 25)
        clock.advance(seconds: 25 * 60)
        cp = try apply(.reachLimit, cp)
        clock.advance(seconds: 120)
        cp = try apply(.extend(minutes: 5), cp)
        #expect(cp.allocation.initialDurationMs == Int64(25 * 60_000))
        #expect(cp.allocation.currentTargetMs == Int64(30 * 60_000))
        #expect(cp.allocation.targetRevision == 1)
        clock.advance(seconds: 180)
        cp = try apply(.finish, cp)
        #expect(cp.accumulatedActiveMs == 28 * 60_000)
        #expect(cp.extensionUsed)
        #expect(cp.endReason == .completed)
    }

    @Test("연장은 +5/+10/+15분만 허용한다")
    func onlyAllowedExtensions() throws {
        var cp = started(minutes: 1)
        clock.advance(seconds: 60)
        cp = try apply(.reachLimit, cp)
        #expect(TimerMachine.apply(.extend(minutes: 7), to: cp, now: clock.now()) == nil)
    }

    @Test("종료 사유: 최초 배정 전 종료는 user_ended, 무한은 user_ended")
    func endReasons() throws {
        var cp = started(minutes: 25)
        clock.advance(seconds: 60)
        cp = try apply(.finish, cp)
        #expect(cp.endReason == .userEnded)
        var infinite = started(infinite: true)
        clock.advance(seconds: 3_600)
        infinite = try apply(.finish, infinite)
        #expect(infinite.endReason == .userEnded)
        #expect(infinite.accumulatedActiveMs == 3_600_000)
    }

    @Test("같은 tick에 목표 도달과 정지가 겹치면 도달로 정규화한다")
    func pauseAfterTargetBecomesLimit() throws {
        let cp = started(minutes: 1)
        clock.advance(seconds: 61)
        let next = try apply(.pause, cp)
        #expect(next.state == .limitReached)
    }

    @Test("QA-10: 무한 모드는 잔여와 목표가 없다")
    func infiniteHasNoRemaining() {
        let cp = started(infinite: true)
        clock.advance(seconds: 1_200)
        #expect(TimerMachine.remainingMs(cp, now: clock.now()) == nil)
        #expect(!TimerMachine.hasReachedLimit(cp, now: clock.now()))
        #expect(!TimerMachine.shouldCueLastUnit(cp, now: clock.now()))
    }

    @Test("QA-11: 같은 boot에서 벽시계를 바꿔도 경과는 그대로")
    func wallClockChangeDoesNotAffectElapsed() {
        let cp = started()
        clock.advance(seconds: 100)
        clock.reading.wallMs += 3_600_000
        #expect(TimerMachine.elapsedMs(cp, now: clock.now()) == 100_000)
    }
}

struct RestoreTests {
    private let clock = FakeClock()

    private func started(minutes: Int = 25, infinite: Bool = false) -> SessionCheckpoint {
        TimerMachine.start(
            title: nil,
            allocation: infinite
                ? .infinite(unitSeconds: 240, loopSeconds: nil)
                : .bounded(minutes: minutes, unitSeconds: 240, loopSeconds: nil),
            sourceType: .externalD0, sourceProviderID: nil, displayMode: .playlist, now: clock.now())
    }

    @Test("QA-06: 백그라운드 10분 후 복귀하면 tick 없이 시간이 이어진다")
    func restoresRunningSession() throws {
        let cp = started()
        clock.advance(seconds: 600)
        guard case .restored(let restored) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복원되어야 한다")
            return
        }
        #expect(restored.state == .running)
        #expect(TimerMachine.elapsedMs(restored, now: clock.now()) == 600_000)
    }

    @Test("QA-07: 일시정지 중 종료 후 재시작해도 시간이 늘지 않는다")
    func pausedStaysPaused() throws {
        var cp = started()
        clock.advance(seconds: 90)
        cp = try #require(TimerMachine.apply(.pause, to: cp, now: clock.now())).checkpoint
        clock.advance(seconds: 3_000)
        guard case .restored(let restored) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복원되어야 한다")
            return
        }
        #expect(restored.state == .paused)
        #expect(TimerMachine.elapsedMs(restored, now: clock.now()) == 90_000)
    }

    @Test("QA-08: 목표 이전에 종료되고 목표 이후 재실행하면 목표에서 도달 상태")
    func restoresAtLimit() {
        let cp = started(minutes: 25)
        clock.advance(seconds: 40 * 60)
        guard case .restored(let restored) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복원되어야 한다")
            return
        }
        #expect(restored.state == .limitReached)
        #expect(restored.accumulatedActiveMs == 25 * 60_000)
    }

    @Test("QA-12: 재부팅이면 추정값 없이 복구 선택")
    func rebootRequiresRecovery() throws {
        var cp = started()
        clock.advance(seconds: 120)
        cp = try #require(TimerMachine.apply(.pause, to: cp, now: clock.now())).checkpoint
        cp = try #require(TimerMachine.apply(.resume, to: cp, now: clock.now())).checkpoint
        clock.reboot(after: 600)
        guard case .recoveryRequired(let recovery) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복구가 필요해야 한다")
            return
        }
        #expect(recovery.state == .recoveryRequired)
        #expect(recovery.recoveryReason == .clockDiscontinuity)
        let resumed = try #require(TimerMachine.apply(.resumeFromRecovery, to: recovery, now: clock.now())).checkpoint
        #expect(resumed.state == .paused)
        #expect(resumed.accumulatedActiveMs == 120_000)
        let finished = try #require(TimerMachine.apply(.finishFromRecovery, to: recovery, now: clock.now())).checkpoint
        #expect(finished.endReason == .abandoned)
    }

    @Test("M5: 재부팅 복구는 마지막 확정 지점까지 인정한다")
    func recoveryKeepsConfirmedProgress() throws {
        var cp = started()
        clock.advance(seconds: 20 * 60)
        cp.confirmedActiveMs = TimerMachine.elapsedMs(cp, now: clock.now())
        clock.reboot(after: 60)
        guard case .recoveryRequired(let recovery) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복구가 필요해야 한다")
            return
        }
        #expect(recovery.accumulatedActiveMs == 20 * 60_000)
        let resumed = try #require(TimerMachine.apply(.resumeFromRecovery, to: recovery, now: clock.now())).checkpoint
        #expect(TimerMachine.elapsedMs(resumed, now: clock.now()) == 20 * 60_000)
    }

    @Test("7일 넘은 저장본은 자동 복원하지 않는다")
    func staleCheckpointRequiresRecovery() {
        let cp = started()
        clock.advance(seconds: 8 * 24 * 3_600)
        guard case .recoveryRequired(let recovery) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복구가 필요해야 한다")
            return
        }
        #expect(recovery.recoveryReason == .staleCheckpoint)
    }

    @Test("무한 모드 24시간 이상 공백은 복구 확인")
    func longInfiniteGap() {
        let cp = started(infinite: true)
        clock.advance(seconds: 25 * 3_600)
        guard case .recoveryRequired(let recovery) = TimerMachine.restore(cp, now: clock.now()) else {
            Issue.record("복구가 필요해야 한다")
            return
        }
        #expect(recovery.recoveryReason == .longInfiniteGap)
    }

    @Test("결과는 24시간이 지나면 폐기")
    func endedResultExpires() throws {
        var cp = started()
        clock.advance(seconds: 60)
        cp = try #require(TimerMachine.apply(.finish, to: cp, now: clock.now())).checkpoint
        clock.advance(seconds: 3_600)
        #expect(TimerMachine.restore(cp, now: clock.now()) == .restored(cp))
        clock.advance(seconds: 24 * 3_600)
        #expect(TimerMachine.restore(cp, now: clock.now()) == .discard)
    }
}
