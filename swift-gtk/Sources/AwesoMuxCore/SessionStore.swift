import Foundation

public struct SessionStore: Sendable {
    public let snapshotURL: URL
    public let quarantineDirectoryURL: URL

    public init(snapshotURL: URL, quarantineDirectoryURL: URL) {
        self.snapshotURL = snapshotURL
        self.quarantineDirectoryURL = quarantineDirectoryURL
    }

    public func load() throws -> SessionSnapshot {
        let data = try Data(contentsOf: snapshotURL)
        do {
            return try JSONDecoder().decode(SessionSnapshot.self, from: data).validated()
        } catch {
            try quarantine(data: data)
            throw error
        }
    }

    public func save(_ snapshot: SessionSnapshot) throws {
        let validated = try snapshot.validated()
        let directory = snapshotURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(validated)
        try data.write(to: snapshotURL, options: [.atomic])
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: snapshotURL.path
        )
    }

    private func quarantine(data: Data) throws {
        try FileManager.default.createDirectory(
            at: quarantineDirectoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let formatter = ISO8601DateFormatter()
        let name = "session-\(formatter.string(from: Date())).invalid.json"
            .replacingOccurrences(of: ":", with: "-")
        try data.write(
            to: quarantineDirectoryURL.appendingPathComponent(name),
            options: [.atomic]
        )
    }
}
