import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var theme: AppTheme
    public var notificationsMuted: Bool

    public init(theme: AppTheme = .system, notificationsMuted: Bool = false) {
        self.theme = theme
        self.notificationsMuted = notificationsMuted
    }
}

public struct AppPreferencesStore: Sendable {
    public static let maximumBytes = 64 * 1_024
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() -> AppPreferences {
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true, let size = values.fileSize, size <= Self.maximumBytes,
              let data = try? Data(contentsOf: url),
              let value = try? JSONDecoder().decode(AppPreferences.self, from: data) else { return AppPreferences() }
        return value
    }

    public func save(_ preferences: AppPreferences) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(preferences).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
