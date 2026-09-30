import Foundation
import Observation

/// Home 화면 상태. 뷰는 이 객체만 관찰하고, 데이터 접근은 Core/Services 계층에 위임한다.
@Observable
final class HomeViewModel {
    let appVersion: String

    /// - Parameter infoDictionary: 버전을 읽을 Info.plist 값. 테스트에서는 임의의 값을 주입한다.
    init(infoDictionary: [String: Any]? = Bundle.main.infoDictionary) {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "0"
        appVersion = "\(version) (\(build))"
    }
}
