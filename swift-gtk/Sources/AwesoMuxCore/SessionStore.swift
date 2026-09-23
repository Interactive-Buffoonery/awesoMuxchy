import Foundation

public enum SessionProfileError: Error, Equatable {
    case invalidProfileName
}

public struct SessionProfilePaths: Equatable, Sendable {
    public let snapshotURL: URL
    public let previousSnapshotURL: URL
    public let quarantineDirectoryURL: URL

    public init(
        profile: String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
    ) throws {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        guard !profile.isEmpty,
              profile != ".",
              profile != "..",
              profile.unicodeScalars.allSatisfy(allowed.contains)
        else {
            throw SessionProfileError.invalidProfileName
        }
        let stateRoot: URL
        if let configured = environment["XDG_STATE_HOME"], !configured.isEmpty {
            stateRoot = URL(fileURLWithPath: configured, isDirectory: true)
        } else {
            stateRoot = homeDirectory
                .appendingPathComponent(".local", isDirectory: true)
                .appendingPathComponent("state", isDirectory: true)
        }
        let profileRoot = stateRoot
            .appendingPathComponent("awesomux", isDirectory: true)
            .appendingPathComponent("profiles", isDirectory: true)
            .appendingPathComponent(profile, isDirectory: true)
        snapshotURL = profileRoot.appendingPathComponent("session.json")
        previousSnapshotURL = profileRoot.appendingPathComponent("session.previous.json")
        quarantineDirectoryURL = profileRoot.appendingPathComponent("quarantine", isDirectory: true)
    }
}

public enum SessionLoadOutcome: Equatable, Sendable {
    case missing
    case restored(SessionSnapshot)
    case recoveredPrevious(SessionSnapshot)
    case resetAfterQuarantine
}

public enum SessionStoreError: Error, Equatable {
    case snapshotTooLarge
}

public struct SessionStore: Sendable {
    public static let maximumSnapshotBytes = 4 * 1024 * 1024
    public let snapshotURL: URL
    public let previousSnapshotURL: URL
    public let quarantineDirectoryURL: URL

    public init(
        snapshotURL: URL,
        previousSnapshotURL: URL? = nil,
        quarantineDirectoryURL: URL
    ) {
        self.snapshotURL = snapshotURL
        self.previousSnapshotURL = previousSnapshotURL
            ?? snapshotURL.deletingLastPathComponent()
                .appendingPathComponent("session.previous.json")
        self.quarantineDirectoryURL = quarantineDirectoryURL
    }

    public init(paths: SessionProfilePaths) {
        self.init(
            snapshotURL: paths.snapshotURL,
            previousSnapshotURL: paths.previousSnapshotURL,
            quarantineDirectoryURL: paths.quarantineDirectoryURL
        )
    }

    public func load() throws -> SessionSnapshot {
        do {
            return try decodeSnapshot(at: snapshotURL)
        } catch {
            try quarantineFile(at: snapshotURL, label: "session")
            throw error
        }
    }

    public func loadRecovering() throws -> SessionLoadOutcome {
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            return .missing
        }
        do {
            return .restored(try decodeSnapshot(at: snapshotURL))
        } catch {
            try quarantineFile(at: snapshotURL, label: "current")
            guard FileManager.default.fileExists(atPath: previousSnapshotURL.path) else {
                return .resetAfterQuarantine
            }
            do {
                return .recoveredPrevious(try decodeSnapshot(at: previousSnapshotURL))
            } catch {
                try quarantineFile(at: previousSnapshotURL, label: "previous")
                return .resetAfterQuarantine
            }
        }
    }

    public func save(_ snapshot: SessionSnapshot) throws {
        let validated = try snapshot.validated()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(validated)
        guard data.count <= Self.maximumSnapshotBytes else {
            throw SessionStoreError.snapshotTooLarge
        }
        let directory = snapshotURL.deletingLastPathComponent()
        try prepareDirectory(directory)
        if FileManager.default.fileExists(atPath: snapshotURL.path),
           (try? decodeSnapshot(at: snapshotURL)) != nil {
            let previousData = try Data(contentsOf: snapshotURL)
            try writeOwnerOnly(previousData, to: previousSnapshotURL)
        }
        try writeOwnerOnly(data, to: snapshotURL)
    }

    private func decodeSnapshot(at url: URL) throws -> SessionSnapshot {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard values.isRegularFile == true,
              let size = values.fileSize,
              size <= Self.maximumSnapshotBytes
        else {
            throw SessionStoreError.snapshotTooLarge
        }
        return try JSONDecoder().decode(
            SessionSnapshot.self,
            from: Data(contentsOf: url)
        ).validated()
    }

    private func writeOwnerOnly(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }

    private func prepareDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )
    }

    private func quarantineFile(at source: URL, label: String) throws {
        try prepareDirectory(quarantineDirectoryURL)
        let formatter = ISO8601DateFormatter()
        let name = "\(label)-\(formatter.string(from: Date()))-\(UUID().uuidString).invalid.json"
            .replacingOccurrences(of: ":", with: "-")
        let destination = quarantineDirectoryURL.appendingPathComponent(name)
        try FileManager.default.moveItem(at: source, to: destination)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: destination.path
        )
    }
}
