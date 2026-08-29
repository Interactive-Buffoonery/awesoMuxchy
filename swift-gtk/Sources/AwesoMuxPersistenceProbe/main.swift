import AwesoMuxCore
import Foundation
import Glibc

guard CommandLine.arguments.count >= 3 else { exit(2) }
let mode = CommandLine.arguments[1]
let root = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
let store = SessionStore(
    snapshotURL: root.appendingPathComponent("session.json"),
    quarantineDirectoryURL: root.appendingPathComponent("quarantine", isDirectory: true)
)

func snapshot(named name: String) -> SessionSnapshot {
    let pane = PaneSnapshot(title: "shell", workingDirectory: "/tmp")
    let workspace = WorkspaceSnapshot(name: name, focusedPaneID: pane.id, layout: .pane(pane))
    return SessionSnapshot(
        selectedWorkspaceID: workspace.id,
        groups: [WorkspaceGroupSnapshot(name: "awesoMux", workspaces: [workspace])]
    )
}

switch mode {
case "seed":
    let coordinator = SessionPersistenceCoordinator(store: store)
    exit(coordinator.flush(snapshot(named: "Baseline")) == .saved ? 0 : 3)
case "stage":
    let coordinator = SessionPersistenceCoordinator(store: store)
    coordinator.schedule(snapshot(named: "Latest"))
    _ = FileManager.default.createFile(
        atPath: root.appendingPathComponent("ready").path,
        contents: Data()
    )
    while true { _ = pause() }
case "verify":
    guard CommandLine.arguments.count == 4,
          let restored = try? store.load(),
          restored.selectedWorkspace?.name == CommandLine.arguments[3]
    else { exit(4) }
    exit(0)
default:
    exit(2)
}
