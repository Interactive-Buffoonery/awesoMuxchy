import Dispatch
import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

public enum AgentEventFileError: Error {
    case unableToPrepareDirectory
    case unableToCreateFile
}

public struct AgentEventEndpoint: Sendable {
    public let fileURL: URL
    public let environment: [String: String]

    public init(profileDirectory: URL, sessionID: UUID, paneID: UUID) throws {
        let directory = profileDirectory.appendingPathComponent("runtime-events", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            guard Self.isOwnedDirectory(directory) else {
                throw AgentEventFileError.unableToPrepareDirectory
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700], ofItemAtPath: directory.path
            )
            guard Self.isOwnerOnlyDirectory(directory) else {
                throw AgentEventFileError.unableToPrepareDirectory
            }
        } catch {
            throw AgentEventFileError.unableToPrepareDirectory
        }

        let fileURL = directory.appendingPathComponent("\(paneID.uuidString).jsonl")
        var descriptor = Self.createOwnerOnlyFile(at: fileURL)
        if descriptor < 0, errno == EEXIST, Self.removeStaleOwnerOnlyFile(at: fileURL) {
            descriptor = Self.createOwnerOnlyFile(at: fileURL)
        }
        guard descriptor >= 0 else { throw AgentEventFileError.unableToCreateFile }
        _ = close(descriptor)
        self.fileURL = fileURL
        environment = [
            AgentRuntimeEventProtocol.environmentProtocol: AgentRuntimeEventProtocol.identifier,
            AgentRuntimeEventProtocol.environmentSessionID: sessionID.uuidString,
            AgentRuntimeEventProtocol.environmentPaneID: paneID.uuidString,
            AgentRuntimeEventProtocol.environmentEventFile: fileURL.path,
        ]
    }

    private static func createOwnerOnlyFile(at url: URL) -> Int32 {
        url.path.withCString {
            open($0, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, mode_t(0o600))
        }
    }

    private static func isOwnerOnlyDirectory(_ url: URL) -> Bool {
        var info = stat()
        let status = url.path.withCString { lstat($0, &info) }
        return status == 0 && (info.st_mode & S_IFMT) == S_IFDIR
            && info.st_uid == getuid() && (info.st_mode & 0o077) == 0
    }

    private static func isOwnedDirectory(_ url: URL) -> Bool {
        var info = stat()
        let status = url.path.withCString { lstat($0, &info) }
        return status == 0 && (info.st_mode & S_IFMT) == S_IFDIR
            && info.st_uid == getuid()
    }

    private static func removeStaleOwnerOnlyFile(at url: URL) -> Bool {
        var info = stat()
        let status = url.path.withCString { lstat($0, &info) }
        guard status == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), (info.st_mode & 0o077) == 0
        else { return false }
        return url.path.withCString { unlink($0) } == 0
    }
}

public final class AgentEventWatcher: @unchecked Sendable {
    private static let maximumReadBytes = 64 * 1024
    private let fileURL: URL
    private let queue: DispatchQueue
    private let handler: @Sendable (AgentRuntimeUpdate) -> Void
    private var timer: DispatchSourceTimer?
    private var offset: UInt64 = 0
    private var remainder = Data()
    private var discardingOversizedLine = false

    public init(fileURL: URL, handler: @escaping @Sendable (AgentRuntimeUpdate) -> Void) {
        self.fileURL = fileURL
        self.handler = handler
        queue = DispatchQueue(label: "com.awesomux.agent-event-reader", qos: .utility)
    }

    deinit {
        timer?.cancel()
        try? FileManager.default.removeItem(at: fileURL)
    }

    public func start() {
        queue.async { [weak self] in
            guard let self, timer == nil else { return }
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(150))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer
            timer.resume()
        }
    }

    public func stop(removeFile: Bool = true) {
        queue.async { [weak self] in
            guard let self else { return }
            timer?.cancel()
            timer = nil
            remainder.removeAll(keepingCapacity: false)
            if removeFile { try? FileManager.default.removeItem(at: fileURL) }
        }
    }

    private func poll() {
        guard let handle = secureReadHandle() else { return }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return }
        if size < offset { offset = 0; remainder.removeAll(keepingCapacity: true) }
        guard size > offset else { return }
        do {
            try handle.seek(toOffset: offset)
            let count = min(Int(size - offset), Self.maximumReadBytes)
            guard let data = try handle.read(upToCount: count), !data.isEmpty else { return }
            offset += UInt64(data.count)
            consume(data)
        } catch { return }
    }

    private func consume(_ data: Data) {
        remainder.append(data)
        while let newline = remainder.firstIndex(of: 0x0A) {
            let line = Data(remainder[..<newline])
            remainder.removeSubrange(...newline)
            if discardingOversizedLine {
                discardingOversizedLine = false
            } else if let update = AgentRuntimeEventProtocol.decode(line: line) {
                handler(update)
            }
        }
        if remainder.count > AgentRuntimeEventProtocol.maximumLineBytes {
            remainder.removeAll(keepingCapacity: true)
            discardingOversizedLine = true
        }
    }

    private func secureReadHandle() -> FileHandle? {
        let descriptor = fileURL.path.withCString { open($0, O_RDONLY | O_NOFOLLOW | O_CLOEXEC) }
        guard descriptor >= 0 else { return nil }
        var info = stat()
        guard fstat(descriptor, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), (info.st_mode & 0o077) == 0
        else { _ = close(descriptor); return nil }
        return FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
    }
}
