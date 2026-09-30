import Foundation
import OSLog

/// 카테고리별 로거. 사용 예: `Logger.app.info("launched")`
nonisolated extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "MusicTimely"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let data = Logger(subsystem: subsystem, category: "data")
}
