import ActivityKit
import Foundation
import OSLog

/// 세션 상태를 잠금화면 Live Activity로 반영한다. 실패해도 세션에는 영향이 없다.
final class LiveActivityController {
    private var activity: Activity<SessionActivityAttributes>?
    private var lastState: SessionActivityAttributes.ContentState?
    private let log = Logger(subsystem: "com.gb6105.MusicTimely", category: "live-activity")
    /// 결과 카드를 잠금화면에 남겨 두는 시간.
    static let endedLingerSeconds: TimeInterval = 60 * 60

    init() {
        activity = Activity<SessionActivityAttributes>.activities.first
    }

    func sync(_ cp: SessionCheckpoint?, display: SessionDisplay?, privateMode: Bool, now: Date = .now) {
        guard let cp, let display, cp.state != .ready, cp.state != .recoveryRequired else {
            endAll()
            return
        }
        let state = Self.contentState(cp, display: display, privateMode: privateMode, now: now)
        guard state != lastState || activity == nil else { return }
        lastState = state
        let content = ActivityContent(state: state, staleDate: Self.staleDate(state, now: now))

        if cp.state == .ended {
            guard let id = activity?.id else { return }
            let policy = ActivityUIDismissalPolicy.after(now.addingTimeInterval(Self.endedLingerSeconds))
            Task { await Self.end(id, content: content, policy: policy) }
            self.activity = nil
            return
        }
        if let activity, activity.attributes.sessionID == cp.sessionID.uuidString {
            let id = activity.id
            Task { await Self.update(id, content: content) }
            return
        }
        endAll()
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            log.notice("live activities disabled by user")
            return
        }
        do {
            activity = try Activity.request(
                attributes: SessionActivityAttributes(sessionID: cp.sessionID.uuidString), content: content,
                pushType: nil)
            log.notice("live activity started")
        } catch {
            log.error("live activity request failed: \(String(describing: error), privacy: .public)")
        }
    }

    func endAll() {
        lastState = nil
        activity = nil
        // 지금 있는 것만 끝낸다. 바로 뒤에 새로 요청한 Activity까지 끝내지 않도록 ID를 먼저 확정한다.
        let ids = Activity<SessionActivityAttributes>.activities.map(\.id)
        guard !ids.isEmpty else { return }
        Task { await Self.endImmediately(ids) }
    }

    nonisolated private static func endImmediately(_ ids: [String]) async {
        for running in Activity<SessionActivityAttributes>.activities where ids.contains(running.id) {
            await running.end(nil, dismissalPolicy: .immediate)
        }
    }

    /// Activity는 Sendable이 아니므로 격리 없는 문맥에서 ID로 찾아 바로 쓴다.
    nonisolated private static func update(
        _ id: String, content: ActivityContent<SessionActivityAttributes.ContentState>
    ) async {
        await Activity<SessionActivityAttributes>.activities.first { $0.id == id }?.update(content)
    }

    nonisolated private static func end(
        _ id: String, content: ActivityContent<SessionActivityAttributes.ContentState>,
        policy: ActivityUIDismissalPolicy
    ) async {
        await Activity<SessionActivityAttributes>.activities.first { $0.id == id }?.end(
            content, dismissalPolicy: policy)
    }

    static func contentState(
        _ cp: SessionCheckpoint, display d: SessionDisplay, privateMode: Bool, now: Date
    ) -> SessionActivityAttributes.ContentState {
        let phase: SessionActivityAttributes.ContentState.Phase =
            switch cp.state {
            case .running: .running
            case .paused: .paused
            case .limitReached: .limitReached
            default: .ended
            }
        return .init(
            phase: phase,
            isInfinite: !cp.allocation.isBounded,
            privateMode: privateMode,
            timeOnly: cp.displayMode == .timeOnly,
            elapsedOrigin: now.addingTimeInterval(-Double(d.elapsedMs) / 1_000),
            elapsedMs: d.elapsedMs,
            targetMs: d.targetMs,
            initialMs: d.initialMs,
            unitMs: cp.allocation.unitMs,
            segmentIndex: d.segmentIndex,
            isLastUnit: d.isLastUnit
        )
    }

    /// 진행 중이면 다음 곡 경계(또는 목표 시각)에서 오래된 정보로 표시된다. 그 뒤 문구는 일반형으로 바뀐다.
    static func staleDate(_ s: SessionActivityAttributes.ContentState, now: Date) -> Date? {
        guard s.phase == .running else { return nil }
        let unit = Double(s.unitMs) / 1_000
        let elapsed = Double(s.elapsedMs) / 1_000
        var next = now.addingTimeInterval(unit - elapsed.truncatingRemainder(dividingBy: unit))
        if let end = s.targetEnd { next = min(next, end) }
        return next
    }
}
