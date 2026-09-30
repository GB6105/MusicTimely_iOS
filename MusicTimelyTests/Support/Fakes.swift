import Foundation

@testable import MusicTimely

/// 조작 가능한 시계. 단조·벽시계·boot를 따로 움직인다.
final class FakeClock: ClockPort, @unchecked Sendable {
    var reading = ClockReading(monoMs: 1_000_000, wallMs: 1_800_000_000_000, bootID: "boot-A")

    func now() -> ClockReading { reading }

    func advance(seconds: Double) {
        let ms = Int64(seconds * 1_000)
        reading.monoMs += ms
        reading.wallMs += ms
    }

    func reboot(after seconds: Double) {
        reading.wallMs += Int64(seconds * 1_000)
        reading.monoMs = 5_000
        reading.bootID = "boot-B"
    }
}

final class MemoryStore: StateStore, @unchecked Sendable {
    var checkpoint: SessionCheckpoint?
    var corrupt = false
    var settings = AppSettings()
    var thoughts: [ThoughtNote] = []
    var failWrites = false
    var checkpointWrites = 0

    struct WriteError: Error {}

    func loadCheckpoint() -> LoadResult<SessionCheckpoint> {
        if corrupt { return .corrupt }
        return checkpoint.map { .loaded($0) } ?? .empty
    }

    func saveCheckpoint(_ checkpoint: SessionCheckpoint) throws {
        if failWrites { throw WriteError() }
        checkpointWrites += 1
        self.checkpoint = checkpoint
    }

    func deleteCheckpoint() { checkpoint = nil }
    func loadSettings() -> AppSettings { settings }
    func saveSettings(_ settings: AppSettings) throws { self.settings = settings }
    func loadThoughts() -> [ThoughtNote] { thoughts }

    func saveThoughts(_ thoughts: [ThoughtNote]) throws {
        if failWrites { throw WriteError() }
        self.thoughts = thoughts
    }

    func deleteAll() {
        checkpoint = nil
        settings = AppSettings()
        thoughts = []
    }
}

final class FakeNotifications: NotificationScheduling {
    var scheduled: [String: Int64] = [:]
    var reconcileCalls = 0

    func requestAuthorizationIfNeeded() async -> Bool { false }
    func authorizationDenied() async -> Bool { true }

    /// 실제 알림 센터처럼 중간에 중단점이 있다. 직렬화되지 않으면 순서가 뒤집힌다.
    func reconcile(targetKey: String?, fireInMs: Int64?) async {
        reconcileCalls += 1
        let snapshot = scheduled
        try? await Task.sleep(for: .milliseconds(5))
        var next = snapshot
        next.removeAll()
        if let targetKey, let fireInMs { next[targetKey] = fireInMs }
        scheduled = next
    }

    func cancelAll() async { scheduled = [:] }
}

final class FakeLauncher: ExternalLaunching {
    var result = true
    var opened: [URL] = []

    func open(_ url: URL) async -> Bool {
        opened.append(url)
        return result
    }
}

final class RecordingSink: SessionResultSink {
    var results: [SessionResult] = []
    var succeeds = true

    func deliver(_ result: SessionResult) async -> Bool {
        results.append(result)
        return succeeds
    }
}

extension ClockReading {
    static func at(mono: Int64, wall: Int64 = 1_800_000_000_000, boot: String = "boot-A") -> ClockReading {
        ClockReading(monoMs: mono, wallMs: wall, bootID: boot)
    }
}
