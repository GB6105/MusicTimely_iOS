import Foundation

/// UI 테스트·스크린샷 전용 예시 상태. `-uiTesting -uiSeed <이름>`으로만 동작한다.
enum UITestSeed {
    static func apply(_ name: String, to store: StateStore, clock: ClockPort = SystemClock()) {
        let now = clock.now()
        func ago(_ seconds: Int64) -> ClockReading {
            ClockReading(monoMs: now.monoMs - seconds * 1_000, wallMs: now.wallMs - seconds * 1_000, bootID: now.bootID)
        }
        func started(_ secondsAgo: Int64) -> SessionCheckpoint {
            TimerMachine.start(
                title: "기획안 첫 문단 쓰기", allocation: .bounded(minutes: 25, unitSeconds: 240, loopSeconds: nil),
                sourceType: .externalD0, sourceProviderID: nil, displayMode: .playlist, now: ago(secondsAgo))
        }

        switch name {
        case "running":
            try? store.saveCheckpoint(started(564))
        case "lastUnit":
            var cp = started(1_310)
            cp.lastCueKey = TimerMachine.cueKey(cp)
            try? store.saveCheckpoint(cp)
        case "result":
            var cp = started(34 * 60)
            let limitAt = ago(9 * 60)
            cp = TimerMachine.apply(.reachLimit, to: cp, now: limitAt)?.checkpoint ?? cp
            cp = TimerMachine.apply(.extend(minutes: 10), to: cp, now: ago(8 * 60))?.checkpoint ?? cp
            cp = TimerMachine.apply(.finish, to: cp, now: ago(60))?.checkpoint ?? cp
            cp.resultFinalized = true
            try? store.saveCheckpoint(cp)
            let note = ThoughtNote(
                sessionID: cp.sessionID, text: "참고 자료 링크 다시 찾기", createdAtEpochMs: ago(20 * 60).wallMs)
            try? store.saveThoughts([note])
        default:
            break
        }
    }
}
