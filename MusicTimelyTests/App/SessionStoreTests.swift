import Foundation
import Testing

@testable import MusicTimely

struct SessionStoreTests {
    private let clock = FakeClock()
    private let disk = MemoryStore()
    private let notifications = FakeNotifications()
    private let launcher = FakeLauncher()
    private let sink = RecordingSink()

    private func makeStore() -> SessionStore {
        SessionStore(clock: clock, store: disk, notifications: notifications, launcher: launcher, resultSink: sink)
    }

    private func settle(_ store: SessionStore? = nil) async {
        for _ in 0..<5 { await Task.yield() }
        try? await Task.sleep(for: .milliseconds(30))
        await store?.waitForNotificationWork()
    }

    @Test("QA-01: 최초 실행은 25분 선택, 바로 시작 가능")
    func firstLaunchDefaults() {
        let store = makeStore()
        #expect(store.route == .assign)
        #expect(store.selectedMinutes == 25)
        #expect(store.draftPlannedUnits == 7)
        #expect(store.canStart)
    }

    @Test("QA-04: 시작을 10번 눌러도 세션·알림 예약은 1개")
    func startIsIdempotent() async {
        let store = makeStore()
        for _ in 0..<10 { store.start() }
        await settle(store)
        #expect(store.route == .session)
        #expect(disk.checkpointWrites == 1)
        #expect(notifications.scheduled.count == 1)
        #expect(notifications.scheduled.values.first == 1_500_000)
    }

    @Test("QA-03: 잘못된 직접 입력으로는 시작하지 않는다")
    func invalidCustomMinutesBlocksStart() {
        let store = makeStore()
        store.selectedMinutes = nil
        store.customMinutesText = "241"
        #expect(!store.canStart)
        store.start()
        #expect(store.route == .assign)
    }

    @Test("일시정지하면 목표 알림이 취소되고 재개하면 남은 시간으로 재예약")
    func notificationsFollowState() async {
        let store = makeStore()
        store.start()
        clock.advance(seconds: 60)
        store.send(.pause)
        await settle(store)
        #expect(notifications.scheduled.isEmpty)
        clock.advance(seconds: 30)
        store.send(.resume)
        await settle(store)
        #expect(notifications.scheduled.values.first == 1_440_000)
    }

    @Test("목표 도달은 tick에서 LIMIT_REACHED로 바뀐다")
    func tickReachesLimit() {
        let store = makeStore()
        store.selectedMinutes = 10
        store.start()
        clock.advance(seconds: 10 * 60 + 1)
        store.tick()
        #expect(store.checkpoint?.state == .limitReached)
    }

    @Test("마치면 결과 화면과 시간 중심 결과 1건 (FR-040)")
    func finishDeliversResult() async throws {
        let store = makeStore()
        store.draftTitle = "  기획안 첫 문단  "
        store.start()
        clock.advance(seconds: 300)
        store.send(.finish)
        await settle()
        #expect(store.route == .result)
        #expect(store.checkpoint?.taskTitle == "기획안 첫 문단")
        let result = try #require(sink.results.first)
        #expect(sink.results.count == 1)
        #expect(result.activeDurationMs == 300_000)
        #expect(result.endReason == .userEnded)
        #expect(store.checkpoint?.resultFinalized == true)
    }

    @Test("결과를 닫으면 결과와 곡 정보를 지우고, 이어서 하기는 제목만 남긴다")
    func closeResult() {
        let store = makeStore()
        store.draftTitle = "보고서"
        store.start()
        store.send(.finish)
        store.closeResult(keepTitle: true)
        #expect(store.route == .assign)
        #expect(disk.checkpoint == nil)
        #expect(store.draftTitle == "보고서")
    }

    @Test("QA-12: 손상된 저장본은 복구 화면으로 간다")
    func corruptCheckpoint() {
        disk.corrupt = true
        let store = makeStore()
        #expect(store.route == .recovery)
        store.discardCorruptCheckpoint()
        #expect(store.route == .assign)
    }

    @Test("저장 실패는 한 번 안내하고 메모리에서 계속 진행")
    func checkpointWriteFailure() {
        disk.failWrites = true
        let store = makeStore()
        store.start()
        #expect(store.route == .session)
        #expect(store.toast?.message == "이번 세션은 앱 종료 후 복원되지 않을 수 있어요")
        store.toast = nil
        store.send(.pause)
        #expect(store.toast == nil)
    }

    @Test("QA-28: 메모 저장 실패 시 실패를 알리고 입력은 호출자가 유지")
    func memoFailure() {
        let store = makeStore()
        store.start()
        #expect(store.addThought("참고 자료") == .saved)
        disk.failWrites = true
        #expect(store.addThought("두 번째") == .failed)
        #expect(store.activeThoughts.count == 1)
    }

    @Test("메모는 세션당 20개까지")
    func memoLimit() {
        let store = makeStore()
        store.start()
        for i in 0..<20 { _ = store.addThought("메모 \(i)") }
        #expect(store.addThought("초과") == .limitReached)
    }

    @Test("QA-15: 곡 표시 보정은 시간과 알림을 바꾸지 않는다")
    func correctionKeepsTime() async throws {
        let store = makeStore()
        store.start()
        clock.advance(seconds: 300)
        await settle()
        let before = notifications.reconcileCalls
        store.correctSegment(to: 5)
        await settle()
        let display = try #require(store.display())
        #expect(display.segmentIndex == 5)
        #expect(display.elapsedMs == 300_000)
        #expect(notifications.reconcileCalls == before)
    }

    @Test("QA-19: 링크 실패는 안내하고 타이머는 그대로")
    func linkFailure() async {
        launcher.result = false
        let store = makeStore()
        store.selectExternal(MusicProvider.named("apple_music"))
        store.start()
        await store.openSelectedMusic()
        #expect(store.linkFailure == "음악 앱을 직접 열어주세요")
        #expect(store.checkpoint?.state == .running)
        store.linkFailure = nil
        await store.openSelectedMusic()
        #expect(store.linkFailure == nil)
    }

    @Test("QA-21: 조건부 제한 고지는 제공자마다 처음 한 번")
    func sourceNoticeOnce() async {
        let store = makeStore()
        store.selectExternal(MusicProvider.named("youtube_music"))
        await store.openSelectedMusic()
        #expect(store.sourceNotice?.id == "youtube_music")
        store.sourceNotice = nil
        await store.openSelectedMusic()
        #expect(store.sourceNotice == nil)
    }

    @Test("QA-33: 전체 삭제는 설정·세션·메모·알림을 지운다")
    func deleteAll() async {
        let store = makeStore()
        store.updateSettings { $0.averageSongSeconds = 300 }
        store.start()
        _ = store.addThought("메모")
        store.deleteAllData()
        await settle(store)
        #expect(store.route == .assign)
        #expect(store.settings == AppSettings())
        #expect(disk.thoughts.isEmpty)
        #expect(notifications.scheduled.isEmpty)
    }

    @Test("FR-004: 평균 길이 변경은 진행 중 세션에 소급하지 않는다")
    func settingsSnapshot() {
        let store = makeStore()
        store.start()
        store.updateSettings { $0.averageSongSeconds = 180 }
        #expect(store.checkpoint?.allocation.durationPerUnitMs == 240_000)
    }

    @Test("음악 없음 선택 시 새 세션은 시간만 표시")
    func noMusicTimeOnly() {
        let store = makeStore()
        store.selectNoMusic()
        store.start()
        #expect(store.checkpoint?.displayMode == .timeOnly)
        #expect(store.checkpoint?.sourceType == SourceType.none)
    }

    @Test("H2: 빠른 pause·resume에도 알림 재조정 순서가 뒤집히지 않는다")
    func notificationReconcileIsSerialized() async {
        let store = makeStore()
        store.start()
        clock.advance(seconds: 60)
        store.send(.pause)
        clock.advance(seconds: 1)
        store.send(.resume)
        await settle(store)
        #expect(store.checkpoint?.state == .running)
        #expect(notifications.scheduled.count == 1)
        clock.advance(seconds: 1)
        store.send(.pause)
        await settle(store)
        #expect(notifications.scheduled.isEmpty)
    }

    @Test("M8: 같은 자리 버튼의 연속 탭(400ms 이내)은 무시한다")
    func toggleDebounce() {
        let store = makeStore()
        store.start()
        store.send(.pause)
        clock.advance(seconds: 0.1)
        store.send(.resume)
        #expect(store.checkpoint?.state == .paused)
        clock.advance(seconds: 0.5)
        store.send(.resume)
        #expect(store.checkpoint?.state == .running)
    }

    @Test("QA-05: 진행·정지·재개에서 외부 음악 앱 호출은 0회")
    func noExternalControl() {
        let store = makeStore()
        store.start()
        clock.advance(seconds: 60)
        store.send(.pause)
        clock.advance(seconds: 30)
        store.send(.resume)
        clock.advance(seconds: 60)
        store.send(.finish)
        #expect(launcher.opened.isEmpty)
        #expect(store.checkpoint?.accumulatedActiveMs == 120_000)
    }

    @Test("QA-10: 무한 모드는 목표 알림을 예약하지 않는다")
    func infiniteHasNoNotification() async {
        let store = makeStore()
        store.isInfinite = true
        store.start()
        await settle(store)
        #expect(store.route == .session)
        #expect(notifications.scheduled.isEmpty)
    }

    @Test("QA-12: 재부팅 뒤 복구 화면에서 이어가기와 마치기")
    func recoveryFlow() {
        let first = makeStore()
        first.start()
        clock.advance(seconds: 120)
        first.send(.pause)
        clock.advance(seconds: 1)
        first.send(.resume)
        clock.reboot(after: 300)

        let second = makeStore()
        #expect(second.route == .recovery)
        second.resumeFromRecovery()
        #expect(second.checkpoint?.state == .paused)
        #expect(second.checkpoint?.accumulatedActiveMs == 120_000)
        second.send(.finish)
        #expect(second.route == .result)
    }

    @Test("QA-16: 앱을 다시 열어도 같은 revision의 예고는 반복하지 않는다")
    func cueNotRepeatedAfterRelaunch() {
        let first = makeStore()
        first.start()
        clock.advance(seconds: 21 * 60 + 10)
        first.tick()
        #expect(first.checkpoint?.lastCueKey != nil)
        let second = makeStore()
        #expect(second.checkpoint.map { TimerMachine.shouldCueLastUnit($0, now: clock.now()) } == false)
    }

    @Test("QA-32·M7: 결과 전달이 실패하면 같은 deliveryID로 다시 보낸다")
    func resultRedelivery() async {
        sink.succeeds = false
        let store = makeStore()
        store.start()
        store.send(.finish)
        await settle()
        #expect(store.checkpoint?.resultFinalized == false)
        sink.succeeds = true
        store.sceneBecameActive()
        await settle()
        #expect(store.checkpoint?.resultFinalized == true)
        #expect(sink.results.count == 2)
        #expect(Set(sink.results.map(\.deliveryID)).count == 1)
    }

    @Test("§6.4: 진행 중 소스를 바꿔도 표시 방식은 다음 세션부터")
    func displayModeFixedDuringSession() {
        let store = makeStore()
        store.start()
        store.selectNoise(.pink)
        #expect(store.checkpoint?.displayMode == .playlist)
        #expect(store.checkpoint?.sourceType == .builtinNoise)
    }
}
