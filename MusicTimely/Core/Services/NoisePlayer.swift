import AVFoundation
import Foundation
import Observation
import os

/// 절차 생성 노이즈 (FR-027). 오디오 스레드에서만 필터 상태를 만진다.
nonisolated final class NoiseGenerator: @unchecked Sendable {
    private let colorLock = OSAllocatedUnfairLock(initialState: NoiseColor.pink)
    private var b0: Float = 0, b1: Float = 0, b2: Float = 0, b3: Float = 0, b4: Float = 0, b5: Float = 0, b6: Float = 0
    private var seed: UInt32 = 0x1234_5678

    /// 출력 상한. 볼륨 1.0에서도 이 진폭을 넘지 않는다 (limiter).
    static let peak: Float = 0.5

    var color: NoiseColor {
        get { colorLock.withLock { $0 } }
        set { colorLock.withLock { $0 = newValue } }
    }

    private func nextWhite() -> Float {
        seed = seed &* 1_664_525 &+ 1_013_904_223
        return Float(Int32(bitPattern: seed)) / Float(Int32.max)
    }

    /// 한 샘플을 만든다. 핑크는 Paul Kellet 필터.
    func nextSample(color: NoiseColor) -> Float {
        let white = nextWhite()
        let raw: Float
        switch color {
        case .white:
            raw = white * 0.35
        case .pink:
            b0 = 0.99886 * b0 + white * 0.0555179
            b1 = 0.99332 * b1 + white * 0.0750759
            b2 = 0.96900 * b2 + white * 0.1538520
            b3 = 0.86650 * b3 + white * 0.3104856
            b4 = 0.55000 * b4 + white * 0.5329522
            b5 = -0.7616 * b5 - white * 0.0168980
            raw = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + white * 0.5362) * 0.11
            b6 = white * 0.115926
        }
        return max(-Self.peak, min(Self.peak, raw))
    }

    func render(frames: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        let color = self.color
        for frame in 0..<frames {
            let sample = nextSample(color: color)
            for buffer in buffers {
                buffer.mData?.assumingMemoryBound(to: Float.self)[frame] = sample
            }
        }
    }
}

/// 앱이 소유한 노이즈 재생기 (명세서 §9.4 OwnedAudioPlayer). 외부 앱 오디오는 건드리지 않는다.
@Observable
final class NoisePlayer {
    enum State: Equatable {
        case stopped
        case playing
        /// 페이드아웃 중. 덕킹·볼륨 변경이 페이드를 취소하지 않는다.
        case stopping
        case interrupted
        case unavailable
    }

    private(set) var state: State = .stopped
    private(set) var color: NoiseColor = .pink

    @ObservationIgnored private let generator = NoiseGenerator()
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var fadeTask: Task<Void, Never>?
    @ObservationIgnored private var targetVolume: Float = 0.2
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    static let duckFraction: Float = 0.3

    init() {
        let center = NotificationCenter.default
        // 인터럽트·헤드폰 분리·엔진 구성 변경 시 소리만 멈춘다. 자동 재개하지 않는다 (FR-030).
        observers.append(
            center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) {
                [weak self] note in
                let began =
                    (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                    .flatMap(AVAudioSession.InterruptionType.init(rawValue:)) == .began
                guard began else { return }
                MainActor.assumeIsolated { self?.interrupt() }
            })
        observers.append(
            center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) {
                [weak self] note in
                let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt)
                    .flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
                guard reason == .oldDeviceUnavailable else { return }
                MainActor.assumeIsolated { self?.interrupt() }
            })
        observers.append(
            center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.interrupt() }
            })
    }

    isolated deinit {
        for observer in observers { NotificationCenter.default.removeObserver(observer) }
    }

    private func interrupt() {
        guard state == .playing || state == .stopping else { return }
        halt(as: .interrupted)
    }

    /// 사용자가 명시적으로 탭했을 때만 호출한다 (FR-028).
    func play(color: NoiseColor, volume: Double, fadeIn: Double) {
        self.color = color
        generator.color = color
        targetVolume = Float(min(1, max(0, volume)))
        do {
            let session = AVAudioSession.sharedInstance()
            // 다른 앱 소리를 멈추지 않는다 (FR-031).
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            let engine = self.engine ?? makeEngine()
            self.engine = engine
            engine.mainMixerNode.outputVolume = 0
            if !engine.isRunning { try engine.start() }
            state = .playing
            ramp(to: targetVolume, over: fadeIn)
        } catch {
            state = .unavailable
        }
    }

    func setColor(_ color: NoiseColor) {
        self.color = color
        generator.color = color
    }

    func setVolume(_ volume: Double) {
        targetVolume = Float(min(1, max(0, volume)))
        if state == .playing { ramp(to: targetVolume, over: 0.2) }
    }

    /// 세션 일시정지 시 설정 볼륨의 30%로 낮춘다 (FR-029).
    func duck() {
        guard state == .playing else { return }
        ramp(to: targetVolume * Self.duckFraction, over: 0.5)
    }

    func restoreLevel() {
        guard state == .playing else { return }
        ramp(to: targetVolume, over: 0.5)
    }

    func stop(fadeOut: Double) {
        guard state == .playing else {
            if state == .interrupted || state == .unavailable { state = .stopped }
            return
        }
        state = .stopping
        ramp(to: 0, over: fadeOut) { [weak self] in self?.halt(as: .stopped) }
    }

    private func halt(as newState: State) {
        fadeTask?.cancel()
        engine?.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = newState
    }

    private func makeEngine() -> AVAudioEngine {
        let engine = AVAudioEngine()
        let format = engine.outputNode.inputFormat(forBus: 0)
        let mono = AVAudioFormat(standardFormatWithSampleRate: format.sampleRate, channels: 1)
        let source = Self.makeSourceNode(generator: generator)
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: mono)
        return engine
    }

    /// 렌더 블록은 오디오 스레드에서 돈다. MainActor 격리를 물려받지 않도록 nonisolated 문맥에서 만든다.
    nonisolated private static func makeSourceNode(generator: NoiseGenerator) -> AVAudioSourceNode {
        AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            generator.render(frames: Int(frameCount), into: UnsafeMutableAudioBufferListPointer(audioBufferList))
            return noErr
        }
    }

    private func ramp(to target: Float, over seconds: Double, completion: (() -> Void)? = nil) {
        fadeTask?.cancel()
        guard let mixer = engine?.mainMixerNode else {
            completion?()
            return
        }
        let start = mixer.outputVolume
        let steps = max(1, Int(seconds * 30))
        fadeTask = Task { @MainActor in
            for step in 1...steps {
                if Task.isCancelled { return }
                mixer.outputVolume = start + (target - start) * Float(step) / Float(steps)
                if steps > 1 { try? await Task.sleep(for: .milliseconds(33)) }
            }
            completion?()
        }
    }
}
