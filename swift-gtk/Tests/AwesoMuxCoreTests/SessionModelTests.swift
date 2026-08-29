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

    value.groups[0].workspaces[0].acknowledgedAttentionPaneIDs = [newPane.id]
    value.unansweredTurnPaneIDs.insert(newPane.id)

    let decision = try value.closeFocusedPane(in: initial.id)
    #expect(decision == .closePane(newPane.id))
    #expect(value.workspaces[0].layout.paneIDs == [initial.focusedPaneID])
    #expect(value.workspaces[0].focusedPaneID == initial.focusedPaneID)
    #expect(value.workspaces[0].acknowledgedAttentionPaneIDs.isEmpty)
    #expect(!value.unansweredTurnPaneIDs.contains(newPane.id))
    _ = try value.validated()
}

@Test func closingFocusedPaneChoosesItsNextTraversalNeighbor() throws {
    let initial = workspace(panes: 3)
    let paneIDs = initial.layout.paneIDs
    var value = snapshot([initial])
    try value.focusPane(paneIDs[1], in: initial.id)

    let decision = try value.closeFocusedPane(in: initial.id)

    #expect(decision == .closePane(paneIDs[1]))
    #expect(value.workspaces[0].layout.paneIDs == [paneIDs[0], paneIDs[2]])
    #expect(value.workspaces[0].focusedPaneID == paneIDs[2])
}

@Test func resizingFocusedPaneChangesNearestSplitAndClampsItsFraction() throws {
    let first = PaneSnapshot(title: "first", workingDirectory: "/tmp")
    let second = PaneSnapshot(title: "second", workingDirectory: "/tmp")
    let third = PaneSnapshot(title: "third", workingDirectory: "/tmp")
    let nested = PaneLayout.split(
        axis: .vertical, fraction: 0.5,
        first: .pane(second), second: .pane(third)
    )
    let workspace = WorkspaceSnapshot(
        name: "Nested", focusedPaneID: second.id,
        layout: .split(
            axis: .horizontal, fraction: 0.4,
            first: .pane(first), second: nested
        )
    )
    var value = snapshot([workspace])

    #expect(try value.resizeFocusedSplit(in: workspace.id, by: 0.05))
    guard case let .split(_, rootFraction, _, right) = value.workspaces[0].layout,
          case let .split(_, nestedFraction, _, _) = right else {
        Issue.record("Expected the nested split layout")
        return
    }
    #expect(rootFraction == 0.4)
    #expect(nestedFraction == 0.55)

    try value.focusPane(third.id, in: workspace.id)
    #expect(try value.resizeFocusedSplit(in: workspace.id, by: 1))
    guard case let .split(_, _, _, clampedRight) = value.workspaces[0].layout,
          case let .split(_, clampedFraction, _, _) = clampedRight else {
        Issue.record("Expected the clamped nested split layout")
        return
    }
    #expect(clampedFraction == 0.1)
    #expect(!(try value.resizeFocusedSplit(in: workspace.id, by: 1)))
}

@Test func settingDividerFractionTargetsExactNestedSplitAndClamps() throws {
    let first = PaneSnapshot(title: "first", workingDirectory: "/tmp")
    let second = PaneSnapshot(title: "second", workingDirectory: "/tmp")
    let third = PaneSnapshot(title: "third", workingDirectory: "/tmp")
    let nested = PaneLayout.split(
        axis: .vertical, fraction: 0.5,
        first: .pane(second), second: .pane(third)
    )
    let workspace = WorkspaceSnapshot(
        name: "Nested", focusedPaneID: first.id,
        layout: .split(
            axis: .horizontal, fraction: 0.4,
            first: .pane(first), second: nested
        )
    )
    var value = snapshot([workspace])

    #expect(try value.setSplitFraction(
        in: workspace.id, splitPaneIDs: nested.paneIDs, to: 0.82
    ))
    guard case let .split(_, rootFraction, _, right) = value.workspaces[0].layout,
          case let .split(_, nestedFraction, _, _) = right else {
        Issue.record("Expected the nested split layout")
        return
    }
    #expect(rootFraction == 0.4)
    #expect(nestedFraction == 0.82)

    #expect(try value.setSplitFraction(
        in: workspace.id, splitPaneIDs: nested.paneIDs, to: 1
    ))
    guard case let .split(_, _, _, clampedRight) = value.workspaces[0].layout,
          case let .split(_, clampedFraction, _, _) = clampedRight else {
        Issue.record("Expected the clamped nested split layout")
        return
    }
    #expect(clampedFraction == 0.9)
    #expect(!(try value.setSplitFraction(
        in: workspace.id, splitPaneIDs: [UUID()], to: 0.5
    )))
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
    #expect(CommandCatalog.definition(for: .growActivePane).action == "Grow Active Pane")
    #expect(CommandCatalog.definition(for: .shrinkActivePane).action == "Shrink Active Pane")
    #expect(CommandCatalog.definition(for: .focusPane1).action == "Focus Pane 1")
    #expect(CommandID.focusPane6.paneFocusIndex == 6)
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

@Test func indexedPaneFocusUsesOneBasedDepthFirstOrderAndRejectsNoOps() throws {
    let workspace = workspace(panes: 3)
    var value = snapshot([workspace])

    #expect(try value.focusPane(at: 3, in: workspace.id))
    #expect(value.workspace(id: workspace.id)?.focusedPaneID == workspace.layout.paneIDs[2])
    #expect(!(try value.focusPane(at: 3, in: workspace.id)))
    #expect(!(try value.focusPane(at: 0, in: workspace.id)))
    #expect(!(try value.focusPane(at: 4, in: workspace.id)))
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

@Test func startupRecoveryPresentationIsTruthfulAndUsesReferenceCopy() {
    let value = snapshot([workspace(panes: 1)])
    #expect(SessionRecoveryPresentation.resolve(.missing) == nil)
    #expect(SessionRecoveryPresentation.resolve(.restored(value)) == nil)
    #expect(SessionRecoveryPresentation.resolve(.recoveredPrevious(value)) == .init(
        title: "Couldn't reopen your last workspaces",
        message: "Saved workspaces could not be decoded; the original snapshot was archived"
    ))
    #expect(SessionRecoveryPresentation.resolve(.resetAfterQuarantine) == .init(
        title: "Couldn't reopen your last workspaces",
        message: "We found a problem with your saved session and set it aside safely. Create a workspace with Control-N to start fresh."
    ))
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

@Test func persistenceCoordinatorCoalescesBurstAndFlushesLatestSnapshot() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        previousSnapshotURL: root.appendingPathComponent("session.previous.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let first = snapshot([workspace(panes: 1)])
    let second = snapshot([workspace(panes: 2)])
    let third = snapshot([workspace(panes: 3)])
    let coordinator = SessionPersistenceCoordinator(
        store: store,
        debounceNanoseconds: 60_000_000_000
    )

    coordinator.schedule(first)
    coordinator.schedule(second)
    coordinator.schedule(third)

    #expect(coordinator.flush() == .saved)
    #expect(try store.load() == third)
    #expect(!FileManager.default.fileExists(atPath: store.previousSnapshotURL.path))
}

@Test func persistenceCoordinatorFlushSupersedesPendingSnapshot() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let pending = snapshot([workspace(panes: 1)])
    let lifecycleBoundary = snapshot([workspace(panes: 2)])
    let coordinator = SessionPersistenceCoordinator(
        store: store,
        debounceNanoseconds: 60_000_000_000
    )

    coordinator.schedule(pending)

    #expect(coordinator.flush(lifecycleBoundary) == .saved)
    #expect(try store.load() == lifecycleBoundary)
}

@Test func persistenceCoordinatorWritesLatestSnapshotAfterBoundedDelay() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = SessionStore(
        snapshotURL: root.appendingPathComponent("session.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let first = snapshot([workspace(panes: 1)])
    let latest = snapshot([workspace(panes: 2)])
    let completed = DispatchSemaphore(value: 0)
    let coordinator = SessionPersistenceCoordinator(
        store: store,
        debounceNanoseconds: 20_000_000
    ) { outcome in
        if outcome == .saved { completed.signal() }
    }

    coordinator.schedule(first)
    coordinator.schedule(latest)

    #expect(completed.wait(timeout: .now() + .seconds(2)) == .success)
    #expect(try store.load() == latest)
    #expect(!FileManager.default.fileExists(atPath: store.previousSnapshotURL.path))
}

@Test func persistenceCoordinatorReportsWriteFailureAndCanRetry() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let blockedParent = root.appendingPathComponent("not-a-directory")
    try Data("blocked".utf8).write(to: blockedParent)
    let store = SessionStore(
        snapshotURL: blockedParent.appendingPathComponent("session.json"),
        quarantineDirectoryURL: root.appendingPathComponent("quarantine")
    )
    let coordinator = SessionPersistenceCoordinator(store: store)
    let value = snapshot([workspace(panes: 1)])

    #expect(coordinator.flush(value) == .failed)
    try FileManager.default.removeItem(at: blockedParent)
    #expect(coordinator.flush() == .saved)
    #expect(try store.load() == value)
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
    #expect(title?.titleMatches == [0..<1, 1..<3, 3..<4, 4..<5, 5..<6, 6..<8])
    #expect(title?.locationMatches == [])

    let location = SidebarSearchProjection.project(snapshot: value, query: "cafe", homeDirectory: "/home/test")
        .groups.first?.rows.first
    #expect(location?.titleMatches == [])
    #expect(location?.locationMatches == [6..<7, 7..<8, 8..<9, 9..<11])

    let hiddenToken = SidebarSearchProjection.project(snapshot: value, query: "local", homeDirectory: "/home/test")
        .groups.first?.rows.first
    #expect(hiddenToken?.titleMatches == [])
    #expect(hiddenToken?.locationMatches == [])
}

@Test func sidebarFuzzyMatcherScoresBoundariesAndPublishesEveryUTF8Range() throws {
    let initials = try #require(SidebarFuzzyMatcher.match(query: "cc", in: "Claude Code"))
    #expect(initials.ranges == [0..<1, 7..<8])

    let accented = try #require(SidebarFuzzyMatcher.match(query: "cafe", in: "Café"))
    #expect(accented.ranges == [0..<1, 1..<2, 2..<3, 3..<5])

    let later = try #require(SidebarFuzzyMatcher.match(query: "cod", in: "cxxxxxxxxx Code"))
    #expect(later.ranges == [11..<12, 12..<13, 13..<14])

    let boundary = try #require(SidebarFuzzyMatcher.match(query: "p", in: "Foo Project"))
    let midword = try #require(SidebarFuzzyMatcher.match(query: "p", in: "Floppy"))
    #expect(boundary.score > midword.score)
    #expect(SidebarFuzzyMatcher.match(
        query: String(repeating: "a", count: SidebarFuzzyMatcher.maximumQueryLength + 1),
        in: "anything"
    ) == nil)
}

@Test func sidebarFuzzySearchOrdersScoresStablyAndKeepsBroadHiddenFields() {
    let weakPane = PaneSnapshot(title: "cxxxxxxxxxod", workingDirectory: "/tmp")
    let strongPane = PaneSnapshot(title: "Code", workingDirectory: "/tmp")
    let weak = WorkspaceSnapshot(name: "cxxxxxxxxxod", focusedPaneID: weakPane.id, layout: .pane(weakPane))
    let strong = WorkspaceSnapshot(name: "Code", focusedPaneID: strongPane.id, layout: .pane(strongPane))
    let remotePane = PaneSnapshot(
        title: "Shell", workingDirectory: "/tmp", agent: "Codex",
        ownership: .remoteZmx
    )
    let remote = WorkspaceSnapshot(
        name: "Remote", focusedPaneID: remotePane.id, layout: .pane(remotePane)
    )
    let value = SessionSnapshot(groups: [
        WorkspaceGroupSnapshot(name: "Work", workspaces: [weak, strong, remote]),
    ])

    let scored = SidebarSearchProjection.project(snapshot: value, query: "cod")
    #expect(scored.orderedWorkspaceIDs.prefix(2) == [strong.id, weak.id])
    #expect(scored.groups[0].rows[0].titleMatches == [0..<1, 1..<2, 2..<3])

    let provider = SidebarSearchProjection.project(snapshot: value, query: "codex")
    #expect(provider.orderedWorkspaceIDs == [remote.id])
    #expect(provider.groups[0].rows[0].titleMatches.isEmpty)

    let remoteIdentity = SidebarSearchProjection.project(snapshot: value, query: "ssh")
    #expect(remoteIdentity.orderedWorkspaceIDs == [remote.id])
    #expect(remoteIdentity.groups[0].rows[0].locationMatches.isEmpty)
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

@Test func workspaceRenameDraftMatchesReferenceCopyAndValidation() {
    #expect(WorkspaceRenameDraft.heading(for: "Review") == "Rename 'Review'")
    #expect(WorkspaceRenameDraft.heading(for: "Build\nready") == "Rename 'Buildready'")
    #expect(WorkspaceRenameDraft.emptyHint == "Enter a workspace name to enable Save")
    #expect(!WorkspaceRenameDraft.canSubmit(" \n "))
    #expect(WorkspaceRenameDraft.canSubmit("  Review  "))
    #expect(WorkspaceRenameDraft.sanitized("  Review\nReady  ") == "ReviewReady")
}

@Test func workspaceGroupNameDraftMatchesReferenceValidationAndFeedback() {
    let empty = WorkspaceGroupNameDraft(typedName: "", existingGroupNames: ["Local"])
    #expect(!empty.canSubmit)
    #expect(empty.validationMessage == "Enter a group name.")
    #expect(WorkspaceGroupNameDraft.createEmptyHint
        == "Enter a workspace group name to enable Create")
    #expect(WorkspaceGroupNameDraft.renameEmptyHint
        == "Enter a workspace group name to enable Save")

    let duplicate = WorkspaceGroupNameDraft(typedName: "lócal", existingGroupNames: ["Local"])
    #expect(!duplicate.canSubmit)
    #expect(duplicate.validationMessage == "\"lócal\" already exists.")

    let mixed = WorkspaceGroupNameDraft(typedName: "Lοcal", existingGroupNames: [])
    #expect(!mixed.canSubmit)
    #expect(mixed.validationMessage
        == "Mixing Latin with Cyrillic or Greek letters isn't allowed here — use one alphabet.")

    let adjusted = WorkspaceGroupNameDraft(typedName: "  Field Ops  ", existingGroupNames: [])
    #expect(adjusted.canSubmit)
    #expect(adjusted.sanitizedName == "Field Ops")
    #expect(adjusted.sanitizationFeedback?.contains("\u{2068}Field Ops\u{2069}") == true)
    #expect(WorkspaceGroupNameDraft.clampedInput(
        String(repeating: "a", count: WorkspaceGroupNameDraft.inputScalarLimit + 1)
    ).unicodeScalars.count == WorkspaceGroupNameDraft.inputScalarLimit)
}

@Test func workspaceCreationTargetsSelectedOwnerAndConfiguredDefaultWithoutFirstGroupFallback() {
    let first = workspace(panes: 1)
    let selected = workspace(panes: 1)
    let firstGroup = WorkspaceGroupSnapshot(name: "Research", workspaces: [first])
    let selectedGroup = WorkspaceGroupSnapshot(name: "Product", workspaces: [selected])
    let defaultGroup = WorkspaceGroupSnapshot(name: "AWESÓMUX", workspaces: [])
    let selectedSnapshot = SessionSnapshot(
        selectedWorkspaceID: selected.id,
        groups: [firstGroup, selectedGroup, defaultGroup]
    )

    #expect(WorkspaceCreationTarget.selectedOwningGroupID(in: selectedSnapshot) == selectedGroup.id)
    #expect(WorkspaceCreationTarget.currentContextGroupID(in: selectedSnapshot) == selectedGroup.id)
    #expect(WorkspaceCreationTarget.defaultGroupID(in: selectedSnapshot) == defaultGroup.id)
    #expect(WorkspaceCreationTarget.currentDirectory(in: selectedSnapshot) == "/tmp")
    #expect(WorkspaceCreationTarget.workspaceHere(first.id, in: selectedSnapshot)
        == WorkspaceCreationContext(groupID: firstGroup.id, workingDirectory: "/tmp"))
    #expect(WorkspaceCreationTarget.workspaceHere(selected.id, in: selectedSnapshot)
        == WorkspaceCreationContext(groupID: selectedGroup.id, workingDirectory: "/tmp"))

    let groupless = SessionSnapshot(groups: [firstGroup, defaultGroup])
    #expect(WorkspaceCreationTarget.currentContextGroupID(in: groupless) == defaultGroup.id)
    #expect(WorkspaceCreationTarget.defaultGroupID(
        in: groupless, defaultGroupName: "Product"
    ) == nil)
    #expect(WorkspaceCreationTarget.currentContextGroupID(
        in: SessionSnapshot(groups: [firstGroup])
    ) == nil)
    #expect(WorkspaceCreationTarget.currentDirectory(in: groupless) == nil)
    #expect(WorkspaceCreationTarget.workspaceHere(UUID(), in: selectedSnapshot) == nil)

    let remotePane = PaneSnapshot(
        title: "Remote", workingDirectory: "/srv/project", ownership: .remoteZmx
    )
    let remoteWorkspace = WorkspaceSnapshot(
        name: "Remote", focusedPaneID: remotePane.id, layout: .pane(remotePane)
    )
    let remoteSnapshot = SessionSnapshot(
        selectedWorkspaceID: remoteWorkspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Remote", workspaces: [remoteWorkspace])]
    )
    #expect(WorkspaceCreationTarget.currentDirectory(in: remoteSnapshot) == "/srv/project")

    let missingPane = PaneSnapshot(title: "Missing", workingDirectory: "\n")
    let missingWorkspace = WorkspaceSnapshot(
        name: "Missing", focusedPaneID: missingPane.id, layout: .pane(missingPane)
    )
    let missingSnapshot = SessionSnapshot(
        selectedWorkspaceID: missingWorkspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [missingWorkspace])]
    )
    #expect(WorkspaceCreationTarget.currentDirectory(in: missingSnapshot) == nil)
    #expect(WorkspaceCreationTarget.workspaceHere(missingWorkspace.id, in: missingSnapshot) == nil)

    var closedWorkspace = first
    closedWorkspace.isSoftClosed = true
    let closedSnapshot = SessionSnapshot(groups: [
        WorkspaceGroupSnapshot(name: "Closed", workspaces: [closedWorkspace]),
    ])
    #expect(WorkspaceCreationTarget.workspaceHere(closedWorkspace.id, in: closedSnapshot) == nil)
}

@Test func groupAccessibilityPresentsLocalExecutionAndSelectedDescendant() {
    let pane = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let workspace = WorkspaceSnapshot(
        name: "Local", focusedPaneID: pane.id, layout: .pane(pane)
    )
    let group = WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace])

    let presentation = SidebarGroupAccessibilityPresentation(
        group: group, selectedWorkspaceID: workspace.id
    )
    #expect(presentation.workspaceCount == 1)
    #expect(presentation.hasSelectedDescendant)
    #expect(presentation.executionText == "Local panes")
    #expect(SidebarGroupAccessibilityPresentation(
        group: WorkspaceGroupSnapshot(name: "Empty", workspaces: []), selectedWorkspaceID: nil
    ).executionText == "Local creation default")
    var softClosedWorkspace = workspace
    softClosedWorkspace.isSoftClosed = true
    let softClosedPresentation = SidebarGroupAccessibilityPresentation(
        group: WorkspaceGroupSnapshot(name: "Closed", workspaces: [softClosedWorkspace]),
        selectedWorkspaceID: softClosedWorkspace.id
    )
    #expect(softClosedPresentation.workspaceCount == 0)
    #expect(!softClosedPresentation.hasSelectedDescendant)

    let remotePane = PaneSnapshot(
        title: "Remote", workingDirectory: "/srv", ownership: .remoteZmx
    )
    let remoteWorkspace = WorkspaceSnapshot(
        name: "Remote", focusedPaneID: remotePane.id, layout: .pane(remotePane)
    )
    #expect(SidebarGroupAccessibilityPresentation(
        group: WorkspaceGroupSnapshot(name: "Remote", workspaces: [remoteWorkspace]),
        selectedWorkspaceID: remoteWorkspace.id
    ).executionText == nil)
}

@Test func workspaceCloseRiskUsesProcessPromptAndFreshAgentEvidence() {
    let now = Date(timeIntervalSince1970: 20_000)
    func input(
        agent: String? = nil,
        state: AgentState = .idle,
        changedAt: Date? = nil,
        observed: Bool = true,
        away: Bool = false,
        liveness: ForegroundProcessLiveness
    ) -> PaneCloseRiskInput {
        PaneCloseRiskInput(
            agentName: agent, agentState: state,
            lastAgentStateChangeAt: changedAt,
            terminalPromptObserved: observed,
            terminalAwayFromPrompt: away, liveness: liveness
        )
    }

    #expect(!WorkspaceCloseRiskPolicy.decision(input(liveness: .exited), at: now).isRisk)
    #expect(!WorkspaceCloseRiskPolicy.decision(input(liveness: .idleShell), at: now).isRisk)
    #expect(!WorkspaceCloseRiskPolicy.decision(
        input(observed: false, away: true, liveness: .idleShell), at: now
    ).isRisk)
    #expect(WorkspaceCloseRiskPolicy.decision(input(away: true, liveness: .idleShell), at: now).reason == .terminalAwayFromPrompt)
    #expect(WorkspaceCloseRiskPolicy.decision(input(liveness: .busyShell), at: now).reason == .backgroundJob)
    #expect(WorkspaceCloseRiskPolicy.decision(input(liveness: .liveCommand), at: now).reason == .liveForegroundProcess)
    #expect(WorkspaceCloseRiskPolicy.decision(input(liveness: .indeterminate), at: now).reason == .indeterminate)
    #expect(WorkspaceCloseRiskPolicy.decision(
        input(agent: "Codex", state: .running, changedAt: now.addingTimeInterval(-1), liveness: .idleShell), at: now
    ).reason == .activeAgentExecution)
    #expect(!WorkspaceCloseRiskPolicy.decision(
        input(
            agent: "Codex", state: .running,
            changedAt: now.addingTimeInterval(-(WorkspaceCloseRiskPolicy.staleAgentActivityThreshold + 1)),
            liveness: .idleShell
        ), at: now
    ).isRisk)
    #expect(WorkspaceCloseRiskPolicy.workspaceHasRisk([
        input(liveness: .idleShell), input(liveness: .liveCommand),
    ], at: now))
}

@Test func foregroundProcessAndDestructiveClosePresentationMatchReference() {
    #expect(ForegroundProcessLiveness.classify(
        processExited: true, commandName: "sleep", hasChildren: nil
    ) == .exited)
    #expect(ForegroundProcessLiveness.classify(
        processExited: false, commandName: "/usr/bin/zsh", hasChildren: false
    ) == .idleShell)
    #expect(ForegroundProcessLiveness.classify(
        processExited: false, commandName: "bash", hasChildren: true
    ) == .busyShell)
    #expect(ForegroundProcessLiveness.classify(
        processExited: false, commandName: "vim", hasChildren: false
    ) == .liveCommand)
    #expect(ForegroundProcessLiveness.classify(
        processExited: false, commandName: nil, hasChildren: nil
    ) == .indeterminate)

    let isolated = "\u{2068}Review\u{2069}"
    #expect(DestructiveClosePresentation.closePaneTitle("Review") == "Close pane in \(isolated)?")
    #expect(DestructiveClosePresentation.closePaneBody("Review")
        == "The active pane in \(isolated) has activity that will be interrupted. Closing the pane will terminate the running process.")
    #expect(DestructiveClosePresentation.closePaneHint
        == "Press ⌘Return to close pane. Esc cancels.")
    #expect(DestructiveClosePresentation.closeWorkspaceTitle("Review") == "Close \(isolated)?")
    #expect(DestructiveClosePresentation.closeWorkspaceBody("Review")
        == "\(isolated) has activity that will be interrupted. Closing will terminate the running process.")
    #expect(DestructiveClosePresentation.clearWorkspaceTitle("Review") == "Clear \(isolated)?")
    #expect(DestructiveClosePresentation.closeGroupTitle("Local") == "Close group \u{2068}Local\u{2069}?")
    #expect(DestructiveClosePresentation.closeGroupBody(riskyWorkspaceCount: 1)
        == "1 workspace in this group has running activity that will be interrupted. Closing will terminate its running process.")
    #expect(DestructiveClosePresentation.spoken("Close \(isolated)?") == "Close Review?")
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
