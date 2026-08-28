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
