import Foundation
import Testing
@testable import AwesoMuxCore

@Test func agentRuntimeEventMapsExplicitExecutionAndProvider() throws {
    let line = try #require(#"{"v":1,"source":"codex","execution":"thinking"}"#.data(using: .utf8))
    #expect(AgentRuntimeEventProtocol.decode(line: line) == AgentRuntimeUpdate(
        agent: "Codex", state: .thinking, attentionReason: nil
    ))
}

@Test func agentRuntimeEventAttentionOverridesExecution() throws {
    let line = try #require(#"{"v":1,"source":"claude-code","execution":"running","attentionReason":"permissionPrompt"}"#.data(using: .utf8))
    #expect(AgentRuntimeEventProtocol.decode(line: line) == AgentRuntimeUpdate(
        agent: "Claude Code", state: .needsAttention, attentionReason: .permissionPrompt
    ))
}

@Test func agentRuntimeEventPreservesUnknownAttentionAsActionable() throws {
    let line = try #require(#"{"v":1,"source":"grok","attentionReason":"futureReason"}"#.data(using: .utf8))
    #expect(AgentRuntimeEventProtocol.decode(line: line) == AgentRuntimeUpdate(
        agent: "Grok", state: .needsAttention, attentionReason: .unknown
    ))
}

@Test func agentRuntimeEventRejectsUnknownOrUnboundedInput() throws {
    let unknown = try #require(#"{"v":1,"source":"other","execution":"running"}"#.data(using: .utf8))
    let wrongVersion = try #require(#"{"v":2,"source":"codex","execution":"running"}"#.data(using: .utf8))
    let malformed = Data("not json".utf8)
    let oversized = Data(repeating: 0x20, count: AgentRuntimeEventProtocol.maximumLineBytes + 1)
    #expect(AgentRuntimeEventProtocol.decode(line: unknown) == nil)
    #expect(AgentRuntimeEventProtocol.decode(line: wrongVersion) == nil)
    #expect(AgentRuntimeEventProtocol.decode(line: malformed) == nil)
    #expect(AgentRuntimeEventProtocol.decode(line: oversized) == nil)
}

@Test func agentRuntimeEventSupportsLegacyStateField() throws {
    let line = try #require(#"{"v":1,"source":"pi","state":"output"}"#.data(using: .utf8))
    #expect(AgentRuntimeEventProtocol.decode(line: line) == AgentRuntimeUpdate(
        agent: "Pi", state: .output, attentionReason: nil
    ))
}

@Test func paneAgentUpdatePublishesProviderAndClearsAttentionReason() throws {
    let pane = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let workspace = WorkspaceSnapshot(name: "Runtime", focusedPaneID: pane.id, layout: .pane(pane))
    var value = SessionSnapshot(
        selectedWorkspaceID: workspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace])]
    )
    try value.updatePaneAgentState(
        paneID: pane.id, workspaceID: workspace.id, agent: "Codex",
        state: .needsAttention, attentionReason: .userInputRequired
    )
    #expect(value.workspace(id: workspace.id)?.layout.pane(id: pane.id)?.agent == "Codex")
    #expect(value.workspace(id: workspace.id)?.layout.pane(id: pane.id)?.attentionReason == .userInputRequired)

    try value.updatePaneAgentState(
        paneID: pane.id, workspaceID: workspace.id, agent: "Codex", state: .running
    )
    #expect(value.workspace(id: workspace.id)?.layout.pane(id: pane.id)?.attentionReason == nil)
}

@Test func agentEventEndpointIsOwnerOnlyAndPaneScoped() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("awesomux-agent-endpoint-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let sessionID = UUID(), paneID = UUID()
    let endpoint = try AgentEventEndpoint(
        profileDirectory: root, sessionID: sessionID, paneID: paneID
    )
    let attributes = try FileManager.default.attributesOfItem(atPath: endpoint.fileURL.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
    #expect(endpoint.environment[AgentRuntimeEventProtocol.environmentSessionID] == sessionID.uuidString)
    #expect(endpoint.environment[AgentRuntimeEventProtocol.environmentPaneID] == paneID.uuidString)
    #expect(endpoint.environment[AgentRuntimeEventProtocol.environmentEventFile] == endpoint.fileURL.path)
}

@Test func agentEventEndpointSafelyReplacesOwnerOnlyStaleFile() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("awesomux-agent-stale-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let paneID = UUID()
    let first = try AgentEventEndpoint(profileDirectory: root, sessionID: UUID(), paneID: paneID)
    try Data("stale".utf8).write(to: first.fileURL)
    try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: first.fileURL.path)
    let replacement = try AgentEventEndpoint(profileDirectory: root, sessionID: UUID(), paneID: paneID)
    #expect((try Data(contentsOf: replacement.fileURL)).isEmpty)
}

@Test func agentEventEndpointRejectsSymlinkedRuntimeDirectory() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("awesomux-agent-symlink-\(UUID().uuidString)", isDirectory: true)
    let target = FileManager.default.temporaryDirectory
        .appendingPathComponent("awesomux-agent-target-\(UUID().uuidString)", isDirectory: true)
    defer {
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.removeItem(at: target)
    }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
    try FileManager.default.createSymbolicLink(
        at: root.appendingPathComponent("runtime-events"), withDestinationURL: target
    )
    #expect(throws: AgentEventFileError.self) {
        _ = try AgentEventEndpoint(profileDirectory: root, sessionID: UUID(), paneID: UUID())
    }
}
