import Foundation

/// 앱 테마 (피그마 Light / Navy / Dark).
nonisolated enum ThemeChoice: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case navy
    case dark
}

/// 선택한 음악 소스. 선택값만 복원하고 자동 재생하지 않는다 (DEC-05).
nonisolated struct SourceSelection: Codable, Equatable, Sendable {
    var type: SourceType
    var providerID: String?
    var noiseColor: NoiseColor?

    static let `default` = SourceSelection(type: .externalD0, providerID: nil, noiseColor: nil)
}

nonisolated enum NoiseColor: String, Codable, Sendable, CaseIterable {
    case white
    case pink
}

/// 버전 있는 설정 (FR-038).
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let unitSecondsRange = 60...1_800
    static let fadeInRange = 0.0...5.0
    static let fadeOutRange = 0.0...10.0

    var version = AppSettings.currentVersion
    var averageSongSeconds = 240
    var showSongs = true
    var repeatSingleSong = false
    var loopSeconds: Int?
    var motionEnabled = true
    var noiseVolume = 0.2
    var fadeInSeconds = 1.5
    var fadeOutSeconds = 3.0
    var theme = ThemeChoice.system
    var lastMinutes = Allocation.defaultMinutes
    var source = SourceSelection.default
    var customLinkURL: String?
    var noticeShownProviders: [String] = []
    var notificationPromptShown = false
    /// 잠금화면 Live Activity에 곡·시간 세부를 숨긴다 (피그마 Private).
    var lockScreenPrivate = false

    init() {}

    /// 새 필드가 없는 이전 버전 설정도 읽을 수 있게 한다.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? d.version
        averageSongSeconds = try c.decodeIfPresent(Int.self, forKey: .averageSongSeconds) ?? d.averageSongSeconds
        showSongs = try c.decodeIfPresent(Bool.self, forKey: .showSongs) ?? d.showSongs
        repeatSingleSong = try c.decodeIfPresent(Bool.self, forKey: .repeatSingleSong) ?? d.repeatSingleSong
        loopSeconds = try c.decodeIfPresent(Int.self, forKey: .loopSeconds)
        motionEnabled = try c.decodeIfPresent(Bool.self, forKey: .motionEnabled) ?? d.motionEnabled
        noiseVolume = try c.decodeIfPresent(Double.self, forKey: .noiseVolume) ?? d.noiseVolume
        fadeInSeconds = try c.decodeIfPresent(Double.self, forKey: .fadeInSeconds) ?? d.fadeInSeconds
        fadeOutSeconds = try c.decodeIfPresent(Double.self, forKey: .fadeOutSeconds) ?? d.fadeOutSeconds
        theme = try c.decodeIfPresent(ThemeChoice.self, forKey: .theme) ?? d.theme
        lastMinutes = try c.decodeIfPresent(Int.self, forKey: .lastMinutes) ?? d.lastMinutes
        source = try c.decodeIfPresent(SourceSelection.self, forKey: .source) ?? d.source
        customLinkURL = try c.decodeIfPresent(String.self, forKey: .customLinkURL)
        noticeShownProviders = try c.decodeIfPresent([String].self, forKey: .noticeShownProviders) ?? []
        notificationPromptShown = try c.decodeIfPresent(Bool.self, forKey: .notificationPromptShown) ?? false
        lockScreenPrivate = try c.decodeIfPresent(Bool.self, forKey: .lockScreenPrivate) ?? false
    }

    /// 새 세션에 적용할 표시 방식. 음악 없음은 시간만 표시가 기본이다 (§6.1).
    func displayMode(for source: SourceType) -> DisplayMode {
        // 음악 없음은 시간 환산, 노이즈는 곡이 아니므로 시간 표시 (§6.1 소스별 예외).
        if !showSongs || source == .none || source == .builtinNoise { return .timeOnly }
        return repeatSingleSong ? .singleLoop : .playlist
    }

    /// 범위를 벗어난 값을 기본 범위로 되돌린다.
    func sanitized() -> AppSettings {
        var s = self
        if !Self.unitSecondsRange.contains(s.averageSongSeconds) { s.averageSongSeconds = 240 }
        if let loop = s.loopSeconds, !Self.unitSecondsRange.contains(loop) { s.loopSeconds = nil }
        s.noiseVolume = min(1, max(0, s.noiseVolume))
        s.fadeInSeconds = min(Self.fadeInRange.upperBound, max(0, s.fadeInSeconds))
        s.fadeOutSeconds = min(Self.fadeOutRange.upperBound, max(0, s.fadeOutSeconds))
        if !(Allocation.minMinutes...Allocation.maxMinutes).contains(s.lastMinutes) {
            s.lastMinutes = Allocation.defaultMinutes
        }
        return s
    }

    /// "3:42" 형식의 반복 길이를 초로 바꾼다. 빈 값은 nil(평균 사용), 잘못된 값은 오류 (§6.4).
    static func parseLoopLength(_ text: String) -> Result<Int?, LoopLengthError> {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return .success(nil) }
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isASCIIDigit) }),
            let minutes = Int(parts[0]), let seconds = Int(parts[1]), seconds < 60
        else { return .failure(.format) }
        let total = minutes * 60 + seconds
        return unitSecondsRange.contains(total) ? .success(total) : .failure(.range)
    }

    enum LoopLengthError: Error, Equatable {
        case format
        case range
    }
}

/// 생각 메모 (FR-037).
nonisolated struct ThoughtNote: Codable, Equatable, Sendable, Identifiable {
    static let maxLength = 500
    static let maxPerSession = 20
    static let unkeptRetentionMs: Int64 = 24 * 60 * 60 * 1_000

    var id = UUID()
    var sessionID: UUID
    var text: String
    var createdAtEpochMs: Int64
    var kept = false
}
