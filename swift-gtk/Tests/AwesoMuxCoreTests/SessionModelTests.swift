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
