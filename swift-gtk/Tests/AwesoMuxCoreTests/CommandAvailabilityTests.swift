import Foundation
import Testing
@testable import AwesoMuxCore

@Test func commandAvailabilityDisablesContextCommandsWithoutAWorkspace() {
    let enabled = CommandAvailabilityProjection.enabledCommandIDs(
        snapshot: SessionSnapshot(), isSheetPresented: false
    )

    #expect(enabled == [
        .newWorkspace, .newWorkspaceGroup, .commandPalette,
        .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility,
    ])
    #expect(!CommandAvailabilityProjection.implementedCommandIDs.contains(.keyboardShortcuts))
}

@Test func commandAvailabilityTracksOneWorkspaceAndOnePaneTruthfully() {
    let pane = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let workspace = WorkspaceSnapshot(
        name: "One", focusedPaneID: pane.id, layout: .pane(pane)
    )
    let snapshot = SessionSnapshot(
        selectedWorkspaceID: workspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace])]
    )
    let enabled = CommandAvailabilityProjection.enabledCommandIDs(
        snapshot: snapshot, isSheetPresented: false
    )

    #expect(enabled.isSuperset(of: [
        .newWorkspaceInCurrentDirectory, .renameWorkspace, .togglePinWorkspace,
        .closeWorkspace, .clearWorkspace, .splitRight, .splitDown, .closePane,
        .focusPane1, .jumpWorkspace1,
    ]))
    #expect(enabled.isDisjoint(with: [
        .acknowledgeWorkspace, .previousWorkspace, .nextWorkspace,
        .growActivePane, .shrinkActivePane, .previousPane, .nextPane,
        .focusPane2, .jumpWorkspace2, .reopenClosedWorkspace,
    ]))
}

@Test func commandAvailabilityTracksAttentionTraversalRecoveryAndSheets() {
    let waiting = PaneSnapshot(
        title: "Waiting", workingDirectory: "/tmp", agentState: .needsAttention
    )
    let secondPane = PaneSnapshot(title: "Second", workingDirectory: "/tmp")
    let firstWorkspace = WorkspaceSnapshot(
        name: "One", focusedPaneID: waiting.id,
        layout: .split(
            axis: .horizontal, fraction: 0.5,
            first: .pane(waiting), second: .pane(secondPane)
        )
    )
    let otherPane = PaneSnapshot(title: "Other", workingDirectory: "/tmp")
    let secondWorkspace = WorkspaceSnapshot(
        name: "Two", focusedPaneID: otherPane.id, layout: .pane(otherPane)
    )
    let snapshot = SessionSnapshot(
        selectedWorkspaceID: firstWorkspace.id,
        groups: [WorkspaceGroupSnapshot(
            name: "Local", workspaces: [firstWorkspace, secondWorkspace]
        )],
        attentionWorkspaceIDs: [firstWorkspace.id],
        recentlyClosedWorkspaces: [
            RecentlyClosedWorkspaceRecord(workspaceID: UUID(), closedAt: Date()),
        ]
    )
    let enabled = CommandAvailabilityProjection.enabledCommandIDs(
        snapshot: snapshot, isSheetPresented: false
    )

    #expect(enabled.isSuperset(of: [
        .acknowledgeWorkspace, .previousWorkspace, .nextWorkspace,
        .growActivePane, .shrinkActivePane, .previousPane, .nextPane,
        .focusPane2, .jumpWorkspace2, .reopenClosedWorkspace,
    ]))

    let sheetEnabled = CommandAvailabilityProjection.enabledCommandIDs(
        snapshot: snapshot, isSheetPresented: true
    )
    #expect(sheetEnabled.isDisjoint(with: [
        .newWorkspaceGroup, .renameWorkspace, .togglePinWorkspace,
        .closeWorkspace, .clearWorkspace, .closePane, .commandPalette,
        .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility,
        .jumpWorkspace1, .jumpWorkspace2,
    ]))
    #expect(sheetEnabled.isSuperset(of: [
        .newWorkspace, .newWorkspaceInCurrentDirectory,
        .acknowledgeWorkspace, .reopenClosedWorkspace,
        .splitRight, .splitDown, .growActivePane, .focusPane2,
        .previousWorkspace, .nextWorkspace,
    ]))
}

@Test func commandAvailabilityTreatsUnansweredTurnAsAcknowledgable() {
    let pane = PaneSnapshot(title: "Waiting", workingDirectory: "/tmp")
    let workspace = WorkspaceSnapshot(
        name: "One", focusedPaneID: pane.id, layout: .pane(pane)
    )
    let snapshot = SessionSnapshot(
        selectedWorkspaceID: workspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace])],
        unansweredTurnPaneIDs: [pane.id]
    )

    #expect(CommandAvailabilityProjection.canAcknowledgeWorkspace(
        workspace.id, in: snapshot
    ))
    #expect(CommandAvailabilityProjection.enabledCommandIDs(
        snapshot: snapshot, isSheetPresented: false
    ).contains(.acknowledgeWorkspace))
}
