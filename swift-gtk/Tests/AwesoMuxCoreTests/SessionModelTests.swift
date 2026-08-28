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
