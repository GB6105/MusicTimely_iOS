import Foundation
import OSLog
import Observation
import UIKit

/// 화면이 읽는 진행 파생값 (명세서 §6.1). 1Hz로 다시 계산한다.
struct SessionDisplay: Equatable {
    var elapsedMs: Int64
    var remainingMs: Int64?
    var targetMs: Int64?
    var initialMs: Int64?
    var plannedUnits: Int?
    var totalUnits: Int?
    var remainingUnits: Int?
    var elapsedUnits: Double
    var segmentIndex: Int
    var chips: [SongMath.Chip]?
    var isLastUnit: Bool
    var mode: DisplayMode
    var unitNoun: String { mode == .singleLoop ? String(localized: "바퀴") : String(localized: "곡") }
}

enum Route: Equatable {
    case assign
    case session
    case result
    case recovery
}

struct Toast: Equatable, Identifiable {
    let id = UUID()
    var message: String
}

@Observable
final class SessionStore {
    // MARK: 의존성
    @ObservationIgnored let clock: ClockPort
    @ObservationIgnored let store: StateStore
    @ObservationIgnored let notifications: NotificationScheduling
    @ObservationIgnored let launcher: ExternalLaunching
    @ObservationIgnored let resultSink: SessionResultSink
    let noise: NoisePlayer

    // MARK: 상태
    private(set) var settings: AppSettings
    private(set) var checkpoint: SessionCheckpoint?
    private(set) var now: ClockReading
    private(set) var corruptCheckpoint = false
    private(set) var thoughts: [ThoughtNote]
    private(set) var notificationsDenied = false
    var toast: Toast?
    /// 링크 실패 안내 (LINK_UNAVAILABLE). 같은 세션·소스에 한 번.
    var linkFailure: String?
    var sourceNotice: MusicProvider?

    // MARK: 배정 입력
    var draftTitle = ""
    var selectedMinutes: Int?
    var customMinutesText = ""
    var isInfinite = false

    @ObservationIgnored private var ticker: Task<Void, Never>?
    /// 알림 재조정을 직렬화하는 체인 (§7.2). 앞선 재조정이 끝난 뒤 최신 상태로 계산한다.
    @ObservationIgnored private var notificationChain: Task<Void, Never>?
    /// 같은 자리에서 바뀌는 pause/resume 버튼의 연속 탭을 막는다.
    @ObservationIgnored private var lastToggleMonoMs: Int64?
    @ObservationIgnored private var lastConfirmMonoMs: Int64 = 0
    @ObservationIgnored private var settingsWriteWarned = false
    static let toggleDebounceMs: Int64 = 400
    static let confirmIntervalMs: Int64 = 60_000
    @ObservationIgnored private var checkpointWriteWarned = false
    @ObservationIgnored private var linkFailureShown: Set<String> = []
    @ObservationIgnored private let log = Logger(subsystem: "com.gb6105.MusicTimely", category: "session")

    init(
        clock: ClockPort = SystemClock(),
        store: StateStore = FileStateStore(),
        notifications: NotificationScheduling = UserNotificationScheduler(),
        launcher: ExternalLaunching = UIApplicationLauncher(),
        resultSink: SessionResultSink = StandaloneResultSink(),
        noise: NoisePlayer = NoisePlayer()
    ) {
        self.clock = clock
        self.store = store
        self.notifications = notifications
        self.launcher = launcher
        self.resultSink = resultSink
        self.noise = noise
        let now = clock.now()
        self.now = now
        settings = store.loadSettings()
        thoughts = Self.purgeExpired(store.loadThoughts(), now: now)
        selectedMinutes = settings.lastMinutes
        restoreFromDisk()
    }

    // MARK: - 라우팅

    var route: Route {
        if corruptCheckpoint { return .recovery }
        guard let checkpoint else { return .assign }
        switch checkpoint.state {
        case .ready: return .assign
        case .running, .paused, .limitReached: return .session
        case .ended: return .result
        case .recoveryRequired: return .recovery
        }
    }

    // MARK: - 배정

    /// 선택된 분. 직접 입력이 잘못됐으면 nil이고 시작할 수 없다 (FR-002).
    var draftMinutes: Int? {
        if let selectedMinutes { return selectedMinutes }
        return Allocation.validateMinutes(customMinutesText)
    }

    var canStart: Bool { isInfinite || draftMinutes != nil }

    var draftPlannedUnits: Int? {
        guard let minutes = draftMinutes else { return nil }
        return SongMath.plannedUnits(targetMs: Int64(minutes) * 60_000, unitMs: Int64(unitSeconds) * 1_000)
    }

    var unitSeconds: Int {
        settings.repeatSingleSong ? (settings.loopSeconds ?? settings.averageSongSeconds) : settings.averageSongSeconds
    }

    /// 1탭·멱등 시작 (FR-007, FR-013). 이미 진행 중인 세션이 있으면 아무것도 하지 않는다.
    func start() {
        guard route == .assign, canStart else { return }
        let now = clock.now()
        self.now = now
        let loop = settings.repeatSingleSong ? settings.loopSeconds : nil
        let allocation: Allocation
        if isInfinite {
            allocation = .infinite(unitSeconds: settings.averageSongSeconds, loopSeconds: loop)
        } else {
            guard let minutes = draftMinutes else { return }
            allocation = .bounded(minutes: minutes, unitSeconds: settings.averageSongSeconds, loopSeconds: loop)
            updateSettings { $0.lastMinutes = minutes }
        }
        let title = String(draftTitle.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        let source = settings.source
        let cp = TimerMachine.start(
            title: title.isEmpty ? nil : title,
            allocation: allocation,
            sourceType: source.type,
            sourceProviderID: source.type == .builtinNoise ? source.noiseColor?.rawValue : source.providerID,
            displayMode: settings.displayMode(for: source.type),
            now: now
        )
        commit(cp, effects: [.rescheduleNotifications])
        linkFailureShown.removeAll()
        promptNotificationsOnce()
    }

    // MARK: - 세션 명령

    func send(_ command: SessionCommand, commandID: UUID? = nil) {
        guard let checkpoint else { return }
        let now = clock.now()
        self.now = now
        if command == .pause || command == .resume {
            if let last = lastToggleMonoMs, now.monoMs - last < Self.toggleDebounceMs { return }
        }
        guard let transition = TimerMachine.apply(command, to: checkpoint, now: now, commandID: commandID) else {
            return
        }
        if command == .pause || command == .resume { lastToggleMonoMs = now.monoMs }
        commit(transition.checkpoint, effects: transition.effects)
    }

    /// 곡 표시만 k번째로 맞춘다. 시간·목표·알림은 그대로 (FR-016, §6.2).
    func correctSegment(to index: Int) {
        guard var cp = checkpoint, cp.state.isActive, (1...999).contains(index) else { return }
        let now = clock.now()
        self.now = now
        cp.correction = .init(anchorIndex: index, anchorActiveMs: TimerMachine.elapsedMs(cp, now: now))
        cp.updatedAtEpochMs = now.wallMs
        commit(cp, effects: [])
        showToast(String(localized: "곡 표시만 맞췄어요. 정한 시간은 그대로예요."))
    }

    // MARK: - 결과

    func setPerceivedMinutes(_ minutes: Int?) {
        guard var cp = checkpoint, cp.state == .ended else { return }
        if let minutes, !(0...1_440).contains(minutes) { return }
        cp.perceivedMinutes = minutes
        commit(cp, effects: [])
    }

    func correctResultUnits(_ units: Int) {
        guard var cp = checkpoint, cp.state == .ended, (0...999).contains(units) else { return }
        cp.resultCorrectedUnits = units
        commit(cp, effects: [])
        showToast(String(localized: "곡 분량 표시만 고쳤어요. 세션 시간은 그대로예요."))
    }

    /// 결과를 닫는다. 곡 정보와 결과는 폐기하고 새 배정으로 간다 (§9.3).
    func closeResult(keepTitle: Bool) {
        let title = keepTitle ? (checkpoint?.taskTitle ?? "") : ""
        checkpoint = nil
        store.deleteCheckpoint()
        draftTitle = title
        isInfinite = false
        selectedMinutes = settings.lastMinutes
        customMinutesText = ""
    }

    // MARK: - 복구

    func resumeFromRecovery() { send(.resumeFromRecovery) }
    func finishFromRecovery() { send(.finishFromRecovery) }

    /// 손상된 저장본은 읽지 않고 폐기한다 (CORRUPT_CHECKPOINT).
    func discardCorruptCheckpoint() {
        store.deleteCheckpoint()
        corruptCheckpoint = false
        checkpoint = nil
    }

    // MARK: - 표시값

    func display(at now: ClockReading? = nil) -> SessionDisplay? {
        guard let cp = checkpoint else { return nil }
        let now = now ?? self.now
        let elapsed = TimerMachine.elapsedMs(cp, now: now)
        let unit = cp.allocation.unitMs
        let target = cp.allocation.currentTargetMs
        let remaining = TimerMachine.remainingMs(cp, now: now)
        return SessionDisplay(
            elapsedMs: elapsed,
            remainingMs: remaining,
            targetMs: target,
            initialMs: cp.allocation.initialDurationMs,
            plannedUnits: cp.allocation.initialDurationMs.map { SongMath.plannedUnits(targetMs: $0, unitMs: unit) },
            totalUnits: target.map { SongMath.plannedUnits(targetMs: $0, unitMs: unit) },
            remainingUnits: target.map { SongMath.remainingUnits(targetMs: $0, elapsedMs: elapsed, unitMs: unit) },
            elapsedUnits: SongMath.elapsedUnits(elapsedMs: elapsed, unitMs: unit),
            segmentIndex: SongMath.segmentIndex(
                elapsedMs: elapsed, unitMs: unit, correction: cp.correction, targetMs: target),
            chips: target.flatMap { SongMath.chips(targetMs: $0, elapsedMs: elapsed, unitMs: unit) },
            isLastUnit: TimerMachine.isInLastUnit(cp, now: now),
            mode: cp.displayMode
        )
    }

    // MARK: - 음악

    func selectExternal(_ provider: MusicProvider?) {
        if settings.source.type == .builtinNoise { noise.stop(fadeOut: settings.fadeOutSeconds) }
        updateSettings { $0.source = SourceSelection(type: .externalD0, providerID: provider?.id, noiseColor: nil) }
        applySourceToActiveSession()
    }

    func selectNoise(_ color: NoiseColor) {
        updateSettings { $0.source = SourceSelection(type: .builtinNoise, providerID: nil, noiseColor: color) }
        noise.setColor(color)
        applySourceToActiveSession()
    }

    func selectNoMusic() {
        if settings.source.type == .builtinNoise { noise.stop(fadeOut: settings.fadeOutSeconds) }
        updateSettings { $0.source = SourceSelection(type: .none, providerID: nil, noiseColor: nil) }
        applySourceToActiveSession()
    }

    func setCustomLink(_ text: String) -> Bool {
        guard let url = LinkValidation.validatedUserLink(text) else { return false }
        updateSettings {
            $0.customLinkURL = url.absoluteString
            $0.source = SourceSelection(type: .externalD0, providerID: MusicProvider.customLinkID, noiseColor: nil)
        }
        applySourceToActiveSession()
        return true
    }

    /// 사용자 탭으로만 외부 앱을 연다. 실패해도 타이머는 영향이 없다 (FR-023, FR-024).
    func openSelectedMusic() async {
        let source = settings.source
        guard source.type == .externalD0 else { return }
        let url: URL?
        if source.providerID == MusicProvider.customLinkID {
            url = settings.customLinkURL.flatMap(LinkValidation.validatedUserLink)
        } else {
            url = MusicProvider.named(source.providerID)?.url
        }
        if let provider = MusicProvider.named(source.providerID), provider.mayStopInBackground,
            !settings.noticeShownProviders.contains(provider.id)
        {
            sourceNotice = provider
            updateSettings { $0.noticeShownProviders.append(provider.id) }
        }
        let opened: Bool
        if let url { opened = await launcher.open(url) } else { opened = false }
        let key = "\(checkpoint?.sessionID.uuidString ?? "-"):\(source.providerID ?? "-")"
        if !opened, !linkFailureShown.contains(key) {
            linkFailureShown.insert(key)
            linkFailure = String(localized: "음악 앱을 직접 열어주세요")
        }
    }

    /// 노이즈는 명시적 탭으로만 재생한다 (FR-028).
    func toggleNoise() {
        if noise.state == .playing {
            noise.stop(fadeOut: settings.fadeOutSeconds)
        } else {
            let color = settings.source.noiseColor ?? .pink
            noise.play(color: color, volume: settings.noiseVolume, fadeIn: settings.fadeInSeconds)
            if checkpoint?.state == .paused { noise.duck() }
        }
    }

    private func applySourceToActiveSession() {
        guard var cp = checkpoint, cp.state.isActive else { return }
        let source = settings.source
        cp.sourceType = source.type
        cp.sourceProviderID = source.type == .builtinNoise ? source.noiseColor?.rawValue : source.providerID
        // 표시 방식은 다음 세션부터 바뀐다 (§6.4). 진행 중에는 소스만 바꾼다.
        commit(cp, effects: [])
    }

    // MARK: - 생각 메모 (FR-037)

    var activeThoughts: [ThoughtNote] {
        guard let id = checkpoint?.sessionID else { return [] }
        return thoughts.filter { $0.sessionID == id }
    }

    enum ThoughtSaveResult {
        case saved
        case empty
        case limitReached
        case failed
    }

    func addThought(_ text: String) -> ThoughtSaveResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard let id = checkpoint?.sessionID else { return .failed }
        guard activeThoughts.count < ThoughtNote.maxPerSession else { return .limitReached }
        let note = ThoughtNote(
            sessionID: id, text: String(trimmed.prefix(ThoughtNote.maxLength)), createdAtEpochMs: clock.now().wallMs)
        var next = thoughts
        next.append(note)
        do {
            try store.saveThoughts(next)
            thoughts = next
            return .saved
        } catch {
            return .failed
        }
    }

    func keepThought(_ id: UUID) {
        mutateThoughts { notes in
            for index in notes.indices where notes[index].id == id { notes[index].kept = true }
        }
    }
    func deleteThought(_ id: UUID) { mutateThoughts { $0.removeAll { $0.id == id } } }
    var keptThoughts: [ThoughtNote] { thoughts.filter(\.kept) }

    private func mutateThoughts(_ change: (inout [ThoughtNote]) -> Void) {
        var next = thoughts
        change(&next)
        do {
            try store.saveThoughts(next)
            thoughts = next
        } catch {
            showToast(String(localized: "메모를 저장하지 못했어요. 다시 시도해 주세요."))
        }
    }

    private static func purgeExpired(_ notes: [ThoughtNote], now: ClockReading) -> [ThoughtNote] {
        notes.filter { $0.kept || now.wallMs - $0.createdAtEpochMs <= ThoughtNote.unkeptRetentionMs }
    }

    // MARK: - 설정 (FR-038, FR-039)

    func updateSettings(_ change: (inout AppSettings) -> Void) {
        var next = settings
        change(&next)
        next = next.sanitized()
        guard next != settings else { return }
        settings = next
        saveSettings(next)
        if noise.state == .playing { noise.setVolume(next.noiseVolume) }
    }

    func resetSettings() {
        let keepNotice = settings.noticeShownProviders
        settings = AppSettings()
        settings.noticeShownProviders = keepNotice
        saveSettings(settings)
    }

    private func saveSettings(_ settings: AppSettings) {
        do {
            try store.saveSettings(settings)
        } catch {
            if !settingsWriteWarned {
                settingsWriteWarned = true
                showToast(String(localized: "설정을 저장하지 못했어요. 앱을 다시 열면 이전 값으로 돌아갈 수 있어요."))
            }
        }
    }

    /// 설정·활성 상태·메모를 지우고 소리와 알림을 멈춘다. 외부 음악·파일 원본은 건드리지 않는다.
    func deleteAllData() {
        noise.stop(fadeOut: 0)
        enqueueNotificationWork { notifications in await notifications.cancelAll() }
        store.deleteAll()
        settings = AppSettings()
        thoughts = []
        checkpoint = nil
        corruptCheckpoint = false
        draftTitle = ""
        selectedMinutes = settings.lastMinutes
        customMinutesText = ""
        isInfinite = false
        showToast(String(localized: "모든 데이터를 지웠어요."))
    }

    // MARK: - 앱 수명주기

    func sceneBecameActive() {
        tick()
        reconcileNotifications()
        redeliverPendingResult()
        Task { notificationsDenied = await notifications.authorizationDenied() }
        startTicker()
    }

    /// 백그라운드에서는 UI tick을 멈춘다. 단, 앱 소리가 나는 중이면 목표 도달 fade-out을 위해 유지한다 (§5.1).
    func sceneMovedToBackground() {
        confirmProgress(force: true)
        if noise.state != .playing {
            ticker?.cancel()
            ticker = nil
        }
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    /// 현재 활성 경과를 확정 지점으로 저장한다. 재부팅 복구 때 이 지점까지만 인정한다.
    private func confirmProgress(force: Bool) {
        guard var cp = checkpoint, cp.state == .running else {
            if let checkpoint { persist(checkpoint) }
            return
        }
        let now = clock.now()
        guard force || now.monoMs - lastConfirmMonoMs >= Self.confirmIntervalMs else { return }
        lastConfirmMonoMs = now.monoMs
        cp.confirmedActiveMs = TimerMachine.elapsedMs(cp, now: now)
        cp.updatedAtEpochMs = now.wallMs
        checkpoint = cp
        persist(cp)
    }

    /// 1Hz 파생값 갱신. 목표 도달과 마지막 분량 예고를 처리한다.
    func tick() {
        let now = clock.now()
        self.now = now
        guard var cp = checkpoint, cp.state == .running else { return }
        if TimerMachine.hasReachedLimit(cp, now: now) {
            send(.reachLimit)
            return
        }
        if TimerMachine.shouldCueLastUnit(cp, now: now) {
            cp.lastCueKey = TimerMachine.cueKey(cp)
            commit(cp, effects: [])
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            let message: String =
                switch cp.displayMode {
                case .timeOnly: String(localized: "정한 시간이 곧 끝나요")
                case .singleLoop: String(localized: "대략 한 바퀴 분량 남았어요")
                case .playlist: String(localized: "대략 한 곡 분량 남았어요")
                }
            UIAccessibility.post(notification: .announcement, argument: message)
            return
        }
        confirmProgress(force: false)
    }

    // MARK: - 내부

    private func restoreFromDisk() {
        switch store.loadCheckpoint() {
        case .empty:
            checkpoint = nil
        case .corrupt:
            corruptCheckpoint = true
        case .loaded(let cp):
            switch TimerMachine.restore(cp, now: now) {
            case .discard:
                store.deleteCheckpoint()
            case .restored(let restored), .recoveryRequired(let restored):
                checkpoint = restored
                if restored != cp { persist(restored) }
                redeliverPendingResult()
            }
        }
    }

    private func commit(_ cp: SessionCheckpoint, effects: [SessionEffect]) {
        checkpoint = cp
        persist(cp)
        for effect in effects { perform(effect, for: cp) }
    }

    private func persist(_ cp: SessionCheckpoint) {
        do {
            try store.saveCheckpoint(cp)
        } catch {
            log.error("checkpoint write failed")
            if !checkpointWriteWarned {
                checkpointWriteWarned = true
                showToast(String(localized: "이번 세션은 앱 종료 후 복원되지 않을 수 있어요"))
            }
        }
    }

    private func perform(_ effect: SessionEffect, for cp: SessionCheckpoint) {
        switch effect {
        case .rescheduleNotifications:
            reconcileNotifications()
        case .duckOwnAudio:
            noise.duck()
        case .restoreOwnAudioLevel:
            noise.restoreLevel()
        case .fadeOutOwnAudio:
            noise.stop(fadeOut: settings.fadeOutSeconds)
        case .deliverResult:
            deliver(cp)
        }
    }

    /// 전달하지 못한 결과를 같은 deliveryID로 다시 보낸다. 수신 측은 deliveryID로 중복을 거른다 (FR-040).
    private func redeliverPendingResult() {
        guard let cp = checkpoint, cp.state == .ended, !cp.resultFinalized else { return }
        deliver(cp)
    }

    private func deliver(_ cp: SessionCheckpoint) {
        let result = SessionResult(
            sessionID: cp.sessionID,
            deliveryID: cp.deliveryID,
            initialDurationMs: cp.allocation.initialDurationMs,
            activeDurationMs: cp.accumulatedActiveMs,
            endReason: cp.endReason ?? .userEnded,
            extensionUsed: cp.extensionUsed
        )
        Task {
            // 실패해도 로컬 결과 화면은 유지한다. 다음 실행·복귀 때 다시 보낸다.
            guard await resultSink.deliver(result), var latest = checkpoint, latest.sessionID == cp.sessionID else {
                return
            }
            latest.resultFinalized = true
            checkpoint = latest
            persist(latest)
        }
    }

    /// 알림 재조정 (§7.2). RUNNING이고 목표가 미래일 때만 하나를 예약한다.
    private func reconcileNotifications() {
        enqueueNotificationWork { [weak self] notifications in
            // 실행 시점의 최신 상태로 다시 계산한다. 앞선 작업과 순서가 뒤집히지 않는다.
            guard let self else { return }
            let now = self.clock.now()
            var key: String?
            var fireIn: Int64?
            if let cp = self.checkpoint, cp.state == .running, let remaining = TimerMachine.remainingMs(cp, now: now),
                remaining > 0
            {
                key = "\(TimerMachine.cueKey(cp)):target"
                fireIn = remaining
            }
            await notifications.reconcile(targetKey: key, fireInMs: fireIn)
        }
    }

    private func enqueueNotificationWork(_ work: @escaping (NotificationScheduling) async -> Void) {
        let previous = notificationChain
        let notifications = self.notifications
        notificationChain = Task {
            await previous?.value
            await work(notifications)
        }
    }

    /// 테스트용: 대기 중인 알림 재조정이 모두 끝날 때까지 기다린다.
    func waitForNotificationWork() async {
        await notificationChain?.value
    }

    private func promptNotificationsOnce() {
        guard !settings.notificationPromptShown else { return }
        updateSettings { $0.notificationPromptShown = true }
        Task {
            _ = await notifications.requestAuthorizationIfNeeded()
            notificationsDenied = await notifications.authorizationDenied()
            reconcileNotifications()
        }
    }

    func showToast(_ message: String) {
        toast = Toast(message: message)
    }
}
