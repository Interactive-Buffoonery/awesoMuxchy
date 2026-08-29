import Foundation

public enum ForegroundProcessLiveness: Equatable, Sendable {
    case exited
    case idleShell
    case busyShell
    case liveCommand
    case indeterminate

    public static func classify(
        processExited: Bool,
        commandName: String?,
        hasChildren: Bool?
    ) -> ForegroundProcessLiveness {
        if processExited { return .exited }
        guard let commandName else { return .indeterminate }
        guard ShellRecognition.isShell(commandName) else { return .liveCommand }
        return switch hasChildren {
        case true: .busyShell
        case false: .idleShell
        case nil: .indeterminate
        }
    }
}

public enum ShellRecognition {
    private static let names: Set<String> = [
        "ash", "bash", "csh", "dash", "elvish", "fish", "ksh", "mksh",
        "nu", "pwsh", "sh", "tcsh", "xonsh", "zsh",
    ]

    public static func isShell(_ rawName: String) -> Bool {
        let name = URL(fileURLWithPath: rawName)
            .lastPathComponent.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return names.contains(name)
    }
}

public struct PaneCloseRiskInput: Equatable, Sendable {
    public let agentName: String?
    public let agentState: AgentState
    public let lastAgentStateChangeAt: Date?
    public let terminalPromptObserved: Bool
    public let terminalAwayFromPrompt: Bool
    public let liveness: ForegroundProcessLiveness

    public init(
        agentName: String?,
        agentState: AgentState,
        lastAgentStateChangeAt: Date?,
        terminalPromptObserved: Bool,
        terminalAwayFromPrompt: Bool,
        liveness: ForegroundProcessLiveness
    ) {
        self.agentName = agentName
        self.agentState = agentState
        self.lastAgentStateChangeAt = lastAgentStateChangeAt
        self.terminalPromptObserved = terminalPromptObserved
        self.terminalAwayFromPrompt = terminalAwayFromPrompt
        self.liveness = liveness
    }
}

public enum PaneCloseRiskReason: Equatable, Sendable {
    case processExited
    case shellAtPrompt
    case liveForegroundProcess
    case backgroundJob
    case activeAgentExecution
    case terminalAwayFromPrompt
    case indeterminate
}

public struct PaneCloseRiskDecision: Equatable, Sendable {
    public let isRisk: Bool
    public let reason: PaneCloseRiskReason

    public init(isRisk: Bool, reason: PaneCloseRiskReason) {
        self.isRisk = isRisk
        self.reason = reason
    }
}

public enum WorkspaceCloseRiskPolicy {
    public static let staleAgentActivityThreshold: TimeInterval = 60

    public static func decision(
        _ input: PaneCloseRiskInput,
        at now: Date = Date()
    ) -> PaneCloseRiskDecision {
        if input.liveness == .exited {
            return .init(isRisk: false, reason: .processExited)
        }
        if input.terminalPromptObserved && input.terminalAwayFromPrompt {
            return .init(isRisk: true, reason: .terminalAwayFromPrompt)
        }
        switch input.liveness {
        case .busyShell:
            return .init(isRisk: true, reason: .backgroundJob)
        case .liveCommand:
            return .init(isRisk: true, reason: .liveForegroundProcess)
        case .indeterminate:
            return .init(isRisk: true, reason: .indeterminate)
        case .idleShell:
            if hasFreshAgentExecution(input, at: now) {
                return .init(isRisk: true, reason: .activeAgentExecution)
            }
            return .init(isRisk: false, reason: .shellAtPrompt)
        case .exited:
            return .init(isRisk: false, reason: .processExited)
        }
    }

    public static func workspaceHasRisk(
        _ inputs: some Sequence<PaneCloseRiskInput>,
        at now: Date = Date()
    ) -> Bool {
        inputs.contains { decision($0, at: now).isRisk }
    }

    private static func hasFreshAgentExecution(
        _ input: PaneCloseRiskInput,
        at now: Date
    ) -> Bool {
        guard input.agentName != nil else { return false }
        guard [.running, .thinking, .output].contains(input.agentState) else { return false }
        guard let changedAt = input.lastAgentStateChangeAt else {
            // Restored active state has no trustworthy age in the Linux schema;
            // fail closed until process/prompt evidence proves the pane idle.
            return true
        }
        return now.timeIntervalSince(changedAt) < staleAgentActivityThreshold
    }
}

public enum DestructiveClosePresentation {
    public static let closePaneHint = "Press ⌘Return to close pane. Esc cancels."
    public static let closeWorkspaceHint = "Press ⌘Return to close workspace. Esc cancels."
    public static let closeGroupHint = "Press ⌘Return to close group. Esc cancels."
    public static let clearWorkspaceHint = "Press ⌘Return to clear workspace. Esc cancels."

    public static func compactTitle(_ rawTitle: String) -> String {
        ChromeText.sanitized(rawTitle, limit: 60)
    }

    public static func isolatedTitle(_ rawTitle: String) -> String {
        "\u{2068}\(compactTitle(rawTitle))\u{2069}"
    }

    public static func closeWorkspaceTitle(_ rawTitle: String) -> String {
        "Close \(isolatedTitle(rawTitle))?"
    }

    public static func closePaneTitle(_ rawTitle: String) -> String {
        "Close pane in \(isolatedTitle(rawTitle))?"
    }

    public static func closePaneBody(_ rawTitle: String) -> String {
        "The active pane in \(isolatedTitle(rawTitle)) has activity that will be interrupted. Closing the pane will terminate the running process."
    }

    public static func closeWorkspaceBody(_ rawTitle: String) -> String {
        "\(isolatedTitle(rawTitle)) has activity that will be interrupted. Closing will terminate the running process."
    }

    public static func clearWorkspaceTitle(_ rawTitle: String) -> String {
        "Clear \(isolatedTitle(rawTitle))?"
    }

    public static func clearWorkspaceBody(_ rawTitle: String, hasRisk: Bool) -> String {
        if hasRisk {
            return "\(isolatedTitle(rawTitle)) has activity that will be interrupted. The workspace will be closed permanently and can't be reopened."
        }
        return "\(isolatedTitle(rawTitle)) will be closed permanently and can't be reopened."
    }

    public static func closeGroupTitle(_ rawName: String) -> String {
        "Close group \(isolatedTitle(rawName))?"
    }

    public static func closeGroupBody(riskyWorkspaceCount count: Int) -> String {
        if count == 1 {
            return "1 workspace in this group has running activity that will be interrupted. Closing will terminate its running process."
        }
        return "\(count) workspaces in this group have running activity that will be interrupted. Closing will terminate their running processes."
    }

    public static func spoken(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{2068}", with: "")
            .replacingOccurrences(of: "\u{2069}", with: "")
    }
}
