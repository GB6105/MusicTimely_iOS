import Foundation

/// 원자적 로컬 저장소 (명세서 §9.2, NFR-005). 데이터 보호 등급을 걸고 백업에서 제외한다.
nonisolated protocol StateStore: Sendable {
    func loadCheckpoint() -> LoadResult<SessionCheckpoint>
    func saveCheckpoint(_ checkpoint: SessionCheckpoint) throws
    func deleteCheckpoint()
    func loadSettings() -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
    func loadThoughts() -> [ThoughtNote]
    func saveThoughts(_ thoughts: [ThoughtNote]) throws
    func deleteAll()
}

nonisolated enum LoadResult<Value: Sendable>: Sendable {
    case empty
    case loaded(Value)
    case corrupt
}

nonisolated final class FileStateStore: StateStore, @unchecked Sendable {
    private let directory: URL
    private let lock = NSLock()

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appending(path: "MusicTimely", directoryHint: .isDirectory)
        }
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var url = self.directory
        try? url.setResourceValues(values)
    }

    private func url(_ name: String) -> URL { directory.appending(path: name) }

    private func read<T: Decodable>(_ type: T.Type, _ name: String) -> LoadResult<T> {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: url(name)) else { return .empty }
        guard let value = try? JSONDecoder().decode(T.self, from: data) else { return .corrupt }
        return .loaded(value)
    }

    private func write<T: Encodable>(_ value: T, _ name: String) throws {
        lock.lock()
        defer { lock.unlock() }
        let data = try JSONEncoder().encode(value)
        try data.write(to: url(name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func remove(_ name: String) {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url(name))
    }

    func loadCheckpoint() -> LoadResult<SessionCheckpoint> {
        let result = read(SessionCheckpoint.self, "checkpoint.json")
        if case .loaded(let cp) = result, cp.schemaVersion != SessionCheckpoint.currentSchemaVersion { return .corrupt }
        return result
    }

    func saveCheckpoint(_ checkpoint: SessionCheckpoint) throws { try write(checkpoint, "checkpoint.json") }
    func deleteCheckpoint() { remove("checkpoint.json") }

    func loadSettings() -> AppSettings {
        if case .loaded(let settings) = read(AppSettings.self, "settings.json") { return settings.sanitized() }
        return AppSettings()
    }

    func saveSettings(_ settings: AppSettings) throws { try write(settings, "settings.json") }

    func loadThoughts() -> [ThoughtNote] {
        if case .loaded(let notes) = read([ThoughtNote].self, "thoughts.json") { return notes }
        return []
    }

    func saveThoughts(_ thoughts: [ThoughtNote]) throws { try write(thoughts, "thoughts.json") }

    func deleteAll() {
        for name in ["checkpoint.json", "settings.json", "thoughts.json"] { remove(name) }
    }
}
