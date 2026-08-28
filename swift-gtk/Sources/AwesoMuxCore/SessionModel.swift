import Foundation

public enum AgentState: String, Codable, CaseIterable, Sendable {
    case idle, running, waiting, thinking, output, needsAttention, done, error
}

public enum SessionOwnership: String, Codable, Sendable {
    case local
    case remoteZmx
}

public enum SplitAxis: String, Codable, Sendable {
    case horizontal, vertical
}

public enum WorkspaceGroupColor: String, Codable, CaseIterable, Sendable {
    case mauve, peach, green, teal, blue, pink, yellow, red, gray, sky, lavender
}

public struct PaneSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var title: String
    public var workingDirectory: String
    public var agent: String?
    public var agentState: AgentState
    public var ownership: SessionOwnership

    public init(
        id: UUID = UUID(),
        title: String,
        workingDirectory: String,
        agent: String? = nil,
        agentState: AgentState = .idle,
        ownership: SessionOwnership = .local
    ) {
        self.id = id
        self.title = title
        self.workingDirectory = workingDirectory
        self.agent = agent
        self.agentState = agentState
        self.ownership = ownership
    }
}

public indirect enum PaneLayout: Codable, Equatable, Sendable {
    case pane(PaneSnapshot)
    case split(axis: SplitAxis, fraction: Double, first: PaneLayout, second: PaneLayout)

    public var paneCount: Int {
        switch self {
        case .pane: 1
        case let .split(_, _, first, second): first.paneCount + second.paneCount
        }
    }

    public var paneIDs: [UUID] {
        switch self {
        case let .pane(pane): [pane.id]
        case let .split(_, _, first, second): first.paneIDs + second.paneIDs
        }
    }
}

public struct WorkspaceSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var isSoftClosed: Bool
    public var focusedPaneID: UUID
    public var layout: PaneLayout

    public init(
        id: UUID = UUID(),
        name: String,
        isSoftClosed: Bool = false,
        focusedPaneID: UUID,
        layout: PaneLayout
    ) {
        self.id = id
        self.name = name
        self.isSoftClosed = isSoftClosed
        self.focusedPaneID = focusedPaneID
        self.layout = layout
    }
}

public struct WorkspaceGroupSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var color: WorkspaceGroupColor?
    public var isCollapsed: Bool
    public var workspaces: [WorkspaceSnapshot]

    public init(
        id: UUID = UUID(),
        name: String,
        color: WorkspaceGroupColor? = nil,
        isCollapsed: Bool = false,
        workspaces: [WorkspaceSnapshot]
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.isCollapsed = isCollapsed
        self.workspaces = workspaces
    }
}

public struct SessionSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var selectedWorkspaceID: UUID?
    public var groups: [WorkspaceGroupSnapshot]

    public var workspaces: [WorkspaceSnapshot] {
        groups.flatMap(\.workspaces)
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        selectedWorkspaceID: UUID? = nil,
        groups: [WorkspaceGroupSnapshot] = []
    ) {
        self.schemaVersion = schemaVersion
        self.selectedWorkspaceID = selectedWorkspaceID
        self.groups = groups
    }

    public func validated() throws -> SessionSnapshot {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw SessionValidationError.unsupportedSchema(schemaVersion)
        }
        let groupIDs = groups.map(\.id)
        guard Set(groupIDs).count == groupIDs.count else {
            throw SessionValidationError.duplicateGroupID
        }
        let workspaceIDs = workspaces.map(\.id)
        guard Set(workspaceIDs).count == workspaceIDs.count else {
            throw SessionValidationError.duplicateWorkspaceID
        }
        if let selectedWorkspaceID, !workspaceIDs.contains(selectedWorkspaceID) {
            throw SessionValidationError.missingSelectedWorkspace
        }
        for workspace in workspaces {
            let paneIDs = workspace.layout.paneIDs
            guard Set(paneIDs).count == paneIDs.count else {
                throw SessionValidationError.duplicatePaneID(workspace.id)
            }
            guard paneIDs.contains(workspace.focusedPaneID) else {
                throw SessionValidationError.missingFocusedPane(workspace.id)
            }
        }
        return self
    }
}

public enum SessionValidationError: Error, Equatable {
    case unsupportedSchema(Int)
    case duplicateGroupID
    case duplicateWorkspaceID
    case missingSelectedWorkspace
    case duplicatePaneID(UUID)
    case missingFocusedPane(UUID)
}

public enum CloseDecision: Equatable, Sendable {
    case closePane(UUID)
    case softCloseWorkspace(UUID)
    case closeWindow
}

public enum ClosePolicy {
    public static func primaryClose(
        workspace: WorkspaceSnapshot,
        visibleWorkspaceCount: Int
    ) -> CloseDecision {
        if workspace.layout.paneCount > 1 {
            return .closePane(workspace.focusedPaneID)
        }
        if visibleWorkspaceCount > 1 {
            return .softCloseWorkspace(workspace.id)
        }
        return .closeWindow
    }
}
