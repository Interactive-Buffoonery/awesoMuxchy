import Foundation

public enum AppTheme: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

public enum SidebarPosition: String, Codable, CaseIterable, Sendable {
    case left
    case right
}

public enum SidebarDensity: String, Codable, CaseIterable, Sendable {
    case standard
    case compact
}

public struct AppPreferences: Codable, Equatable, Sendable {
    public var theme: AppTheme
    public var notificationsMuted: Bool
    public var sidebarWidth: Int
    public var lastExpandedSidebarWidth: Int
    public var isSidebarHidden: Bool
    public var sidebarPosition: SidebarPosition
    public var sidebarDensity: SidebarDensity

    public init(
        theme: AppTheme = .system,
        notificationsMuted: Bool = false,
        sidebarWidth: Int = SidebarWidthPolicy.defaultWidth,
        lastExpandedSidebarWidth: Int = SidebarWidthPolicy.fallbackLastNonCollapsedWidth,
        isSidebarHidden: Bool = false,
        sidebarPosition: SidebarPosition = .left,
        sidebarDensity: SidebarDensity = .standard
    ) {
        self.theme = theme
        self.notificationsMuted = notificationsMuted
        self.sidebarWidth = SidebarWidthPolicy.committedWidth(for: Double(sidebarWidth))
        self.lastExpandedSidebarWidth = SidebarWidthPolicy.normalizedLastNonCollapsedWidth(
            Double(lastExpandedSidebarWidth)
        )
        self.isSidebarHidden = isSidebarHidden
        self.sidebarPosition = sidebarPosition
        self.sidebarDensity = sidebarDensity
    }

    private enum CodingKeys: String, CodingKey {
        case theme, notificationsMuted, sidebarWidth, lastExpandedSidebarWidth
        case isSidebarHidden, sidebarPosition, sidebarDensity
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            theme: try values.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system,
            notificationsMuted: try values.decodeIfPresent(Bool.self, forKey: .notificationsMuted) ?? false,
            sidebarWidth: try values.decodeIfPresent(Int.self, forKey: .sidebarWidth) ?? SidebarWidthPolicy.defaultWidth,
            lastExpandedSidebarWidth: try values.decodeIfPresent(Int.self, forKey: .lastExpandedSidebarWidth)
                ?? SidebarWidthPolicy.fallbackLastNonCollapsedWidth,
            isSidebarHidden: try values.decodeIfPresent(Bool.self, forKey: .isSidebarHidden) ?? false,
            sidebarPosition: try values.decodeIfPresent(SidebarPosition.self, forKey: .sidebarPosition) ?? .left,
            sidebarDensity: try values.decodeIfPresent(SidebarDensity.self, forKey: .sidebarDensity) ?? .standard
        )
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
