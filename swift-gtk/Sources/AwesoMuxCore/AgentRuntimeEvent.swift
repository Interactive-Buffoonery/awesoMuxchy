import Foundation

public struct AgentRuntimeUpdate: Equatable, Sendable {
    public let agent: String
    public let state: AgentState
    public let attentionReason: AttentionReason?
    public let phase: AgentRuntimePhase?

    public init(
        agent: String, state: AgentState, attentionReason: AttentionReason?,
        phase: AgentRuntimePhase? = nil
    ) {
        self.agent = agent
        self.state = state
        self.attentionReason = attentionReason
        self.phase = phase
    }

    /// The runtime's one-shot signal that a completed turn has remained
    /// unanswered. It deliberately does not become an attention reason: the
    /// pane remains receptive while its workspace is promoted in the sidebar.
    public var reportsUnansweredTurn: Bool {
        phase == .notification && state == .waiting && attentionReason == nil
    }
}

public enum AgentRuntimePhase: String, Codable, Sendable {
    case sessionStart
    case promptSubmit
    case toolStart
    case toolEnd
    case notification
    case stop
    case sessionEnd
    case rename
    case openDocument = "open-document"
}

public enum AgentRuntimeEventProtocol {
    public static let identifier = "awesomux-agent-v1"
    public static let maximumLineBytes = 4 * 1024

    public static let environmentProtocol = "AWESOMUX_AGENT_EVENT_PROTOCOL"
    public static let environmentSessionID = "AWESOMUX_SESSION_ID"
    public static let environmentPaneID = "AWESOMUX_PANE_ID"
    public static let environmentEventFile = "AWESOMUX_AGENT_EVENT_FILE"

    public static func decode(line: Data) -> AgentRuntimeUpdate? {
        guard !line.isEmpty, line.count <= maximumLineBytes,
              let event = try? JSONDecoder().decode(WireEvent.self, from: line),
              event.v == 1,
              let agent = displayName(for: event.source)
        else { return nil }

        if let rawReason = event.attentionReason {
            let reason = AttentionReason(rawValue: rawReason) ?? .unknown
            return AgentRuntimeUpdate(
                agent: agent, state: .needsAttention, attentionReason: reason,
                phase: event.phase
            )
        }
        guard let rawState = event.execution ?? event.state,
              let state = AgentState(rawValue: rawState)
        else { return nil }
        return AgentRuntimeUpdate(
            agent: agent, state: state, attentionReason: nil, phase: event.phase
        )
    }

    private static func displayName(for source: String) -> String? {
        switch source.lowercased() {
        case "claude-code": "Claude Code"
        case "codex": "Codex"
        case "opencode": "OpenCode"
        case "pi": "Pi"
        case "grok": "Grok"
        default: nil
        }
    }

    private struct WireEvent: Decodable {
        let v: Int
        let source: String
        let execution: String?
        let state: String?
        let attentionReason: String?
        let phase: AgentRuntimePhase?
    }
}
