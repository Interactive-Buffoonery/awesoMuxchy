import Foundation
import Testing
@testable import AwesoMuxCore

@Test func commandPaletteGeometryUsesPreferredSizeAndCentersInLargeParent() {
    #expect(
        CommandPaletteGeometry.fit(parentWidth: 1440, parentHeight: 852)
            == CommandPaletteGeometry(
                width: 520, height: 420, anchorX: 720, anchorY: 216
            )
    )
}

@Test func commandPaletteGeometryFitsWithinNarrowParentInsets() {
    #expect(
        CommandPaletteGeometry.fit(parentWidth: 360, parentHeight: 300)
            == CommandPaletteGeometry(
                width: 328, height: 268, anchorX: 180, anchorY: 16
            )
    )
    #expect(
        CommandPaletteGeometry.fit(parentWidth: 20, parentHeight: 20)
            == CommandPaletteGeometry(
                width: 1, height: 1, anchorX: 10, anchorY: 9
            )
    )
}

@Test func commandPaletteUnifiesWorkspacesAndSuggestedActionsWithoutImplicitSubmission() throws {
    let first = paletteWorkspace(name: "API Server", directory: "/srv/api")
    let second = paletteWorkspace(name: "Docs", directory: "/srv/docs")
    let snapshot = SessionSnapshot(
        selectedWorkspaceID: first.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [first, second])]
    )
    let output = CommandPaletteProjection.project(
        snapshot: snapshot,
        commands: CommandCatalog.definitions,
        enabledCommandIDs: [.newWorkspace, .newWorkspaceInCurrentDirectory],
        rawQuery: "",
        homeDirectory: "/home/test"
    )

    #expect(output.mode == .unified)
    #expect(output.sections.map(\.title) == ["Workspaces", "Suggested"])
    #expect(output.sections[0].items.map(\.target) == [
        .workspace(first.id), .workspace(second.id),
    ])
    #expect(output.sections[1].items.map(\.target) == [
        .command(.newWorkspace), .command(.newWorkspaceInCurrentDirectory),
    ])
    #expect(output.defaultSelectionIndex == nil)
}

@Test func commandPaletteFuzzySearchUsesWorkspaceTitlePathGroupAndStableScores() throws {
    let titleMatch = paletteWorkspace(name: "Deployment Console", directory: "/srv/tools")
    let pathMatch = paletteWorkspace(name: "Console", directory: "/srv/deployment")
    let groupMatch = paletteWorkspace(name: "Logs", directory: "/srv/logs")
    let snapshot = SessionSnapshot(groups: [
        WorkspaceGroupSnapshot(name: "Local", workspaces: [pathMatch, titleMatch]),
        WorkspaceGroupSnapshot(name: "Deployment", workspaces: [groupMatch]),
    ])
    let output = CommandPaletteProjection.project(
        snapshot: snapshot,
        commands: CommandCatalog.definitions,
        enabledCommandIDs: [.splitDown],
        rawQuery: "deploy",
        homeDirectory: "/home/test"
    )

    #expect(output.sections.first?.title == "Workspaces")
    #expect(Set(output.sections.first?.items.map(\.target) ?? []) == Set([
        .workspace(titleMatch.id), .workspace(pathMatch.id), .workspace(groupMatch.id),
    ]))
    #expect(output.defaultSelectionIndex == 0)
}

@Test func commandPaletteActionsOnlyOmitsWorkspacesAndDisabledCommands() throws {
    let workspace = paletteWorkspace(name: "Split Right Notes", directory: "/tmp")
    let output = CommandPaletteProjection.project(
        snapshot: SessionSnapshot(groups: [
            WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace]),
        ]),
        commands: CommandCatalog.definitions,
        enabledCommandIDs: [.splitRight, .newWorkspace],
        rawQuery: "> split"
    )

    #expect(output.mode == .actionsOnly)
    #expect(output.query == "split")
    #expect(output.sections.map(\.title) == ["Actions"])
    #expect(output.items.map(\.target) == [.command(.splitRight)])
    #expect(output.defaultSelectionIndex == 0)
}

@Test func commandPaletteRejectsSoftClosedAndOversizedQueries() throws {
    var closed = paletteWorkspace(name: "Closed", directory: "/tmp/closed")
    closed.isSoftClosed = true
    let output = CommandPaletteProjection.project(
        snapshot: SessionSnapshot(groups: [
            WorkspaceGroupSnapshot(name: "Local", workspaces: [closed]),
        ]),
        commands: CommandCatalog.definitions,
        enabledCommandIDs: [.newWorkspace],
        rawQuery: String(repeating: "x", count: SidebarFuzzyMatcher.maximumQueryLength + 1)
    )

    #expect(output.sections.isEmpty)
    #expect(output.defaultSelectionIndex == nil)
}

@Test func commandPaletteSelectionStartsAtTheDirectionalEdgeAndClamps() {
    #expect(CommandPaletteSelectionPolicy.destination(current: nil, count: 3, delta: 1) == 0)
    #expect(CommandPaletteSelectionPolicy.destination(current: nil, count: 3, delta: -1) == 2)
    #expect(CommandPaletteSelectionPolicy.destination(current: 0, count: 3, delta: -1) == 0)
    #expect(CommandPaletteSelectionPolicy.destination(current: 2, count: 3, delta: 1) == 2)
    #expect(CommandPaletteSelectionPolicy.destination(current: nil, count: 0, delta: 1) == nil)
}

private func paletteWorkspace(name: String, directory: String) -> WorkspaceSnapshot {
    let pane = PaneSnapshot(title: name, workingDirectory: directory)
    return WorkspaceSnapshot(name: name, focusedPaneID: pane.id, layout: .pane(pane))
}
