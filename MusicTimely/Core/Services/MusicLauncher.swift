import Foundation
import UIKit

/// 외부 음악 앱. 열기만 하고 재생·정지·큐·볼륨 제어는 두지 않는다 (FR-025).
nonisolated struct MusicProvider: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 열기용 앱 스킴. 재생 제어 명령은 담지 않는다.
    let urlString: String
    /// 요금제·지역에 따른 백그라운드 재생 제한 고지 대상 (FR-026).
    let mayStopInBackground: Bool

    static let all: [MusicProvider] = [
        MusicProvider(id: "apple_music", name: "Apple Music", urlString: "music://", mayStopInBackground: false),
        MusicProvider(id: "spotify", name: "Spotify", urlString: "spotify:", mayStopInBackground: true),
        MusicProvider(
            id: "youtube_music", name: "YouTube Music", urlString: "youtubemusic://", mayStopInBackground: true),
    ]

    var url: URL? { URL(string: urlString) }

    static let customLinkID = "custom_link"

    static func named(_ id: String?) -> MusicProvider? { all.first { $0.id == id } }
}

nonisolated enum LinkValidation {
    static let maxLength = 2_048

    /// 사용자 링크는 https만 허용한다. javascript:, file:, 자격 증명 포함 URL은 거부 (§7.4).
    static func validatedUserLink(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength,
            let components = URLComponents(string: trimmed),
            components.scheme?.lowercased() == "https",
            let host = components.host, !host.isEmpty, host.contains("."),
            components.user == nil, components.password == nil,
            let url = components.url
        else { return nil }
        return url
    }
}

protocol ExternalLaunching {
    func open(_ url: URL) async -> Bool
}

final class UIApplicationLauncher: ExternalLaunching {
    func open(_ url: URL) async -> Bool {
        await UIApplication.shared.open(url)
    }
}
