import Foundation

public enum CommandAvailabilityProjection {
    public static let implementedCommandIDs: Set<CommandID> = [
        .newWorkspace, .newWorkspaceInCurrentDirectory, .newWorkspaceGroup,
        .renameWorkspace, .acknowledgeWorkspace, .togglePinWorkspace,
        .closeWorkspace, .clearWorkspace, .reopenClosedWorkspace,
        .splitRight, .splitDown, .closePane,
        .growActivePane, .shrinkActivePane,
        .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
        .focusPane1, .focusPane2, .focusPane3,
        .focusPane4, .focusPane5, .focusPane6,
        .jumpWorkspace1, .jumpWorkspace2, .jumpWorkspace3, .jumpWorkspace4,
        .jumpWorkspace5, .jumpWorkspace6, .jumpWorkspace7, .jumpWorkspace8,
        .jumpWorkspace9,
        .commandPalette, .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility,
    ]

    public static func enabledCommandIDs(
        snapshot: SessionSnapshot,
        isSheetPresented: Bool,
        isSidebarTargetAvailable: Bool = true
    ) -> Set<CommandID> {
        Set(implementedCommandIDs.filter {
            isEnabled(
                $0,
                snapshot: snapshot,
                isSheetPresented: isSheetPresented,
                isSidebarTargetAvailable: isSidebarTargetAvailable
            )
        })
    }

    public static func canAcknowledgeWorkspace(
        _ workspaceID: UUID,
        in snapshot: SessionSnapshot
    ) -> Bool {
        guard let workspace = snapshot.workspace(id: workspaceID) else { return false }
        return workspace.layout.panes.contains { pane in
            snapshot.unansweredTurnPaneIDs.contains(pane.id)
                || (pane.agentState == .needsAttention
                    && !workspace.acknowledgedAttentionPaneIDs.contains(pane.id))
        }
    }

    private static func isEnabled(
        _ command: CommandID,
        snapshot: SessionSnapshot,
        isSheetPresented: Bool,
        isSidebarTargetAvailable: Bool
    ) -> Bool {
        let workspaceCount = snapshot.groups.reduce(into: 0) { count, group in
            count += group.workspaces.lazy.filter { !$0.isSoftClosed }.count
        }
        let selected = snapshot.selectedWorkspace
        let paneCount = selected?.layout.paneCount ?? 0

        if let index = command.workspaceJumpIndex {
            return !isSheetPresented && index < workspaceCount
        }
        if let index = command.paneFocusIndex {
            return index <= paneCount
        }

        return switch command {
        case .newWorkspace:
            true
        case .newWorkspaceInCurrentDirectory:
            WorkspaceCreationTarget.currentDirectory(in: snapshot) != nil
        case .newWorkspaceGroup:
            !isSheetPresented
        case .renameWorkspace, .closeWorkspace, .clearWorkspace, .closePane:
            selected != nil && !isSheetPresented
        case .acknowledgeWorkspace:
            selected.map { canAcknowledgeWorkspace($0.id, in: snapshot) } ?? false
        case .togglePinWorkspace:
            selected != nil && !isSheetPresented
        case .reopenClosedWorkspace:
            !snapshot.recentlyClosedWorkspaces.isEmpty
        case .splitRight, .splitDown:
            selected != nil
        case .growActivePane, .shrinkActivePane, .previousPane, .nextPane:
            paneCount > 1
        case .previousWorkspace, .nextWorkspace:
            workspaceCount > 1
        case .commandPalette:
            !isSheetPresented
        case .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility:
            !isSheetPresented && isSidebarTargetAvailable
        case .keyboardShortcuts:
            false
        case .jumpWorkspace1, .jumpWorkspace2, .jumpWorkspace3,
             .jumpWorkspace4, .jumpWorkspace5, .jumpWorkspace6,
             .jumpWorkspace7, .jumpWorkspace8, .jumpWorkspace9,
             .focusPane1, .focusPane2, .focusPane3,
             .focusPane4, .focusPane5, .focusPane6:
            false
        }
    }
}
