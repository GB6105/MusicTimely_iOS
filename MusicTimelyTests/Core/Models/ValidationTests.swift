import Foundation
import Testing

@testable import MusicTimely

struct ValidationTests {
    @Test("QA-03: 0·음수·소수·241·문자는 시작할 수 없다", arguments: ["0", "-5", "2.5", "241", "abc", "", " ", "1e2"])
    func invalidMinutes(_ text: String) {
        #expect(Allocation.validateMinutes(text) == nil)
    }

    @Test("유효한 분", arguments: [("1", 1), ("25", 25), ("240", 240), (" 40 ", 40)])
    func validMinutes(_ input: (String, Int)) {
        #expect(Allocation.validateMinutes(input.0) == input.1)
    }

    @Test("QA-41: 반복 길이 03:42 → 222초, 공백은 평균, 범위 밖은 오류")
    func loopLength() {
        #expect(AppSettings.parseLoopLength("03:42") == .success(222))
        #expect(AppSettings.parseLoopLength("") == .success(nil))
        #expect(AppSettings.parseLoopLength("0:30") == .failure(.range))
        #expect(AppSettings.parseLoopLength("31:00") == .failure(.range))
        #expect(AppSettings.parseLoopLength("3:75") == .failure(.format))
        #expect(AppSettings.parseLoopLength("abc") == .failure(.format))
    }

    @Test(
        "QA-20: 악성 scheme과 자격 증명 링크는 거부",
        arguments: [
            "javascript:alert(1)", "file:///etc/passwd", "http://example.com", "intent://x#Intent;end",
            "https://user:pw@example.com", "https://", "spotify:playlist:1",
        ])
    func rejectsUnsafeLinks(_ text: String) {
        #expect(LinkValidation.validatedUserLink(text) == nil)
    }

    @Test("https 링크는 허용")
    func acceptsHTTPS() {
        #expect(
            LinkValidation.validatedUserLink("https://music.youtube.com/playlist?list=abc")?.host == "music.youtube.com"
        )
    }

    @Test("외부 제공자는 열기용 URL만 갖는다")
    func providers() {
        #expect(MusicProvider.all.map(\.id) == ["apple_music", "spotify", "youtube_music"])
    }

    @Test("설정 범위 보정")
    func sanitizeSettings() {
        var s = AppSettings()
        s.averageSongSeconds = 5
        s.noiseVolume = 3
        s.fadeOutSeconds = 99
        let clean = s.sanitized()
        #expect(clean.averageSongSeconds == 240)
        #expect(clean.noiseVolume == 1)
        #expect(clean.fadeOutSeconds == 10)
    }

    @Test("음악 없음은 시간만 표시가 기본")
    func displayModeForNoMusic() {
        #expect(AppSettings().displayMode(for: .none) == .timeOnly)
        #expect(AppSettings().displayMode(for: .externalD0) == .playlist)
        #expect(AppSettings().displayMode(for: .builtinNoise) == .timeOnly)
    }
}

struct NoiseGeneratorTests {
    @Test("NFR-007: 노이즈 샘플은 limiter 상한을 넘지 않는다", arguments: NoiseColor.allCases)
    func samplesStayWithinPeak(_ color: NoiseColor) {
        let generator = NoiseGenerator()
        var peak: Float = 0
        for _ in 0..<48_000 { peak = max(peak, abs(generator.nextSample(color: color))) }
        #expect(peak <= NoiseGenerator.peak)
        #expect(peak > 0.05)
    }
}
