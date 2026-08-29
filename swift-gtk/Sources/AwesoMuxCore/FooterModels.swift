import Dispatch
import Foundation
#if canImport(Glibc)
import Glibc
#else
import Darwin
#endif

public struct AgentActivityRow: Equatable, Sendable {
    public let workspaceID: UUID
    public let paneID: UUID
    public let workspace: String
    public let pane: String
    public let agent: String
    public let state: AgentState
    public let displayTitle: String
    public let location: String
    public let isSelected: Bool
}

public struct AgentActivityGroup: Equatable, Sendable {
    public let state: AgentState
    public let rows: [AgentActivityRow]
}

public struct AgentFooterSummary: Equatable, Sendable {
    public let groups: [AgentActivityGroup]
    public let rows: [AgentActivityRow]
    public let thinkingCount: Int
    public let outputCount: Int
    public let needsAttentionCount: Int

    public var totalCount: Int { rows.count }

    public func rows(matching state: AgentState) -> [AgentActivityRow] {
        rows.filter { $0.state == state }
    }

    public func nextRow(matching state: AgentState, after paneID: UUID?) -> AgentActivityRow? {
        let matches = rows(matching: state)
        guard !matches.isEmpty else { return nil }
        guard let paneID, let index = matches.firstIndex(where: { $0.paneID == paneID }) else {
            return matches[0]
        }
        return matches[(index + 1) % matches.count]
    }

    public init(snapshot: SessionSnapshot) {
        var traversalRows: [AgentActivityRow] = []
        for group in snapshot.groups {
            for workspace in group.workspaces where !workspace.isSoftClosed {
                let panes = workspace.layout.panes
                for pane in workspace.layout.panes {
                    guard let rawAgent = pane.agent,
                          !rawAgent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                    let path = FocusedPaneContext.displayPath(
                        pane.workingDirectory, homeDirectory: NSHomeDirectory()
                    )
                    traversalRows.append(AgentActivityRow(
                        workspaceID: workspace.id,
                        paneID: pane.id,
                        workspace: ChromeText.sanitized(workspace.name, limit: 80),
                        pane: ChromeText.sanitized(pane.title, limit: 80),
                        agent: ChromeText.sanitized(rawAgent, limit: 80),
                        state: pane.agentState,
                        displayTitle: ChromeText.sanitized(
                            panes.count > 1 ? pane.title : workspace.name, limit: 80
                        ),
                        location: pane.ownership == .remoteZmx ? "Remote · \(path)" : path,
                        isSelected: snapshot.selectedWorkspaceID == workspace.id
                            && workspace.focusedPaneID == pane.id
                    ))
                }
            }
        }
        let grouped = Dictionary(grouping: traversalRows, by: \.state)
        groups = grouped.keys.sorted { Self.priority($0) < Self.priority($1) }.map {
            AgentActivityGroup(state: $0, rows: grouped[$0] ?? [])
        }
        rows = groups.flatMap(\.rows)
        thinkingCount = rows.count { $0.state == .thinking }
        outputCount = rows.count { $0.state == .output }
        needsAttentionCount = rows.count { $0.state == .needsAttention }
    }

    private static func priority(_ state: AgentState) -> Int {
        switch state {
        case .needsAttention, .error: 0
        case .output: 1
        case .thinking: 2
        case .running, .waiting: 3
        case .idle, .done: 4
        }
    }
}

public extension AgentState {
    var activityLabel: String {
        switch self {
        case .idle: "Idle"
        case .running: "Running"
        case .waiting: "Waiting"
        case .thinking: "Thinking"
        case .output: "Output"
        case .needsAttention: "Needs Attention"
        case .done: "Done"
        case .error: "Error"
        }
    }
}

public enum AgentFooterWording {
    public static func agentsInState(count: Int, state: AgentState) -> String {
        "\(count) \(state.activityLabel.lowercased()) \(count == 1 ? "agent" : "agents")"
    }

    public static func agentsTotal(count: Int) -> String {
        "\(count) \(count == 1 ? "agent" : "agents")"
    }
}

public extension PaneLayout {
    var panes: [PaneSnapshot] {
        switch self {
        case let .pane(pane): [pane]
        case let .split(_, _, first, second): first.panes + second.panes
        }
    }
}

public struct GitWorkingCopyStatus: Equatable, Sendable {
    public let dirtyCount: Int
    public let ahead: Int
    public let behind: Int
    public let reportedBranch: String?

    public init(dirtyCount: Int, ahead: Int, behind: Int, reportedBranch: String? = nil) {
        self.dirtyCount = dirtyCount
        self.ahead = ahead
        self.behind = behind
        self.reportedBranch = reportedBranch
    }

    public init(porcelainV2: Data) {
        var dirty = 0
        var ahead = 0
        var behind = 0
        var branch: String?
        for line in String(decoding: porcelainV2, as: UTF8.self).split(whereSeparator: { $0 == "\n" || $0 == "\r" }) {
            if line.hasPrefix("# branch.ab ") {
                for field in line.dropFirst("# branch.ab ".count).split(separator: " ") {
                    if field.hasPrefix("+") { ahead = Int(field.dropFirst()) ?? 0 }
                    if field.hasPrefix("-") { behind = Int(field.dropFirst()) ?? 0 }
                }
            } else if line.hasPrefix("# branch.head ") {
                branch = String(line.dropFirst("# branch.head ".count))
            } else if !line.hasPrefix("#") && !line.isEmpty {
                dirty += 1
            }
        }
        self.init(dirtyCount: dirty, ahead: ahead, behind: behind, reportedBranch: branch)
    }
}

public struct PullRequestStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable { case open, draft, inReview }
    public let number: Int
    public let url: URL
    public let state: State

    public init?(ghJSON: Data) {
        struct Payload: Decodable {
            let number: Int
            let url: String
            let state: String
            let isDraft: Bool
            let reviewDecision: String?
        }
        guard let value = try? JSONDecoder().decode(Payload.self, from: ghJSON),
              value.number > 0, value.state.uppercased() == "OPEN",
              let url = URL(string: value.url), url.scheme?.lowercased() == "https" else { return nil }
        number = value.number
        self.url = url
        if value.isDraft { state = .draft }
        else if ["REVIEW_REQUIRED", "CHANGES_REQUESTED"].contains(value.reviewDecision?.uppercased() ?? "") { state = .inReview }
        else { state = .open }
    }
}

public struct CIStatus: Equatable, Sendable {
    public enum State: Equatable, Sendable { case failing, running }
    public let state: State
    public let url: URL
    public let runDatabaseID: Int
    public let repoSlug: String?
    public let workflowName: String?

    public init?(ghJSON: Data) {
        struct Payload: Decodable {
            let databaseId: Int
            let status: String
            let conclusion: String?
            let url: String
            let workflowName: String?
        }
        guard let values = try? JSONDecoder().decode([Payload].self, from: ghJSON), let value = values.first,
              value.databaseId > 0, let url = URL(string: value.url), url.scheme?.lowercased() == "https" else { return nil }
        let status = value.status.lowercased()
        if status == "completed" {
            guard ["failure", "timed_out", "startup_failure"].contains(value.conclusion?.lowercased() ?? "") else { return nil }
            state = .failing
        } else {
            guard ["queued", "in_progress", "requested", "waiting", "pending"].contains(status) else { return nil }
            state = .running
        }
        self.url = url
        runDatabaseID = value.databaseId
        workflowName = value.workflowName.map { ChromeText.sanitized($0, limit: 120) }.flatMap { $0.isEmpty ? nil : $0 }
        repoSlug = Self.githubRepoSlug(url: url, runID: value.databaseId)
    }

    private static func githubRepoSlug(url: URL, runID: Int) -> String? {
        guard url.host?.lowercased() == "github.com" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 5, parts[2] == "actions", parts[3] == "runs", parts[4] == String(runID) else { return nil }
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
        guard [parts[0], parts[1]].allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy(allowed.contains) }) else { return nil }
        return "\(parts[0])/\(parts[1])"
    }
}

public struct InstalledEditor: Equatable, Sendable {
    public let name: String
    public let executable: String
    public init(name: String, executable: String) { self.name = name; self.executable = executable }
}

public struct TerminalFooterDetails: Equatable, Sendable {
    public let context: FocusedPaneContext
    public let repoRoot: String?
    public let branch: String?
    public let branches: [String]
    public let git: GitWorkingCopyStatus?
    public let pullRequest: PullRequestStatus?
    public let ci: CIStatus?
    public let editors: [InstalledEditor]

    public init(context: FocusedPaneContext, repoRoot: String?, branch: String?, branches: [String], git: GitWorkingCopyStatus?, pullRequest: PullRequestStatus?, ci: CIStatus?, editors: [InstalledEditor]) {
        self.context = context
        self.repoRoot = repoRoot
        self.branch = branch
        self.branches = branches
        self.git = git
        self.pullRequest = pullRequest
        self.ci = ci
        self.editors = editors
    }

    public var pathPresentation: FooterPathPresentation {
        FooterPathPresentation(context: context, repoRoot: repoRoot)
    }
}

public struct FooterPathPresentation: Equatable, Sendable {
    public let project: String
    public let path: String

    public init(context: FocusedPaneContext, repoRoot: String?) {
        guard let repoRoot else {
            project = context.project
            path = context.path
            return
        }
        let canonicalRoot = (repoRoot as NSString).standardizingPath
        let canonicalDirectory = (context.copyPath as NSString).standardizingPath
        guard canonicalDirectory == canonicalRoot || canonicalDirectory.hasPrefix(canonicalRoot + "/") else {
            project = context.project
            path = context.path
            return
        }
        project = ChromeText.sanitized((canonicalRoot as NSString).lastPathComponent, limit: 80)
        if canonicalDirectory == canonicalRoot {
            path = "repo root"
        } else {
            path = ChromeText.sanitized(String(canonicalDirectory.dropFirst(canonicalRoot.count + 1)), limit: 180)
        }
    }
}

public struct BoundedCommandRunner: Sendable {
    private final class OutputBuffer: @unchecked Sendable {
        private let lock = NSLock()
        private var data = Data()

        func append(_ chunk: Data, limit: Int) {
            lock.lock()
            defer { lock.unlock() }
            if data.count < limit { data.append(chunk.prefix(limit - data.count)) }
        }

        func value() -> Data {
            lock.lock()
            defer { lock.unlock() }
            return data
        }
    }

    public let timeout: TimeInterval
    public let outputLimit: Int

    public init(timeout: TimeInterval = 2, outputLimit: Int = 256 * 1_024) {
        self.timeout = timeout
        self.outputLimit = outputLimit
    }

    public func run(executable: String, arguments: [String], directory: String) -> Data? {
        guard FileManager.default.isExecutableFile(atPath: executable) else { return nil }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        process.environment = ProcessInfo.processInfo.environment.merging([
            "GH_PROMPT_DISABLED": "1",
            "GIT_OPTIONAL_LOCKS": "0",
            "GIT_TERMINAL_PROMPT": "0",
        ]) { _, pinned in pinned }
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        let buffer = OutputBuffer()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            buffer.append(chunk, limit: outputLimit)
        }
        do { try process.run() } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            return nil
        }
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.01) }
        if process.isRunning {
            process.terminate()
            let grace = Date().addingTimeInterval(0.2)
            while process.isRunning && Date() < grace { Thread.sleep(forTimeInterval: 0.01) }
            if process.isRunning { _ = kill(process.processIdentifier, SIGKILL) }
        }
        process.waitUntilExit()
        pipe.fileHandleForReading.readabilityHandler = nil
        let tail = pipe.fileHandleForReading.readDataToEndOfFile()
        buffer.append(tail, limit: outputLimit)
        return process.terminationStatus == 0 ? buffer.value() : nil
    }
}

public struct TerminalFooterResolver: Sendable {
    private final class DataResult: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: Data?
        func set(_ value: Data?) { lock.withLock { storage = value } }
        func get() -> Data? { lock.withLock { storage } }
    }

    private let runner: BoundedCommandRunner
    public init(runner: BoundedCommandRunner = BoundedCommandRunner()) { self.runner = runner }

    public func resolve(_ context: FocusedPaneContext) -> TerminalFooterDetails {
        let directory = validatedDirectory(context.copyPath)
        let editors = Self.installedEditors()
        guard let directory, let repoRoot = repositoryRoot(from: directory), let branch = currentBranch(repoRoot: repoRoot) else {
            return TerminalFooterDetails(context: context, repoRoot: nil, branch: nil, branches: [], git: nil, pullRequest: nil, ci: nil, editors: editors)
        }
        let statusResult = DataResult()
        let branchesResult = DataResult()
        let prResult = DataResult()
        let ciResult = DataResult()
        let group = DispatchGroup()
        let queue = DispatchQueue.global(qos: .utility)
        group.enter()
        queue.async {
            statusResult.set(git(["--no-optional-locks", "-c", "core.fsmonitor=false", "status", "--porcelain=v2", "--branch", "--ahead-behind", "--untracked-files=normal"], at: repoRoot))
            group.leave()
        }
        group.enter()
        queue.async {
            branchesResult.set(git(["--no-optional-locks", "-c", "core.fsmonitor=false", "for-each-ref", "--sort=-committerdate", "--format=%(refname:short)", "refs/heads"], at: repoRoot))
            group.leave()
        }
        if !branch.hasPrefix("@ ") {
            group.enter()
            queue.async {
                prResult.set(gh(["pr", "view", "--json", "number,url,state,isDraft,reviewDecision", "--", branch], at: repoRoot))
                group.leave()
            }
            group.enter()
            queue.async {
                ciResult.set(gh(["run", "list", "--branch", branch, "--limit", "1", "--json", "databaseId,status,conclusion,url,workflowName"], at: repoRoot))
                group.leave()
            }
        }
        group.wait()
        let statusData = statusResult.get()
        var status = statusData.map(GitWorkingCopyStatus.init(porcelainV2:))
        if let reported = status?.reportedBranch, reported != branch {
            status = GitWorkingCopyStatus(dirtyCount: status?.dirtyCount ?? 0, ahead: 0, behind: 0)
        }
        let branchData = branchesResult.get()
        let branches = branchData.map(Self.parseBranches) ?? []
        let prData = prResult.get()
        let ciData = ciResult.get()
        return TerminalFooterDetails(context: context, repoRoot: repoRoot, branch: branch, branches: branches,
            git: status, pullRequest: prData.flatMap(PullRequestStatus.init(ghJSON:)),
            ci: ciData.flatMap(CIStatus.init(ghJSON:)), editors: editors)
    }

    private func validatedDirectory(_ value: String) -> String? {
        let canonical = URL(fileURLWithPath: value, isDirectory: true).resolvingSymlinksInPath().standardized.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: canonical, isDirectory: &isDirectory), isDirectory.boolValue else { return nil }
        return canonical
    }

    private func repositoryRoot(from directory: String) -> String? {
        var candidate = directory
        while true {
            let marker = (candidate as NSString).appendingPathComponent(".git")
            if FileManager.default.fileExists(atPath: marker) {
                guard let attributes = try? FileManager.default.attributesOfItem(atPath: marker),
                      attributes[.type] as? FileAttributeType != .typeSymbolicLink else { return nil }
                guard let data = git(["--no-optional-locks", "-c", "core.fsmonitor=false", "rev-parse", "--show-toplevel"], at: candidate),
                      let line = Self.singleLine(data), let validated = validatedDirectory(line),
                      directory == validated || directory.hasPrefix(validated + "/") else { return nil }
                return validated
            }
            let parent = (candidate as NSString).deletingLastPathComponent
            if parent == candidate || parent.isEmpty { return nil }
            candidate = parent
        }
    }

    private func currentBranch(repoRoot: String) -> String? {
        guard let data = git(["--no-optional-locks", "-c", "core.fsmonitor=false", "symbolic-ref", "--quiet", "--short", "HEAD"], at: repoRoot),
              let line = Self.singleLine(data) else {
            guard let sha = git(["--no-optional-locks", "-c", "core.fsmonitor=false", "rev-parse", "--short=8", "HEAD"], at: repoRoot).flatMap(Self.singleLine) else { return nil }
            return "@ \(ChromeText.sanitized(sha, limit: 20))"
        }
        let branch = ChromeText.sanitized(line, limit: max(1, line.count + 1))
        return branch.isEmpty || branch.count > 120 ? nil : branch
    }

    private func git(_ arguments: [String], at directory: String) -> Data? {
        runner.run(executable: "/usr/bin/git", arguments: arguments, directory: directory)
    }

    private func gh(_ arguments: [String], at directory: String) -> Data? {
        runner.run(executable: "/usr/bin/gh", arguments: arguments, directory: directory)
    }

    private static func singleLine(_ data: Data) -> String? {
        let line = String(decoding: data, as: UTF8.self).split(whereSeparator: { $0 == "\n" || $0 == "\r" }).first.map(String.init)
        return line?.isEmpty == false ? line : nil
    }

    public static func parseBranches(_ data: Data) -> [String] {
        var seen = Set<String>()
        return String(decoding: data, as: UTF8.self)
            .split(whereSeparator: { $0 == "\n" || $0 == "\r" })
            .map { raw in
                let value = String(raw)
                return ChromeText.sanitized(value, limit: max(1, value.count + 1))
            }
            .filter { !$0.isEmpty && $0.count <= 120 && !$0.hasPrefix("-") && seen.insert($0).inserted }
    }

    public static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    public static func installedEditors(path: String? = ProcessInfo.processInfo.environment["PATH"]) -> [InstalledEditor] {
        let candidates = [("Visual Studio Code", "code"), ("Visual Studio Code - Insiders", "code-insiders"),
            ("Cursor", "cursor"), ("Windsurf", "windsurf"), ("Zed", "zed"),
            ("Sublime Text", "subl"), ("Android Studio", "studio"), ("IntelliJ IDEA", "idea"),
            ("PyCharm", "pycharm"), ("WebStorm", "webstorm"), ("CLion", "clion"), ("GoLand", "goland")]
        let directories = (path ?? "").split(separator: ":").map(String.init).filter { $0.hasPrefix("/") }
        return candidates.compactMap { name, command in
            guard let executable = directories.map({ ($0 as NSString).appendingPathComponent(command) })
                .first(where: FileManager.default.isExecutableFile(atPath:)) else { return nil }
            return InstalledEditor(name: name, executable: executable)
        }
    }
}
