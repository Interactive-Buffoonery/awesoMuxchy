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

    public func pane(id: UUID) -> PaneSnapshot? {
        switch self {
        case let .pane(pane):
            return pane.id == id ? pane : nil
        case let .split(_, _, first, second):
            return first.pane(id: id) ?? second.pane(id: id)
        }
    }

    func validateStructure(depth: Int = 0) throws {
        guard depth <= 32 else { throw SessionValidationError.layoutTooDeep }
        switch self {
        case let .pane(pane):
            guard !pane.workingDirectory.isEmpty,
                  pane.workingDirectory.utf8.count <= 4_096,
                  pane.title.utf8.count <= 512
            else {
                throw SessionValidationError.invalidPaneText(pane.id)
            }
        case let .split(_, fraction, first, second):
            guard fraction.isFinite, (0.05...0.95).contains(fraction) else {
                throw SessionValidationError.invalidSplitFraction
            }
            try first.validateStructure(depth: depth + 1)
            try second.validateStructure(depth: depth + 1)
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
    public var pinnedWorkspaceIDs: [UUID]
    public var attentionWorkspaceIDs: [UUID]

    public var workspaces: [WorkspaceSnapshot] {
        groups.flatMap(\.workspaces)
    }

    public init(
        schemaVersion: Int = currentSchemaVersion,
        selectedWorkspaceID: UUID? = nil,
        groups: [WorkspaceGroupSnapshot] = [],
        pinnedWorkspaceIDs: [UUID] = [],
        attentionWorkspaceIDs: [UUID] = []
    ) {
        self.schemaVersion = schemaVersion
        self.selectedWorkspaceID = selectedWorkspaceID
        self.groups = groups
        self.pinnedWorkspaceIDs = pinnedWorkspaceIDs
        self.attentionWorkspaceIDs = attentionWorkspaceIDs
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, selectedWorkspaceID, groups, pinnedWorkspaceIDs, attentionWorkspaceIDs
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            schemaVersion: try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? Self.currentSchemaVersion,
            selectedWorkspaceID: try values.decodeIfPresent(UUID.self, forKey: .selectedWorkspaceID),
            groups: try values.decodeIfPresent([WorkspaceGroupSnapshot].self, forKey: .groups) ?? [],
            pinnedWorkspaceIDs: try values.decodeIfPresent([UUID].self, forKey: .pinnedWorkspaceIDs) ?? [],
            attentionWorkspaceIDs: try values.decodeIfPresent([UUID].self, forKey: .attentionWorkspaceIDs) ?? []
        )
    }

    public func validated() throws -> SessionSnapshot {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw SessionValidationError.unsupportedSchema(schemaVersion)
        }
        guard groups.count <= 128 else {
            throw SessionValidationError.snapshotLimitExceeded
        }
        let groupIDs = groups.map(\.id)
        guard Set(groupIDs).count == groupIDs.count else {
            throw SessionValidationError.duplicateGroupID
        }
        for group in groups {
            let name = group.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, group.name.utf8.count <= 512 else {
                throw SessionValidationError.invalidGroupName(group.id)
            }
        }
        let workspaceIDs = workspaces.map(\.id)
        guard workspaceIDs.count <= 512 else {
            throw SessionValidationError.snapshotLimitExceeded
        }
        guard Set(workspaceIDs).count == workspaceIDs.count else {
            throw SessionValidationError.duplicateWorkspaceID
        }
        guard Set(pinnedWorkspaceIDs).count == pinnedWorkspaceIDs.count,
              Set(attentionWorkspaceIDs).count == attentionWorkspaceIDs.count,
              pinnedWorkspaceIDs.allSatisfy(Set(workspaceIDs).contains),
              attentionWorkspaceIDs.allSatisfy(Set(workspaceIDs).contains)
        else { throw SessionValidationError.invalidSidebarProjectionIDs }
        if let selectedWorkspaceID,
           !workspaces.contains(where: {
               $0.id == selectedWorkspaceID && !$0.isSoftClosed
           }) {
            throw SessionValidationError.missingSelectedWorkspace
        }
        for workspace in workspaces {
            guard workspace.name.utf8.count <= 512 else {
                throw SessionValidationError.invalidWorkspaceName(workspace.id)
            }
            try workspace.layout.validateStructure()
            let paneIDs = workspace.layout.paneIDs
            guard paneIDs.count <= 64 else {
                throw SessionValidationError.snapshotLimitExceeded
            }
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
    case invalidSplitFraction
    case layoutTooDeep
    case snapshotLimitExceeded
    case invalidPaneText(UUID)
    case invalidWorkspaceName(UUID)
    case invalidGroupName(UUID)
    case invalidSidebarProjectionIDs
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
