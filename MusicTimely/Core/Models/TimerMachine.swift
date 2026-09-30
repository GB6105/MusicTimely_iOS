import Foundation

/// 세션 명령 (명세서 §5.1).
nonisolated enum SessionCommand: Equatable, Sendable {
    case pause
    case resume
    case reachLimit
    case extend(minutes: Int)
    case finish
    case resumeFromRecovery
    case finishFromRecovery
}

/// 상태 전이의 부수효과. 실행은 코디네이터가 맡는다.
nonisolated enum SessionEffect: Equatable, Sendable {
    case rescheduleNotifications
    case duckOwnAudio
    case restoreOwnAudioLevel
    case fadeOutOwnAudio
    case deliverResult
}

nonisolated struct Transition: Equatable, Sendable {
    var checkpoint: SessionCheckpoint
    var effects: [SessionEffect]
}

/// 순수 상태 머신. 시계와 저장소를 직접 호출하지 않는다.
nonisolated enum TimerMachine {
    static let extensionMinutes = [5, 10, 15]
    static let infiniteRecoveryGapMs: Int64 = 24 * 60 * 60 * 1_000
    static let staleCheckpointMs: Int64 = 7 * 24 * 60 * 60 * 1_000
    static let resultRetentionMs: Int64 = 24 * 60 * 60 * 1_000
    private static let commandHistoryLimit = 20

    /// 새 세션을 RUNNING으로 만든다 (READY → START).
    static func start(
        sessionID: UUID = UUID(),
        title: String?,
        allocation: Allocation,
        sourceType: SourceType,
        sourceProviderID: String?,
        displayMode: DisplayMode,
        now: ClockReading
    ) -> SessionCheckpoint {
        SessionCheckpoint(
            sessionID: sessionID,
            state: .running,
            taskTitle: title,
            allocation: allocation,
            accumulatedActiveMs: 0,
            runningAnchorMonoMs: now.monoMs,
            anchorWallEpochMs: now.wallMs,
            bootID: now.bootID,
            startedAtEpochMs: now.wallMs,
            updatedAtEpochMs: now.wallMs,
            sourceType: sourceType,
            sourceProviderID: sourceProviderID,
            displayMode: displayMode,
            deliveryID: UUID()
        )
    }

    /// 활성 경과 E (명세서 §5.2). 유한 세션은 목표에서 clamp한다.
    static func elapsedMs(_ cp: SessionCheckpoint, now: ClockReading) -> Int64 {
        var elapsed = cp.accumulatedActiveMs
        if cp.state == .running, let anchor = cp.runningAnchorMonoMs, cp.bootID == now.bootID {
            elapsed += max(0, now.monoMs - anchor)
        }
        if cp.allocation.isBounded, let target = cp.allocation.currentTargetMs {
            elapsed = min(elapsed, target)
        }
        return elapsed
    }

    static func remainingMs(_ cp: SessionCheckpoint, now: ClockReading) -> Int64? {
        guard cp.allocation.isBounded, let target = cp.allocation.currentTargetMs else { return nil }
        return max(0, target - elapsedMs(cp, now: now))
    }

    static func hasReachedLimit(_ cp: SessionCheckpoint, now: ClockReading) -> Bool {
        cp.state == .running && remainingMs(cp, now: now) == 0
    }

    /// 명령을 적용한다. 현재 상태에서 의미 없는 명령이나 이미 처리한 commandID는 nil (멱등).
    static func apply(
        _ command: SessionCommand,
        to cp: SessionCheckpoint,
        now: ClockReading,
        commandID: UUID? = nil
    ) -> Transition? {
        if let commandID, cp.processedCommandIDs.contains(commandID) { return nil }
        var next = cp
        var effects: [SessionEffect] = []

        switch (command, cp.state) {
        case (.pause, .running):
            // 같은 tick에 목표를 지났다면 정지 대신 도달로 정규화한다.
            if hasReachedLimit(cp, now: now) { return apply(.reachLimit, to: cp, now: now, commandID: commandID) }
            next.accumulatedActiveMs = elapsedMs(cp, now: now)
            next.runningAnchorMonoMs = nil
            next.anchorWallEpochMs = nil
            next.state = .paused
            effects = [.rescheduleNotifications, .duckOwnAudio]

        case (.resume, .paused):
            next.runningAnchorMonoMs = now.monoMs
            next.anchorWallEpochMs = now.wallMs
            next.bootID = now.bootID
            next.state = .running
            effects = [.rescheduleNotifications, .restoreOwnAudioLevel]

        case (.reachLimit, .running):
            guard cp.allocation.isBounded, let target = cp.allocation.currentTargetMs else { return nil }
            next.accumulatedActiveMs = target
            next.runningAnchorMonoMs = nil
            next.anchorWallEpochMs = nil
            next.state = .limitReached
            effects = [.rescheduleNotifications, .fadeOutOwnAudio]

        case (.extend(let minutes), .limitReached):
            guard extensionMinutes.contains(minutes), let target = cp.allocation.currentTargetMs else { return nil }
            let added = Int64(minutes) * 60_000
            next.allocation.currentTargetMs = target + added
            next.allocation.targetRevision += 1
            next.allocation.revisionBaseElapsedMs = cp.accumulatedActiveMs
            next.extensions.append(.init(addedMs: added, acceptedAtEpochMs: now.wallMs))
            next.runningAnchorMonoMs = now.monoMs
            next.anchorWallEpochMs = now.wallMs
            next.bootID = now.bootID
            next.state = .running
            // 연장은 타이머만 재개한다. 자체 소리는 별도 재생 탭이 필요하다.
            effects = [.rescheduleNotifications]

        case (.finish, .running), (.finish, .paused), (.finish, .limitReached):
            let elapsed = elapsedMs(cp, now: now)
            next.accumulatedActiveMs = elapsed
            next.runningAnchorMonoMs = nil
            next.anchorWallEpochMs = nil
            next.state = .ended
            next.endedAtEpochMs = now.wallMs
            next.endReason = endReason(for: cp.allocation, elapsedMs: elapsed)
            effects = [.rescheduleNotifications, .fadeOutOwnAudio, .deliverResult]

        case (.resumeFromRecovery, .recoveryRequired):
            // 저장된 확정 지점에서 멈춘 상태로 이어간다. 불확실한 구간은 더하지 않는다.
            next.runningAnchorMonoMs = nil
            next.anchorWallEpochMs = nil
            next.bootID = now.bootID
            next.recoveryReason = nil
            if cp.allocation.isBounded, let target = cp.allocation.currentTargetMs, cp.accumulatedActiveMs >= target {
                next.accumulatedActiveMs = target
                next.state = .limitReached
            } else {
                next.state = .paused
            }
            effects = [.rescheduleNotifications]

        case (.finishFromRecovery, .recoveryRequired):
            next.runningAnchorMonoMs = nil
            next.anchorWallEpochMs = nil
            next.state = .ended
            next.endedAtEpochMs = now.wallMs
            next.endReason = .abandoned
            next.recoveryReason = nil
            effects = [.rescheduleNotifications, .deliverResult]

        default:
            return nil
        }

        next.updatedAtEpochMs = now.wallMs
        if let commandID {
            next.processedCommandIDs = Array((cp.processedCommandIDs + [commandID]).suffix(commandHistoryLimit))
        }
        return Transition(checkpoint: next, effects: effects)
    }

    static func endReason(for allocation: Allocation, elapsedMs: Int64) -> EndReason {
        guard allocation.isBounded, let initial = allocation.initialDurationMs else { return .userEnded }
        return elapsedMs >= initial ? .completed : .userEnded
    }

    // MARK: - 복원 (명세서 §5.2, §7.2, §8)

    enum RestoreOutcome: Equatable, Sendable {
        /// 그대로 복원. 필요하면 LIMIT_REACHED로 정규화된 상태.
        case restored(SessionCheckpoint)
        /// 결과 보존 기간이 지나 폐기해야 한다.
        case discard
        case recoveryRequired(SessionCheckpoint)
    }

    static func restore(_ cp: SessionCheckpoint, now: ClockReading) -> RestoreOutcome {
        switch cp.state {
        case .ready:
            return .discard
        case .ended:
            let endedAt = cp.endedAtEpochMs ?? cp.updatedAtEpochMs
            return now.wallMs - endedAt > resultRetentionMs ? .discard : .restored(cp)
        case .recoveryRequired:
            return .recoveryRequired(cp)
        case .paused, .limitReached:
            if now.wallMs - cp.updatedAtEpochMs > staleCheckpointMs {
                return .recoveryRequired(requireRecovery(cp, .staleCheckpoint, now))
            }
            return .restored(cp)
        case .running:
            if now.wallMs - cp.updatedAtEpochMs > staleCheckpointMs {
                return .recoveryRequired(requireRecovery(cp, .staleCheckpoint, now))
            }
            guard cp.bootID == now.bootID, let anchor = cp.runningAnchorMonoMs, now.monoMs >= anchor else {
                return .recoveryRequired(requireRecovery(cp, .clockDiscontinuity, now))
            }
            if !cp.allocation.isBounded, now.monoMs - anchor >= infiniteRecoveryGapMs {
                return .recoveryRequired(requireRecovery(cp, .longInfiniteGap, now))
            }
            if hasReachedLimit(cp, now: now), let transition = apply(.reachLimit, to: cp, now: now) {
                return .restored(transition.checkpoint)
            }
            return .restored(cp)
        }
    }

    private static func requireRecovery(_ cp: SessionCheckpoint, _ reason: RecoveryReason, _ now: ClockReading)
        -> SessionCheckpoint
    {
        var next = cp
        // 확정 저장된 지점까지만 인정한다. 그 이후는 추정이라 더하지 않는다.
        var confirmed = max(cp.accumulatedActiveMs, cp.confirmedActiveMs ?? 0)
        if let target = cp.allocation.currentTargetMs { confirmed = min(confirmed, target) }
        next.accumulatedActiveMs = confirmed
        next.state = .recoveryRequired
        next.recoveryReason = reason
        next.runningAnchorMonoMs = nil
        next.anchorWallEpochMs = nil
        return next
    }

    // MARK: - 마지막 분량 예고 (명세서 §6.5, FR-017)

    static func cueKey(_ cp: SessionCheckpoint) -> String {
        "\(cp.sessionID.uuidString):\(cp.allocation.targetRevision)"
    }

    /// 예고를 낼 차례인지. revision당 한 번.
    static func shouldCueLastUnit(_ cp: SessionCheckpoint, now: ClockReading) -> Bool {
        cp.state == .running && isInLastUnit(cp, now: now) && cp.lastCueKey != cueKey(cp)
    }

    /// 현재 revision이 한 단위보다 길었는지. 짧은 배정은 시작하자마자 끝 예고를 하지 않는다 (§6.1 T=120 예시).
    static func isCueEligible(_ cp: SessionCheckpoint) -> Bool {
        guard let target = cp.allocation.currentTargetMs else { return false }
        return target - cp.allocation.revisionBaseElapsedMs > cp.allocation.unitMs
    }

    /// 마지막 한 단위 구간인지 (표시·예고 공용). 곡 표시 OFF에서는 일반 끝 예고로 쓴다 (FR-020).
    static func isInLastUnit(_ cp: SessionCheckpoint, now: ClockReading) -> Bool {
        guard isCueEligible(cp), let remaining = remainingMs(cp, now: now) else { return false }
        return remaining > 0 && remaining <= cp.allocation.unitMs
    }
}
