import Foundation
import Testing
@testable import AwesoMuxCore

private func workspace(panes: Int) -> WorkspaceSnapshot {
    let first = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    var layout = PaneLayout.pane(first)
    for index in 1..<panes {
        let pane = PaneSnapshot(title: "shell \(index + 1)", workingDirectory: "/tmp")
        layout = .split(axis: .horizontal, fraction: 0.5, first: layout, second: .pane(pane))
    }
    return WorkspaceSnapshot(name: "Workspace", focusedPaneID: first.id, layout: layout)
}

private func snapshot(_ workspaces: [WorkspaceSnapshot]) -> SessionSnapshot {
    SessionSnapshot(
        selectedWorkspaceID: workspaces.first?.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: workspaces)]
    )
}

@Test func primaryCloseClosesFocusedPaneWhenSplit() {
    let value = workspace(panes: 2)
    #expect(ClosePolicy.primaryClose(workspace: value, visibleWorkspaceCount: 1) == .closePane(value.focusedPaneID))
}

@Test func primaryCloseSoftClosesLastPaneWhenOtherWorkspacesExist() {
    let value = workspace(panes: 1)
    #expect(ClosePolicy.primaryClose(workspace: value, visibleWorkspaceCount: 2) == .softCloseWorkspace(value.id))
}

@Test func primaryCloseClosesWindowAtLastPaneOfLastWorkspace() {
    let value = workspace(panes: 1)
    #expect(ClosePolicy.primaryClose(workspace: value, visibleWorkspaceCount: 1) == .closeWindow)
}

@Test func snapshotRoundTripsOneHundredTimes() throws {
    let first = workspace(panes: 2)
    let expected = snapshot([first])
    var roundTripped = expected
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    for _ in 0..<100 {
        roundTripped = try decoder.decode(
            SessionSnapshot.self,
            from: encoder.encode(roundTripped)
        ).validated()
    }
    #expect(roundTripped == expected)
}

@Test func rejectsMissingFocusedPane() {
    let pane = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    let broken = WorkspaceSnapshot(name: "Broken", focusedPaneID: UUID(), layout: .pane(pane))
    #expect(throws: SessionValidationError.missingFocusedPane(broken.id)) {
        try snapshot([broken]).validated()
    }
}

@Test func storeUsesOwnerOnlyPermissions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("state/session.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let value = workspace(panes: 1)
    try store.save(snapshot([value]))
    let attributes = try FileManager.default.attributesOfItem(atPath: store.snapshotURL.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func rejectsDuplicateGroupIDs() {
    let id = UUID()
    let first = WorkspaceGroupSnapshot(id: id, name: "One", workspaces: [])
    let second = WorkspaceGroupSnapshot(id: id, name: "Two", workspaces: [])
    #expect(throws: SessionValidationError.duplicateGroupID) {
        try SessionSnapshot(groups: [first, second]).validated()
    }
}

@Test func splitFocusAndCloseMutateOneWorkspace() throws {
    let initial = workspace(panes: 1)
    var value = snapshot([initial])
    let newPane = PaneSnapshot(title: "review", workingDirectory: "/tmp")

    try value.splitFocusedPane(
        in: initial.id,
        axis: .horizontal,
        newPane: newPane
    )
    #expect(value.workspaces[0].layout.paneIDs == [initial.focusedPaneID, newPane.id])
    #expect(value.workspaces[0].focusedPaneID == newPane.id)

    let decision = try value.closeFocusedPane(in: initial.id)
    #expect(decision == .closePane(newPane.id))
    #expect(value.workspaces[0].layout.paneIDs == [initial.focusedPaneID])
    #expect(value.workspaces[0].focusedPaneID == initial.focusedPaneID)
}

@Test func selectingWorkspaceRejectsSoftClosedTarget() {
    var closed = workspace(panes: 1)
    closed.isSoftClosed = true
    var value = snapshot([closed])
    #expect(throws: SessionMutationError.workspaceNotFound(closed.id)) {
        try value.selectWorkspace(closed.id)
    }
}

@Test func commandCatalogHasUniqueIDsAndChords() {
    let definitions = CommandCatalog.definitions
    #expect(Set(definitions.map(\.id)).count == definitions.count)
    let chords = definitions.compactMap(\.defaultChord)
    #expect(Set(chords).count == chords.count)
    #expect(CommandCatalog.definition(for: .splitRight).action == "Split Right")
    #expect(CommandCatalog.definition(for: .newWorkspaceGroup).action == "New Workspace Group…")
    #expect(CommandCatalog.definition(for: .focusSidebar) == CommandDefinition(
        id: .focusSidebar,
        action: "Focus Sidebar",
        section: .view,
        defaultChord: KeyChord(key: "s", modifiers: [.control, .superKey])
    ))
    #expect(CommandCatalog.definition(for: .toggleSidebarWidth).action == "Collapse/Expand Sidebar")
    #expect(CommandCatalog.definition(for: .toggleSidebarVisibility).action == "Hide/Show Sidebar")
}

@Test func relativeWorkspaceAndPaneNavigationWraps() throws {
    let first = workspace(panes: 2)
    let second = workspace(panes: 1)
    var value = snapshot([first, second])

    try value.selectRelativeWorkspace(offset: -1)
    #expect(value.selectedWorkspaceID == second.id)
    try value.selectRelativeWorkspace(offset: 1)
    #expect(value.selectedWorkspaceID == first.id)

    try value.focusRelativePane(offset: -1, in: first.id)
    #expect(value.workspace(id: first.id)?.focusedPaneID == first.layout.paneIDs.last)
}

@Test func workspaceOrderingStaysInsideOwningGroup() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    var value = snapshot([first, second])
    try value.moveWorkspace(first.id, offset: 1)
    #expect(value.groups[0].workspaces.map(\.id) == [second.id, first.id])
    try value.moveWorkspace(first.id, offset: 20)
    #expect(value.groups[0].workspaces.map(\.id) == [second.id, first.id])
}

@Test func groupMutationsPreserveIdentityOrderSelectionAndSafeNames() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    var value = SessionSnapshot(
        selectedWorkspaceID: first.id,
        groups: [
            WorkspaceGroupSnapshot(name: "Alpha", workspaces: [first, second]),
            WorkspaceGroupSnapshot(name: "Beta", workspaces: [])
        ]
    )
    let betaID = value.groups[1].id
    let gammaID = try value.addGroup(named: "  Gamma\u{202E}  ", color: .teal)
    #expect(value.groups.last?.id == gammaID)
    #expect(value.groups.last?.name == "Gamma")
    #expect(value.groups.last?.color == .teal)
    #expect(throws: SessionMutationError.duplicateGroupName) { try value.addGroup(named: "gÁmma") }
    #expect(throws: SessionMutationError.invalidGroupName) { try value.addGroup(named: "\n\t") }
    #expect(throws: SessionMutationError.suspiciousGroupName) { try value.addGroup(named: "Lοcal") }

    try value.renameGroup(betaID, to: "Delivery")
    try value.setGroupColor(betaID, color: .mauve)
    try value.moveGroup(gammaID, offset: -2)
    #expect(value.groups.map(\.id) == [gammaID, value.groups[1].id, betaID])
    #expect(value.groups.last?.name == "Delivery")
    #expect(value.groups.last?.color == .mauve)

    try value.moveWorkspace(first.id, toGroup: betaID, at: 0)
    #expect(value.groups.last?.workspaces.map(\.id) == [first.id])
    #expect(value.selectedWorkspaceID == first.id)
    let removed = try value.closeGroup(betaID)
    #expect(removed == [first.id])
    #expect(value.selectedWorkspaceID == second.id)
    #expect(!value.groups.contains(where: { $0.id == betaID }))
}

@Test func movingWorkspaceUsesPostRemovalIndicesAndClampsAtGroupEdges() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    let third = workspace(panes: 1)
    let destination = WorkspaceGroupSnapshot(name: "Destination", workspaces: [])
    var value = SessionSnapshot(
        selectedWorkspaceID: second.id,
        groups: [WorkspaceGroupSnapshot(name: "Source", workspaces: [first, second, third]), destination]
    )
    try value.moveWorkspace(first.id, toGroup: value.groups[0].id, at: 99)
    #expect(value.groups[0].workspaces.map(\.id) == [second.id, third.id, first.id])
    try value.moveWorkspace(third.id, toGroup: destination.id, at: -4)
    #expect(value.groups[0].workspaces.map(\.id) == [second.id, first.id])
    #expect(value.groups[1].workspaces.map(\.id) == [third.id])
}

@Test func profilePathsRejectTraversalAndUseXDGStateHome() throws {
    #expect(throws: SessionProfileError.invalidProfileName) {
        try SessionProfilePaths(profile: "../other")
    }
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let paths = try SessionProfilePaths(
        profile: "default",
        environment: ["XDG_STATE_HOME": root.path],
        homeDirectory: URL(fileURLWithPath: "/unused")
    )
    #expect(paths.snapshotURL.path.hasSuffix("awesomux/profiles/default/session.json"))
}

@Test func corruptCurrentSnapshotRecoversPreviousAndQuarantines() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        previousSnapshotURL: root.appendingPathComponent("session.previous.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let first = snapshot([workspace(panes: 1)])
    let second = snapshot([workspace(panes: 2)])
    try store.save(first)
    try store.save(second)
    try Data("not-json".utf8).write(to: store.snapshotURL, options: .atomic)

    #expect(try store.loadRecovering() == .recoveredPrevious(first))
    let quarantined = try FileManager.default.contentsOfDirectory(
        at: store.quarantineDirectoryURL,
        includingPropertiesForKeys: nil
    )
    #expect(quarantined.count == 1)
    let attributes = try FileManager.default.attributesOfItem(atPath: quarantined[0].path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func invalidCurrentAndPreviousResetAfterQuarantine() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        previousSnapshotURL: root.appendingPathComponent("session.previous.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    try Data("bad-current".utf8).write(to: store.snapshotURL)
    try Data("bad-previous".utf8).write(to: store.previousSnapshotURL)
    #expect(try store.loadRecovering() == .resetAfterQuarantine)
    #expect(try FileManager.default.contentsOfDirectory(
        at: store.quarantineDirectoryURL,
        includingPropertiesForKeys: nil
    ).count == 2)
}

@Test func oversizedSnapshotIsQuarantinedWithoutDecoding() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let oversized = Data(repeating: 0x20, count: SessionStore.maximumSnapshotBytes + 1)
    try oversized.write(to: store.snapshotURL)
    #expect(try store.loadRecovering() == .resetAfterQuarantine)
    #expect(!FileManager.default.fileExists(atPath: store.snapshotURL.path))
    #expect(try FileManager.default.contentsOfDirectory(
        at: store.quarantineDirectoryURL,
        includingPropertiesForKeys: nil
    ).count == 1)
}

@Test func rejectsUnsafeSplitFractionAndSelectedClosedWorkspace() {
    let pane = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    let second = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    let invalidLayout = PaneLayout.split(
        axis: .horizontal,
        fraction: .infinity,
        first: .pane(pane),
        second: .pane(second)
    )
    let invalidWorkspace = WorkspaceSnapshot(
        name: "Invalid",
        focusedPaneID: pane.id,
        layout: invalidLayout
    )
    #expect(throws: SessionValidationError.invalidSplitFraction) {
        try snapshot([invalidWorkspace]).validated()
    }

    var closed = workspace(panes: 1)
    closed.isSoftClosed = true
    #expect(throws: SessionValidationError.missingSelectedWorkspace) {
        try snapshot([closed]).validated()
    }
}

@Test func addingWorkspaceSelectsItInsideRequestedGroup() throws {
    let initial = workspace(panes: 1)
    var value = snapshot([initial])
    let pane = PaneSnapshot(title: "new", workingDirectory: "/tmp")
    let added = WorkspaceSnapshot(
        name: "Untitled Workspace",
        focusedPaneID: pane.id,
        layout: .pane(pane)
    )
    try value.addWorkspace(added, toGroup: value.groups[0].id)
    #expect(value.groups[0].workspaces.map(\.id) == [initial.id, added.id])
    #expect(value.selectedWorkspaceID == added.id)
    #expect(try value.validated() == value)
}

@Test func groupDisclosureDoesNotChangeSelection() throws {
    let selected = workspace(panes: 1)
    var value = snapshot([selected])
    let groupID = value.groups[0].id
    try value.toggleGroupDisclosure(groupID)
    #expect(value.groups[0].isCollapsed)
    #expect(value.selectedWorkspaceID == selected.id)
}

@Test func sidebarProjectionKeepsFixedChromeAcrossWorkspaceCounts() {
    for count in [0, 1, 40] {
        let items = (0..<count).map { _ in workspace(panes: 1) }
        let projection = SidebarChromeProjection(snapshot: snapshot(items))
        #expect(SidebarChromeProjection.width == 296)
        #expect(SidebarChromeProjection.headerMinimumHeight == 48)
        #expect(SidebarChromeProjection.footerMinimumHeight == 38)
        #expect(projection.groups[0].rows.count == count)
    }
}

@Test func sidebarAutomaticTintCycleReservesMauveAndPeach() {
    let groups = (0..<9).map { WorkspaceGroupSnapshot(name: "Group \($0)", workspaces: []) }
    let snapshot = SessionSnapshot(groups: groups)
    let colors = SidebarChromeProjection(snapshot: snapshot).groups.compactMap(\.color)
    #expect(colors == [.teal, .green, .blue, .pink, .yellow, .red, .gray, .teal, .green])
    #expect(!colors.contains(.mauve))
    #expect(!colors.contains(.peach))
    let special = WorkspaceGroupSnapshot(name: "awesoMux", workspaces: [])
    #expect(SidebarTintProjection.resolvedColor(for: special, unfilteredIndex: 3) == .mauve)
    let explicit = WorkspaceGroupSnapshot(name: "Explicit", color: .peach, workspaces: [])
    #expect(SidebarTintProjection.resolvedColor(for: explicit, unfilteredIndex: 0) == .peach)
}

@Test func sidebarWidthPolicyMatchesReferenceModesAndRestoration() {
    #expect(SidebarWidthPolicy.committedWidth(for: 296) == 296)
    #expect(SidebarWidthPolicy.committedWidth(for: 249.9) == 60)
    #expect(SidebarWidthPolicy.committedWidth(for: 800) == 800)
    #expect(SidebarWidthPolicy.committedWidth(for: .nan) == 296)
    #expect(SidebarWidthPolicy.committedWidth(for: .greatestFiniteMagnitude) == Int(Int32.max))
    #expect(SidebarWidthPolicy.constrainedLiveWidth(for: 900, maximumWidth: 640) == 640)
    #expect(SidebarWidthPolicy.constrainedLiveWidth(for: 220, maximumWidth: 640) == 60)
    #expect(SidebarWidthPolicy.mode(for: 250) == .expanded)
    #expect(SidebarWidthPolicy.mode(for: 249) == .collapsed)
    #expect(SidebarWidthPolicy.shouldRestoreExpanded(currentWidth: 60, maximumWidth: 300, userChoseRail: false))
    #expect(!SidebarWidthPolicy.shouldRestoreExpanded(currentWidth: 60, maximumWidth: 300, userChoseRail: true))
    #expect(SidebarWidthPolicy.toggleWidth(currentWidth: 296, lastNonCollapsedWidth: 420) == 60)
    #expect(SidebarWidthPolicy.toggleWidth(currentWidth: 60, lastNonCollapsedWidth: 420) == 420)
    #expect(SidebarWidthPolicy.updatedLastNonCollapsedWidth(currentWidth: 60, previousLastNonCollapsedWidth: 420) == 420)
}

@Test func appPreferencesDecodeLegacyAndNormalizeUnsafeSidebarWidths() throws {
    let legacy = Data(#"{"theme":"Dark","notificationsMuted":true}"#.utf8)
    let decoded = try JSONDecoder().decode(AppPreferences.self, from: legacy)
    #expect(decoded.theme == .dark)
    #expect(decoded.notificationsMuted)
    #expect(decoded.sidebarWidth == 296)
    #expect(decoded.lastExpandedSidebarWidth == 296)
    #expect(decoded.sidebarPosition == .left)
    #expect(decoded.sidebarDensity == .standard)

    let normalized = AppPreferences(sidebarWidth: 200, lastExpandedSidebarWidth: 60)
    #expect(normalized.sidebarWidth == 60)
    #expect(normalized.lastExpandedSidebarWidth == 296)
}

@Test func sidebarSearchProjectionUsesTitlesLocationsAgentsAndStatesInStableOrder() {
    let firstPane = PaneSnapshot(
        title: "Build logs",
        workingDirectory: "/work/Café",
        agent: "Codex",
        agentState: .thinking
    )
    let first = WorkspaceSnapshot(name: "Frontend", focusedPaneID: firstPane.id, layout: .pane(firstPane))
    let secondPane = PaneSnapshot(
        title: "Deploy",
        workingDirectory: "/srv/production",
        agent: "Claude Code",
        agentState: .needsAttention,
        ownership: .remoteZmx
    )
    let second = WorkspaceSnapshot(name: "Operations", focusedPaneID: secondPane.id, layout: .pane(secondPane))
    let value = SessionSnapshot(
        selectedWorkspaceID: first.id,
        groups: [WorkspaceGroupSnapshot(name: "Product", workspaces: [first, second])]
    )

    for query in ["frontend", "build logs", "cafe", "codex", "thinking", "local"] {
        let output = SidebarSearchProjection.project(snapshot: value, query: query, homeDirectory: "/home/test")
        #expect(output.orderedWorkspaceIDs == [first.id])
        #expect(output.topMatchID == first.id)
        #expect(output.isFiltering)
    }
    for query in ["operations", "production", "claude", "needs input", "remote", "ssh"] {
        let output = SidebarSearchProjection.project(snapshot: value, query: query, homeDirectory: "/home/test")
        #expect(output.orderedWorkspaceIDs == [second.id])
    }
    let groupMatch = SidebarSearchProjection.project(snapshot: value, query: "product")
    #expect(groupMatch.orderedWorkspaceIDs == [first.id, second.id])
}

@Test func sidebarSearchTreatsWhitespaceAsInactiveAndReportsNoMatches() {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    let value = snapshot([first, second])
    let inactive = SidebarSearchProjection.project(snapshot: value, query: " \n\t ")
    #expect(!inactive.isFiltering)
    #expect(inactive.topMatchID == nil)
    #expect(inactive.orderedWorkspaceIDs == [first.id, second.id])

    let missing = SidebarSearchProjection.project(snapshot: value, query: "definitely absent")
    #expect(missing.isFiltering)
    #expect(!missing.hasMatches)
    #expect(missing.groups.isEmpty)
    #expect(missing.topMatchID == nil)
}

@Test func sidebarSearchPublishesSafeUTF8MatchRangesForVisibleText() {
    let pane = PaneSnapshot(title: "Shell", workingDirectory: "/work/Café")
    let workspace = WorkspaceSnapshot(name: "Résumé Review", focusedPaneID: pane.id, layout: .pane(pane))
    let value = SessionSnapshot(groups: [WorkspaceGroupSnapshot(name: "Product", workspaces: [workspace])])

    let title = SidebarSearchProjection.project(snapshot: value, query: "resume", homeDirectory: "/home/test")
        .groups.first?.rows.first
    #expect(title?.titleMatch == 0..<8)
    #expect(title?.locationMatch == nil)

    let location = SidebarSearchProjection.project(snapshot: value, query: "cafe", homeDirectory: "/home/test")
        .groups.first?.rows.first
    #expect(location?.titleMatch == nil)
    #expect(location?.locationMatch == 6..<11)

    let hiddenToken = SidebarSearchProjection.project(snapshot: value, query: "local", homeDirectory: "/home/test")
        .groups.first?.rows.first
    #expect(hiddenToken?.titleMatch == nil)
    #expect(hiddenToken?.locationMatch == nil)
}

@Test func emptyWorkspacePresentationTracksGroupsFilteringAndRecovery() {
    let empty = SessionSnapshot()
    let initial = EmptyWorkspacePresentation.resolve(snapshot: empty, isFiltering: false)
    #expect(initial.showsCollapsedSidebarAction)
    #expect(!initial.showsReopenAction)
    #expect(initial.visibleCopy == "Create a workspace with Ctrl+Super+N.")
    #expect(!EmptyWorkspacePresentation.resolve(snapshot: empty, isFiltering: true).showsCollapsedSidebarAction)

    let live = snapshot([workspace(panes: 1)])
    #expect(!EmptyWorkspacePresentation.resolve(snapshot: live, isFiltering: false).showsCollapsedSidebarAction)

    var recovered = SessionSnapshot()
    recovered.recentlyClosedWorkspaces = [RecentlyClosedWorkspaceRecord(workspaceID: UUID(), closedAt: Date())]
    let reopen = EmptyWorkspacePresentation.resolve(snapshot: recovered, isFiltering: false)
    #expect(reopen.showsReopenAction)
    #expect(reopen.visibleCopy.contains("reopen the last one you closed"))
}

@Test func workspaceMoveAvailabilityNamesAdjacentGroupsAndBoundsActions() {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    let third = workspace(panes: 1)
    let value = SessionSnapshot(groups: [
        WorkspaceGroupSnapshot(name: "Alpha", workspaces: [first, second]),
        WorkspaceGroupSnapshot(name: "Beta", workspaces: [third]),
    ])

    let top = WorkspaceMoveAvailability.resolve(snapshot: value, workspaceID: first.id)
    #expect(top?.canMoveUp == false)
    #expect(top?.canMoveDown == true)
    #expect(top?.previousGroup == nil)
    #expect(top?.nextGroup?.name == "Beta")

    let destination = WorkspaceMoveAvailability.resolve(snapshot: value, workspaceID: third.id)
    #expect(destination?.canMoveUp == false)
    #expect(destination?.canMoveDown == false)
    #expect(destination?.previousGroup?.name == "Alpha")
    #expect(destination?.nextGroup == nil)
    #expect(WorkspaceMoveAvailability.resolve(snapshot: value, workspaceID: UUID()) == nil)
}

@Test func liftedSidebarProjectionOrdersAttentionThenPinnedWithoutDuplicatingOrigins() {
    let attentionOnePane = PaneSnapshot(title: "Approve", workingDirectory: "/one", agent: "Codex", agentState: .needsAttention)
    let attentionTwoPane = PaneSnapshot(title: "Review", workingDirectory: "/two", agent: "Claude", agentState: .needsAttention)
    let quietPane = PaneSnapshot(title: "Shell", workingDirectory: "/quiet")
    let attentionOne = WorkspaceSnapshot(name: "First attention", focusedPaneID: attentionOnePane.id, layout: .pane(attentionOnePane))
    let attentionTwo = WorkspaceSnapshot(name: "Second attention", focusedPaneID: attentionTwoPane.id, layout: .pane(attentionTwoPane))
    let quiet = WorkspaceSnapshot(name: "Pinned quiet", focusedPaneID: quietPane.id, layout: .pane(quietPane))
    var value = SessionSnapshot(
        selectedWorkspaceID: attentionOne.id,
        groups: [
            WorkspaceGroupSnapshot(name: "Alpha", workspaces: [attentionOne, quiet]),
            WorkspaceGroupSnapshot(name: "Beta", workspaces: [attentionTwo])
        ],
        pinnedWorkspaceIDs: [quiet.id, attentionOne.id],
        attentionWorkspaceIDs: [attentionTwo.id, attentionOne.id]
    )
    let output = SidebarLiftedProjection.project(snapshot: value, query: "")
    #expect(output.attention.map { $0.row.id } == [attentionTwo.id])
    #expect(output.pinned.map { $0.row.id } == [quiet.id, attentionOne.id])
    #expect(output.groups.flatMap { $0.rows.map(\.id) }.isEmpty)
    #expect(output.orderedWorkspaceIDs == [attentionTwo.id, quiet.id, attentionOne.id])
    #expect(output.topMatchID == nil)

    let filtered = SidebarLiftedProjection.project(snapshot: value, query: "approve")
    #expect(filtered.attention.isEmpty)
    #expect(filtered.pinned.map { $0.row.id } == [attentionOne.id])
    #expect(filtered.topMatchID == attentionOne.id)

    value.pinnedWorkspaceIDs.removeAll()
    value.attentionWorkspaceIDs = [attentionTwo.id]
    value.reconcileAttentionWorkspaceIDs()
    #expect(value.attentionWorkspaceIDs == [attentionTwo.id, attentionOne.id])
}

@Test func sidebarProjectionListsDecodeBackwardCompatiblyAndValidateIdentity() throws {
    let first = workspace(panes: 1)
    let legacy = SessionSnapshot(selectedWorkspaceID: first.id, groups: [
        WorkspaceGroupSnapshot(name: "Legacy", workspaces: [first])
    ])
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
    object.removeValue(forKey: "pinnedWorkspaceIDs")
    object.removeValue(forKey: "attentionWorkspaceIDs")
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.pinnedWorkspaceIDs.isEmpty)
    #expect(decoded.attentionWorkspaceIDs.isEmpty)

    let unknown = UUID()
    let invalid = SessionSnapshot(selectedWorkspaceID: first.id, groups: legacy.groups, pinnedWorkspaceIDs: [unknown])
    #expect(throws: SessionValidationError.invalidSidebarProjectionIDs) { try invalid.validated() }
}

@Test func pinnedWorkspaceReorderIsBoundedAndIdentityBased() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    let third = workspace(panes: 1)
    var value = snapshot([first, second, third])
    value.pinnedWorkspaceIDs = [first.id, second.id, third.id]

    try value.movePinnedWorkspace(second.id, offset: -1)
    #expect(value.pinnedWorkspaceIDs == [second.id, first.id, third.id])
    try value.movePinnedWorkspace(second.id, offset: -20)
    #expect(value.pinnedWorkspaceIDs == [second.id, first.id, third.id])
    try value.movePinnedWorkspace(first.id, offset: 20)
    #expect(value.pinnedWorkspaceIDs == [second.id, third.id, first.id])
    let unknown = UUID()
    #expect(throws: SessionMutationError.workspaceNotFound(unknown)) {
        try value.movePinnedWorkspace(unknown, offset: 1)
    }
}

@Test func workspaceRenameSanitizesTextAndPreservesDuplicateIdentity() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    var value = snapshot([first, second])
    try value.renameWorkspace(first.id, to: "  Shared\nName  ")
    try value.renameWorkspace(second.id, to: "SharedName")
    #expect(value.workspace(id: first.id)?.name == "SharedName")
    #expect(value.workspace(id: second.id)?.name == "SharedName")
    #expect(throws: SessionMutationError.invalidWorkspaceName) {
        try value.renameWorkspace(first.id, to: " \n ")
    }
}

@Test func workspaceAcknowledgementAndNotificationOverridesPersistIndependently() throws {
    let waitingPane = PaneSnapshot(title: "Approval", workingDirectory: "/tmp", agentState: .needsAttention)
    let quietPane = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let waiting = WorkspaceSnapshot(name: "Waiting", focusedPaneID: waitingPane.id, layout: .pane(waitingPane))
    let quiet = WorkspaceSnapshot(name: "Quiet", focusedPaneID: quietPane.id, layout: .pane(quietPane))
    var value = snapshot([waiting, quiet])
    value.reconcileAttentionWorkspaceIDs()
    #expect(value.attentionWorkspaceIDs == [waiting.id])

    try value.toggleWorkspaceNotificationsMuted(waiting.id)
    #expect(value.workspace(id: waiting.id)?.notificationsMuted == true)
    #expect(value.workspace(id: quiet.id)?.notificationsMuted == false)
    try value.acknowledgeWorkspace(waiting.id)
    #expect(value.workspace(id: waiting.id)?.acknowledgedAttentionPaneIDs == [waitingPane.id])
    #expect(value.attentionWorkspaceIDs.isEmpty)
    #expect(!SidebarPresentationPolicy.hasAttention(value))
    value.reconcileAttentionWorkspaceIDs()
    #expect(value.attentionWorkspaceIDs.isEmpty)

    let encoded = try JSONEncoder().encode(value)
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: encoded)
    #expect(decoded.workspace(id: waiting.id)?.notificationsMuted == true)
    #expect(decoded.workspace(id: waiting.id)?.acknowledgedAttentionPaneIDs == [waitingPane.id])

    var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    var groups = try #require(object["groups"] as? [[String: Any]])
    var workspaces = try #require(groups[0]["workspaces"] as? [[String: Any]])
    workspaces[0].removeValue(forKey: "notificationsMuted")
    workspaces[0].removeValue(forKey: "acknowledgedAttentionPaneIDs")
    groups[0]["workspaces"] = workspaces; object["groups"] = groups
    let legacy = try JSONDecoder().decode(SessionSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(legacy.workspace(id: waiting.id)?.notificationsMuted == false)
    #expect(legacy.workspace(id: waiting.id)?.acknowledgedAttentionPaneIDs.isEmpty == true)

    value.groups[0].workspaces[0].layout = .pane(PaneSnapshot(
        id: waitingPane.id, title: waitingPane.title, workingDirectory: waitingPane.workingDirectory
    ))
    value.reconcileAttentionWorkspaceIDs()
    #expect(value.workspace(id: waiting.id)?.acknowledgedAttentionPaneIDs.isEmpty == true)
}

@Test func paneAcknowledgementKeepsWorkspaceLiftedUntilEveryWaitingPaneIsRead() throws {
    let firstPane = PaneSnapshot(title: "First", workingDirectory: "/tmp", agentState: .needsAttention)
    let secondPane = PaneSnapshot(title: "Second", workingDirectory: "/tmp", agentState: .needsAttention)
    let workspace = WorkspaceSnapshot(name: "Two waits", focusedPaneID: firstPane.id, layout: .split(
        axis: .horizontal, fraction: 0.5, first: .pane(firstPane), second: .pane(secondPane)
    ))
    var value = snapshot([workspace])
    value.reconcileAttentionWorkspaceIDs()
    try value.acknowledgePane(firstPane.id, in: workspace.id)
    #expect(value.attentionWorkspaceIDs == [workspace.id])
    #expect(value.workspace(id: workspace.id)?.acknowledgedAttentionPaneIDs == [firstPane.id])
    try value.acknowledgePane(secondPane.id, in: workspace.id)
    #expect(value.attentionWorkspaceIDs.isEmpty)
    #expect(!SidebarPresentationPolicy.hasAttention(value))
}

@Test func attentionArrivalOrderIsStableAcrossGroupsAndRepeatSignals() throws {
    let firstPane = PaneSnapshot(title: "First", workingDirectory: "/tmp")
    let secondPane = PaneSnapshot(title: "Second", workingDirectory: "/tmp")
    let first = WorkspaceSnapshot(name: "First", focusedPaneID: firstPane.id, layout: .pane(firstPane))
    let second = WorkspaceSnapshot(name: "Second", focusedPaneID: secondPane.id, layout: .pane(secondPane))
    var value = SessionSnapshot(
        selectedWorkspaceID: first.id,
        groups: [
            WorkspaceGroupSnapshot(name: "Earlier group", workspaces: [first]),
            WorkspaceGroupSnapshot(name: "Later group", workspaces: [second])
        ]
    )

    try value.updatePaneAgentState(
        paneID: secondPane.id, workspaceID: second.id,
        state: .needsAttention, attentionReason: .bell
    )
    try value.updatePaneAgentState(
        paneID: firstPane.id, workspaceID: first.id,
        state: .needsAttention, attentionReason: .bell
    )
    #expect(value.attentionWorkspaceIDs == [second.id, first.id])

    try value.updatePaneAgentState(
        paneID: secondPane.id, workspaceID: second.id,
        state: .needsAttention, attentionReason: .bell
    )
    #expect(value.attentionWorkspaceIDs == [second.id, first.id])
}

@Test func passiveAttentionDwellKeepsSelectedWorkspaceStickyUntilNavigation() throws {
    let waitingPane = PaneSnapshot(
        title: "Waiting", workingDirectory: "/tmp", agentState: .needsAttention,
        attentionReason: .bell
    )
    let calmPane = PaneSnapshot(title: "Calm", workingDirectory: "/tmp")
    let waiting = WorkspaceSnapshot(
        name: "Waiting", focusedPaneID: waitingPane.id, layout: .pane(waitingPane)
    )
    let calm = WorkspaceSnapshot(name: "Calm", focusedPaneID: calmPane.id, layout: .pane(calmPane))
    var value = snapshot([calm, waiting])
    value.reconcileAttentionWorkspaceIDs()

    try value.selectWorkspace(waiting.id)
    #expect(value.attentionStickyWorkspaceID == waiting.id)
    #expect(try value.acknowledgePane(waitingPane.id, in: waiting.id, passively: true))
    #expect(value.workspace(id: waiting.id)?.acknowledgedAttentionPaneIDs == [waitingPane.id])
    #expect(value.attentionWorkspaceIDs == [waiting.id])

    try value.selectWorkspace(calm.id)
    #expect(value.attentionStickyWorkspaceID == nil)
    #expect(value.attentionWorkspaceIDs.isEmpty)
    let returned = SidebarLiftedProjection.project(snapshot: value, query: "")
    #expect(returned.attention.isEmpty)
    #expect(returned.groups.flatMap { $0.rows.map(\.id) }.contains(waiting.id))

    try value.selectWorkspace(waiting.id)
    #expect(value.attentionStickyWorkspaceID == nil)
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONEncoder().encode(value))
    #expect(decoded.attentionStickyWorkspaceID == nil)
}

@Test func passiveDwellDoesNotAcknowledgeBlockingPrompt() throws {
    let pane = PaneSnapshot(
        title: "Permission", workingDirectory: "/tmp", agentState: .needsAttention,
        attentionReason: .permissionPrompt
    )
    let workspace = WorkspaceSnapshot(name: "Blocked", focusedPaneID: pane.id, layout: .pane(pane))
    var value = snapshot([workspace])
    value.reconcileAttentionWorkspaceIDs()
    try value.selectWorkspace(workspace.id)

    #expect(try !value.acknowledgePane(pane.id, in: workspace.id, passively: true))
    #expect(value.workspace(id: workspace.id)?.acknowledgedAttentionPaneIDs.isEmpty == true)
    #expect(value.attentionWorkspaceIDs == [workspace.id])

    try value.acknowledgeWorkspace(workspace.id)
    #expect(value.attentionStickyWorkspaceID == nil)
    #expect(value.attentionWorkspaceIDs.isEmpty)
    #expect(SidebarLiftedProjection.project(snapshot: value, query: "").attention.isEmpty)
}

@Test func softCloseReopenAndClearPreserveExplicitRecoverySemantics() throws {
    let first = workspace(panes: 1)
    let second = workspace(panes: 1)
    var value = snapshot([first, second])
    value.pinnedWorkspaceIDs = [first.id]
    let now = Date(timeIntervalSince1970: 10_000)
    try value.softCloseWorkspace(first.id, now: now)
    #expect(value.workspace(id: first.id)?.isSoftClosed == true)
    #expect(value.recentlyClosedWorkspaces.map(\.workspaceID) == [first.id])
    #expect(value.pinnedWorkspaceIDs.isEmpty)
    #expect(value.selectedWorkspaceID == second.id)
    let reopened = try value.reopenMostRecentlyClosedWorkspace(now: now)
    #expect(reopened == first.id)
    #expect(value.workspace(id: first.id)?.isSoftClosed == false)
    #expect(value.selectedWorkspaceID == first.id)
    #expect(value.recentlyClosedWorkspaces.isEmpty)

    try value.softCloseWorkspace(first.id, now: now)
    let cleared = try value.clearWorkspace(first.id)
    #expect(cleared.id == first.id)
    #expect(value.workspace(id: first.id) == nil)
    #expect(value.recentlyClosedWorkspaces.isEmpty)
    #expect(throws: SessionMutationError.noSelectedWorkspace) {
        try value.reopenMostRecentlyClosedWorkspace()
    }
    try value.softCloseWorkspace(second.id, now: now)
    #expect(value.selectedWorkspaceID == nil)
    #expect(try value.reopenMostRecentlyClosedWorkspace(now: now) == second.id)
}

@Test func recentlyClosedWorkspacesDecodeLegacyRejectLiveEntriesAndExpire() throws {
    let first = workspace(panes: 1)
    let value = snapshot([first])
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any])
    object.removeValue(forKey: "recentlyClosedWorkspaces")
    let decoded = try JSONDecoder().decode(SessionSnapshot.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded.recentlyClosedWorkspaces.isEmpty)
    var invalid = value
    invalid.recentlyClosedWorkspaces = [.init(workspaceID: first.id, closedAt: Date())]
    #expect(throws: SessionValidationError.invalidRecentlyClosedWorkspaceIDs) { try invalid.validated() }

    let second = workspace(panes: 1)
    let now = Date(timeIntervalSince1970: 100_000)
    var expiring = snapshot([first, second])
    try expiring.softCloseWorkspace(first.id, now: now)
    #expect(throws: SessionMutationError.noSelectedWorkspace) {
        try expiring.reopenMostRecentlyClosedWorkspace(now: now.addingTimeInterval(24 * 60 * 60 + 1))
    }
    #expect(expiring.recentlyClosedWorkspaces.isEmpty)
    #expect(expiring.workspace(id: first.id) == nil)
}

@Test func sidebarPresentationPolicyMirrorsBothEdgesAndAttentionDiscovery() {
    #expect(SidebarPresentationPolicy.proximity(pointerX: 39, containerWidth: 1_000, position: .left) == .revealed)
    #expect(SidebarPresentationPolicy.proximity(pointerX: 961, containerWidth: 1_000, position: .right) == .revealed)
    #expect(SidebarPresentationPolicy.proximity(pointerX: 500, containerWidth: 1_000, position: .left) == .cue)
    #expect(SidebarPresentationPolicy.proximity(pointerX: .nan, containerWidth: 1_000, position: .left) == .dormant)
    #expect(SidebarPresentationPolicy.dividerCoordinate(sidebarWidth: 296, paneExtent: 1_440, position: .left) == 296)
    #expect(SidebarPresentationPolicy.dividerCoordinate(sidebarWidth: 296, paneExtent: 1_440, position: .right) == 1_144)
    #expect(SidebarPresentationPolicy.sidebarWidth(dividerCoordinate: 1_144, paneExtent: 1_440, position: .right) == 296)
    #expect(SidebarPresentationPolicy.edgeTabStyle(
        isPersistentlyHidden: true, proximity: .dormant, hasAttention: true
    ) == .attention)
    #expect(SidebarPresentationPolicy.edgeTabStyle(
        isPersistentlyHidden: true, proximity: .cue, hasAttention: false
    ) == .cue)
    #expect(SidebarPresentationPolicy.edgeTabStyle(
        isPersistentlyHidden: false, proximity: .dormant, hasAttention: true
    ) == nil)

    let quiet = PaneSnapshot(title: "Quiet", workingDirectory: "/tmp", agentState: .thinking)
    let attention = PaneSnapshot(title: "Waiting", workingDirectory: "/tmp", agentState: .needsAttention)
    #expect(!SidebarPresentationPolicy.hasAttention(snapshot([
        WorkspaceSnapshot(name: "Quiet", focusedPaneID: quiet.id, layout: .pane(quiet))
    ])))
    #expect(SidebarPresentationPolicy.hasAttention(snapshot([
        WorkspaceSnapshot(name: "Waiting", focusedPaneID: attention.id, layout: .pane(attention))
    ])))
}

@Test func sidebarSelectionAndLongNamesPreserveWorkspaceIdentity() {
    let pane = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    let longName = String(repeating: "workspace", count: 40)
    let selected = WorkspaceSnapshot(
        name: longName,
        focusedPaneID: pane.id,
        layout: .pane(pane)
    )
    let projection = SidebarChromeProjection(snapshot: snapshot([selected]))
    let row = projection.groups[0].rows[0]
    #expect(row.id == selected.id)
    #expect(row.isSelected)
    #expect(row.title.count <= 120)
    #expect(row.title.hasSuffix("…"))
}

@Test func focusedPaneContextRejectsStaleResults() {
    let workspaceID = UUID()
    let firstPaneID = UUID()
    let secondPaneID = UUID()
    var coordinator = FocusedPaneContextCoordinator()
    let first = coordinator.begin(workspaceID: workspaceID, paneID: firstPaneID)
    let stale = FocusedPaneContext.resolve(
        identity: first,
        workingDirectory: "/tmp/first",
        homeDirectory: "/home/test"
    )
    let second = coordinator.begin(workspaceID: workspaceID, paneID: secondPaneID)
    let acceptedStale = coordinator.publish(stale)
    #expect(!acceptedStale)
    #expect(coordinator.context == nil)

    let current = FocusedPaneContext.resolve(
        identity: second,
        workingDirectory: "/tmp/second",
        homeDirectory: "/home/test"
    )
    let acceptedCurrent = coordinator.publish(current)
    #expect(acceptedCurrent)
    #expect(coordinator.context?.identity.paneID == secondPaneID)
    #expect(coordinator.context?.path == "/tmp/second")
}

@Test func pathAndSidebarTextAreSanitizedWithoutChangingIdentity() {
    let identity = FocusedPaneIdentity(
        workspaceID: UUID(),
        paneID: UUID(),
        generation: 1
    )
    let context = FocusedPaneContext.resolve(
        identity: identity,
        workingDirectory: "/home/test/project\u{202E}\nname",
        homeDirectory: "/home/test"
    )
    #expect(context.identity == identity)
    #expect(!context.path.contains("\u{202E}"))
    #expect(!context.path.contains("\n"))
}

@Test func collapsedGroupAttentionPrioritizesActionableStatesAndExcludesOutput() {
    let needs = PaneSnapshot(title: "Needs", workingDirectory: "/tmp", agentState: .needsAttention)
    let error = PaneSnapshot(title: "Error", workingDirectory: "/tmp", agentState: .error)
    let thinking = PaneSnapshot(title: "Thinking", workingDirectory: "/tmp", agentState: .thinking)
    let output = PaneSnapshot(title: "Output", workingDirectory: "/tmp", agentState: .output)
    let group = WorkspaceGroupSnapshot(name: "Agents", workspaces: [
        WorkspaceSnapshot(name: "Needs", focusedPaneID: needs.id, layout: .pane(needs)),
        WorkspaceSnapshot(name: "Error", focusedPaneID: error.id, layout: .pane(error)),
        WorkspaceSnapshot(name: "Thinking", focusedPaneID: thinking.id, layout: .pane(thinking)),
        WorkspaceSnapshot(name: "Output", focusedPaneID: output.id, layout: .pane(output)),
    ])
    let summary = CollapsedGroupAttention.resolve(group: group)
    #expect(summary.needsAttention == 1)
    #expect(summary.errors == 1)
    #expect(summary.thinking == 1)
    #expect(summary.primaryState == .needsAttention)
    #expect(summary.accessibilityPhrase == "1 need input, 1 error, 1 thinking")
}

@Test func livePanePresentationDrivesUneditedWorkspaceTitleAndSanitizesIdentityScopedUpdates() throws {
    let pane = PaneSnapshot(title: "Primary terminal", workingDirectory: "/tmp")
    let dynamic = WorkspaceSnapshot(
        name: "Untitled Workspace", isNameUserEdited: false,
        focusedPaneID: pane.id, layout: .pane(pane)
    )
    var value = snapshot([dynamic])

    try value.updatePanePresentation(
        paneID: pane.id,
        workspaceID: dynamic.id,
        title: "build\u{202E}\nready",
        workingDirectory: "/tmp/project\n"
    )
    let updated = try #require(value.workspace(id: dynamic.id))
    #expect(updated.layout.pane(id: pane.id)?.title == "buildready")
    #expect(updated.layout.pane(id: pane.id)?.workingDirectory == "/tmp/project")
    #expect(SidebarWorkspaceTitle.resolve(workspace: updated) == "buildready")

    try value.renameWorkspace(dynamic.id, to: "Pinned Name")
    let renamed = try #require(value.workspace(id: dynamic.id))
    #expect(renamed.isNameUserEdited)
    #expect(SidebarWorkspaceTitle.resolve(workspace: renamed) == "Pinned Name")
    let stalePaneID = UUID()
    #expect(throws: SessionMutationError.paneNotFound(stalePaneID)) {
        try value.updatePanePresentation(
            paneID: stalePaneID, workspaceID: dynamic.id, title: "stale"
        )
    }
}

@Test func panePeekProjectionPreservesLayoutOrderActiveIdentityAndAccessibleState() {
    let first = PaneSnapshot(
        title: "Build\nPane", workingDirectory: "/home/test/project",
        agent: "Codex", agentState: .thinking
    )
    let second = PaneSnapshot(
        title: "Review", workingDirectory: "/home/test/project/review",
        agentState: .needsAttention
    )
    let workspace = WorkspaceSnapshot(
        name: "Work", focusedPaneID: second.id,
        layout: .split(axis: .horizontal, fraction: 0.5, first: .pane(first), second: .pane(second))
    )
    let items = SidebarPanePeekItem.project(workspace: workspace, homeDirectory: "/home/test")
    #expect(items.map(\.id) == [first.id, second.id])
    #expect(items.map(\.paneNumber) == [1, 2])
    #expect(items[0].title == "BuildPane")
    #expect(items[0].location == "~/project")
    #expect(items[0].accessibilityLabel == "Jump to pane 1, BuildPane, Codex, Thinking")
    #expect(items[1].isActive)
    #expect(items[1].accessibilityLabel == "Jump to pane 2, Review, Shell, Needs Attention, active pane")

    let remote = PaneSnapshot(
        title: "Deploy", workingDirectory: "/srv/app", agent: "Claude",
        agentState: .running, ownership: .remoteZmx
    )
    let remoteWorkspace = WorkspaceSnapshot(
        name: "Remote", focusedPaneID: remote.id, layout: .pane(remote)
    )
    let remoteItem = SidebarPanePeekItem.project(workspace: remoteWorkspace)[0]
    #expect(remoteItem.accessibilityLabel == "Jump to pane 1, Deploy, Claude, Running, remote, active pane")
}

@Test func sidebarAgentTileUsesProviderShapeAndHighestPriorityPaneState() {
    #expect(SidebarAgentTilePresentation.project(agent: "Claude Code", state: .thinking).kind == .claude)
    #expect(SidebarAgentTilePresentation.project(agent: "Codex", state: .running).kind == .codex)
    #expect(SidebarAgentTilePresentation.project(agent: "OpenCode", state: .output).kind == .openCode)
    #expect(SidebarAgentTilePresentation.project(agent: "Pi", state: .waiting).kind == .pi)
    #expect(SidebarAgentTilePresentation.project(agent: "Grok", state: .error).kind == .grok)
    let shell = SidebarAgentTilePresentation.project(agent: nil, state: .idle)
    #expect(shell.kind == .shell)
    #expect(shell.accessibilityLabel == "Shell, Idle")
    #expect(!shell.showsBadge)

    let calm = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let needy = PaneSnapshot(
        title: "Review", workingDirectory: "/tmp", agent: "Codex", agentState: .needsAttention
    )
    let workspace = WorkspaceSnapshot(
        name: "Work", focusedPaneID: calm.id,
        layout: .split(axis: .horizontal, fraction: 0.5, first: .pane(calm), second: .pane(needy))
    )
    let rollup = SidebarAgentTilePresentation.project(workspace: workspace)
    #expect(rollup.kind == .codex)
    #expect(rollup.badgeSymbol == "!")
    #expect(rollup.stateToken == "needs")
    #expect(rollup.accessibilityLabel == "Codex, Needs Attention")
}

@Test func collapsedJumpNumbersRevealOnlyForTheConfiguredMode() {
    #expect(SidebarJumpNumberDisplay.resolve(
        collapsed: false, alwaysShow: true, primaryModifierHeld: true
    ) == .hidden)
    #expect(SidebarJumpNumberDisplay.resolve(
        collapsed: true, alwaysShow: false, primaryModifierHeld: false
    ) == .hidden)
    #expect(SidebarJumpNumberDisplay.resolve(
        collapsed: true, alwaysShow: false, primaryModifierHeld: true
    ) == .overlay)
    #expect(SidebarJumpNumberDisplay.resolve(
        collapsed: true, alwaysShow: true, primaryModifierHeld: false
    ) == .belowTile)
    #expect(CommandID.jumpWorkspace1.workspaceJumpIndex == 0)
    #expect(CommandID.jumpWorkspace9.workspaceJumpIndex == 8)
    #expect(CommandID.nextWorkspace.workspaceJumpIndex == nil)
}

@Test func groupCloseAffordanceReplacesCountOnlyWhenSafeAndDiscoverable() {
    func shows(
        hover: Bool = false, rail: Bool = false, filtering: Bool = false,
        resolved: Bool = true, empty: Bool = false, collapsed: Bool = false,
        dragging: Bool = false
    ) -> Bool {
        SidebarGroupClosePolicy.showsCloseButton(
            pointerOrFocusInside: hover, isCollapsedRail: rail, isFiltering: filtering,
            hasResolvedGroup: resolved, isGroupEmpty: empty,
            isGroupCollapsed: collapsed, isDragActive: dragging
        )
    }
    #expect(!shows())
    #expect(shows(hover: true))
    #expect(shows(empty: true))
    #expect(!shows(hover: true, rail: true))
    #expect(!shows(hover: true, filtering: true))
    #expect(!shows(hover: true, resolved: false))
    #expect(!shows(empty: true, collapsed: true))
    #expect(!shows(empty: true, dragging: true))
}

@Test func insertionResolverUsesPostRemovalIndicesAndRejectsNoOps() {
    #expect(SidebarInsertionResolver.reorderTarget(
        sourceIndex: 0, targetIndex: 2, edge: .after, count: 4
    ) == 2)
    #expect(SidebarInsertionResolver.reorderTarget(
        sourceIndex: 3, targetIndex: 1, edge: .before, count: 4
    ) == 1)
    #expect(SidebarInsertionResolver.reorderTarget(
        sourceIndex: 1, targetIndex: 1, edge: .before, count: 4
    ) == nil)
    #expect(SidebarInsertionResolver.reorderTarget(
        sourceIndex: 1, targetIndex: 0, edge: .after, count: 4
    ) == nil)
    #expect(SidebarInsertionResolver.reorderTarget(
        sourceIndex: -1, targetIndex: 0, edge: .before, count: 4
    ) == nil)
}

@Test func sidebarReorderAnnouncementsMatchReferenceWording() {
    #expect(SidebarAnnouncement.movedWorkspace(
        title: "Review", position: 2, count: 4, groupName: "Local"
    ) == "Moved Review to position 2 of 4 in Local")
    #expect(SidebarAnnouncement.movedGroup(
        name: "Local", position: 1, count: 3
    ) == "Moved Local group to position 1 of 3")
    #expect(SidebarAnnouncement.movedPinnedWorkspace(
        title: "Review", position: 3, count: 5
    ) == "Moved Review to position 3 of 5 in Pinned")
    #expect(SidebarAnnouncement.unansweredTurnPromoted(title: "Review")
        == "Review is still waiting for a reply, moved to Needs Input")
    #expect(SidebarAnnouncement.attentionPromoted(agent: "Claude Code", title: "Review")
        == "Claude Code in Review needs input.")
    #expect(SidebarAnnouncement.agentCompleted(agent: "Codex", title: "Review")
        == "Codex in Review completed.")
    #expect(SidebarAnnouncement.agentReportedError(agent: "OpenCode", title: "Review")
        == "OpenCode in Review reported an error.")
}

@Test func sidebarAccessibilityCopyRejectsInvalidPositionsAndUsesSingularCounts() {
    #expect(SidebarAccessibilityCopy.position(2, of: 3) == "Position 2 of 3")
    #expect(SidebarAccessibilityCopy.position(0, of: 3) == nil)
    #expect(SidebarAccessibilityCopy.position(4, of: 3) == nil)
    #expect(SidebarAccessibilityCopy.workspaceCount(0) == "0 workspaces")
    #expect(SidebarAccessibilityCopy.workspaceCount(1) == "1 workspace")
    #expect(SidebarAccessibilityCopy.workspaceCount(2) == "2 workspaces")
    #expect(SidebarAccessibilityCopy.newWorkspaceHint
        == "Creates a new workspace in the current group.")
    #expect(SidebarAccessibilityCopy.newWorkspaceOptionsHint
        == "Opens a menu to create a new workspace group or a workspace in a specific group.")
    #expect(SidebarAccessibilityCopy.newWorkspaceMenuHint
        == "Opens a menu with New Workspace, New Workspace in a chosen group, and New Workspace Group")
    #expect(SidebarAccessibilityCopy.collapsedSearchHint
        == "Opens the command palette to search workspaces and actions.")
}
