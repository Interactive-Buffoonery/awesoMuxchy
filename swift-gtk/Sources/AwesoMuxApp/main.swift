import AwesoMuxCore
import AwesoMuxTerminal
import CGtk
import Foundation
import GIO
import GLib
import Gtk

private final class ApplicationState {
    private final class WorkspaceRuntime {
        let workspaceID: UUID
        let pageName: String
        let root: WidgetRef
        let surfaces: [TerminalSurface]
        var focusedPaneID: UUID
        var focusedSurface: TerminalSurface

        init(
            workspaceID: UUID,
            pageName: String,
            root: WidgetRef,
            surfaces: [TerminalSurface],
            focusedPaneID: UUID,
            focusedSurface: TerminalSurface
        ) {
            self.workspaceID = workspaceID
            self.pageName = pageName
            self.root = root
            self.surfaces = surfaces
            self.focusedPaneID = focusedPaneID
            self.focusedSurface = focusedSurface
        }
    }

    let terminalRuntime: TerminalRuntime
    private(set) var snapshot: SessionSnapshot
    private let sessionStore: SessionStore
    private(set) var isPersistencePaused = false
    private let chromeStyles = CSSProvider(from: """
        .aw-root {
          background: #181825;
        }
        .aw-sidebar {
          background: #181825;
          border-right: 1px solid #313244;
        }
        .aw-brand {
          color: #cdd6f4;
          font-size: 22px;
          font-weight: 700;
        }
        .aw-group-label {
          color: #a6adc8;
          font-size: 11px;
          font-weight: 700;
          letter-spacing: 1px;
        }
        button.aw-workspace-row {
          color: #bac2de;
          background: transparent;
          border: 1px solid transparent;
          border-radius: 8px;
          padding: 10px 12px;
          font-size: 13px;
          font-weight: 500;
        }
        button.aw-workspace-row:hover {
          background: #313244;
        }
        button.aw-workspace-row.suggested-action {
          color: #cdd6f4;
          background: #313244;
          border-color: #45475a;
          box-shadow: inset 3px 0 #89b4fa;
        }
        """)
    var surfaces: [TerminalSurface] = []
    private(set) var focusedSurface: TerminalSurface?
    private(set) var focusedPaneID: UUID?
    private var surfacesByPaneID: [UUID: TerminalSurface] = [:]
    private var workspaceIDByPaneID: [UUID: UUID] = [:]
    private var workspaces: [UUID: WorkspaceRuntime] = [:]
    private var workspaceRows: [UUID: ButtonRef] = [:]
    private var workspaceStack: StackRef?
    private var commandActions: [GIO.SimpleAction] = []
    private var commandMenu: GIO.Menu?

    init?(snapshot: SessionSnapshot, sessionStore: SessionStore) {
        guard let runtime = TerminalRuntime() else { return nil }
        terminalRuntime = runtime
        self.snapshot = snapshot
        self.sessionStore = sessionStore
    }

    deinit {
        focusedSurface = nil
        surfaces.removeAll()
    }

    func makeSurface(
        pane: PaneSnapshot,
        workspaceID: UUID,
        accessibleLabel: String,
        accessibleDescription: String
    ) -> TerminalSurface? {
        guard let surface = terminalRuntime.makeSurface(
            workingDirectory: pane.workingDirectory,
            accessibleLabel: accessibleLabel,
            accessibleDescription: accessibleDescription,
            onFocusChanged: { [weak self] focused in
                guard focused else { return }
                self?.terminalDidFocus(paneID: pane.id)
            }
        ) else { return nil }
        surfaces.append(surface)
        surfacesByPaneID[pane.id] = surface
        workspaceIDByPaneID[pane.id] = workspaceID
        return surface
    }

    private func terminalDidFocus(paneID: UUID) {
        guard let surface = surfacesByPaneID[paneID],
              let workspaceID = workspaceIDByPaneID[paneID],
              let workspace = workspaces[workspaceID]
        else { return }
        let focusChanged = snapshot.workspace(id: workspaceID)?.focusedPaneID != paneID
        if focusChanged {
            try? snapshot.focusPane(paneID, in: workspaceID)
        }
        workspace.focusedPaneID = paneID
        workspace.focusedSurface = surface
        focusedPaneID = paneID
        focusedSurface = surface
        if focusChanged { persistSnapshot() }
    }

    func focus(paneID: UUID) {
        guard let surface = surfacesByPaneID[paneID] else { return }
        terminalDidFocus(paneID: paneID)
        surface.focus()
    }

    func surface(for paneID: UUID) -> TerminalSurface? {
        surfacesByPaneID[paneID]
    }

    func installChromeStyles(for widget: WidgetRef) {
        gtk_style_context_add_provider_for_display(
            widget.getDisplay().display_ptr,
            chromeStyles.styleProvider.style_provider_ptr,
            UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION)
        )
    }

    func install(
        stack: StackRef,
        workspaceID: UUID,
        pageName: String,
        root: WidgetRef,
        surfaces: [TerminalSurface],
        focusedPaneID: UUID,
        focusedSurface: TerminalSurface,
        row: ButtonRef
    ) {
        workspaceStack = stack
        workspaces[workspaceID] = WorkspaceRuntime(
            workspaceID: workspaceID,
            pageName: pageName,
            root: root,
            surfaces: surfaces,
            focusedPaneID: focusedPaneID,
            focusedSurface: focusedSurface
        )
        workspaceRows[workspaceID] = row
    }

    func selectWorkspace(_ workspaceID: UUID) {
        guard let workspace = workspaces[workspaceID], let stack = workspaceStack else { return }
        try? snapshot.selectWorkspace(workspaceID)
        workspace.pageName.withCString { stack.setVisibleChild(name: $0) }
        for (rowWorkspaceID, row) in workspaceRows {
            if rowWorkspaceID == workspaceID {
                row.add(cssClass: "suggested-action")
            } else {
                row.remove(cssClass: "suggested-action")
            }
        }
        focus(paneID: workspace.focusedPaneID)
        persistSnapshot()
    }

    private func persistSnapshot() {
        do {
            try sessionStore.save(snapshot)
            isPersistencePaused = false
        } catch {
            isPersistencePaused = true
        }
    }

    func installCommands(on application: Gtk.ApplicationRef) {
        let implemented: Set<CommandID> = [
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
        ]
        let menu = GIO.Menu()
        for section in [CommandSection.file, .view, .workspace, .pane] {
            let submenu = GIO.Menu()
            for definition in CommandCatalog.definitions where definition.section == section {
                let action = GIO.SimpleAction(
                    name: definition.id.rawValue,
                    parameterType: nil as VariantTypeRef?
                )
                action.set(enabled: implemented.contains(definition.id))
                action.onActivate { [weak self] _, _ in
                    self?.perform(definition.id)
                }
                application.add(action: action)
                submenu.append(
                    label: definition.action,
                    detailedAction: "app.\(definition.id.rawValue)"
                )
                if let chord = definition.defaultChord {
                    installAccelerator(chord: chord, for: definition.id, on: application)
                }
                commandActions.append(action)
            }
            menu.appendSubmenu(label: section.rawValue, submenu: submenu)
        }
        application.set(menubar: menu)
        commandMenu = menu
    }

    private func installAccelerator(
        chord: KeyChord,
        for command: CommandID,
        on application: Gtk.ApplicationRef
    ) {
        let modifiers: [(ShortcutModifier, String)] = [
            (.control, "<Control>"), (.alt, "<Alt>"),
            (.shift, "<Shift>"), (.superKey, "<Super>"),
        ]
        let gtkKeyNames = [
            "/": "slash", "[": "bracketleft", "]": "bracketright",
            "-": "minus", "=": "equal",
        ]
        let accelerator = modifiers
            .filter { chord.modifiers.contains($0.0) }
            .map(\.1)
            .joined() + (gtkKeyNames[chord.key] ?? chord.key)
        accelerator.withCString { acceleratorPointer in
            let pointers: [UnsafePointer<CChar>?] = [acceleratorPointer, nil]
            pointers.withUnsafeBufferPointer { buffer in
                application.setAccelsForAction(
                    detailedActionName: "app.\(command.rawValue)",
                    accels: buffer.baseAddress!
                )
            }
        }
    }

    private func perform(_ command: CommandID) {
        guard let selectedWorkspaceID = snapshot.selectedWorkspaceID,
              let workspace = workspaces[selectedWorkspaceID]
        else { return }
        switch command {
        case .previousWorkspace:
            selectRelativeWorkspace(offset: -1)
        case .nextWorkspace:
            selectRelativeWorkspace(offset: 1)
        case .previousPane:
            focusRelativePane(offset: -1, in: workspace)
        case .nextPane:
            focusRelativePane(offset: 1, in: workspace)
        default:
            break
        }
    }

    private func selectRelativeWorkspace(offset: Int) {
        guard (try? snapshot.selectRelativeWorkspace(offset: offset)) != nil,
              let selectedWorkspaceID = snapshot.selectedWorkspaceID
        else { return }
        selectWorkspace(selectedWorkspaceID)
    }

    private func focusRelativePane(offset: Int, in workspace: WorkspaceRuntime) {
        guard (try? snapshot.focusRelativePane(
            offset: offset,
            in: workspace.workspaceID
        )) != nil,
              let paneID = snapshot.workspace(id: workspace.workspaceID)?.focusedPaneID
        else { return }
        focus(paneID: paneID)
    }
}

nonisolated(unsafe) private var retainedState: ApplicationState?

private func initialSnapshot(workingDirectory: String) -> SessionSnapshot {
    let developmentPrimary = PaneSnapshot(
        title: "Primary terminal",
        workingDirectory: workingDirectory
    )
    let developmentSecondary = PaneSnapshot(
        title: "Secondary terminal",
        workingDirectory: workingDirectory
    )
    let reviewPrimary = PaneSnapshot(
        title: "Primary terminal",
        workingDirectory: workingDirectory
    )
    let development = WorkspaceSnapshot(
        name: "Development",
        focusedPaneID: developmentPrimary.id,
        layout: .split(
            axis: .horizontal,
            fraction: 0.5,
            first: .pane(developmentPrimary),
            second: .pane(developmentSecondary)
        )
    )
    let review = WorkspaceSnapshot(
        name: "Review",
        focusedPaneID: reviewPrimary.id,
        layout: .pane(reviewPrimary)
    )
    return SessionSnapshot(
        selectedWorkspaceID: development.id,
        groups: [
            WorkspaceGroupSnapshot(
                name: "Local",
                color: .blue,
                workspaces: [development, review]
            ),
        ]
    )
}

private func buildWindow(for application: Gtk.ApplicationRef) {
    let directory = FileManager.default.currentDirectoryPath
    let fallbackSnapshot = initialSnapshot(workingDirectory: directory)
    let paths: SessionProfilePaths
    do {
        paths = try SessionProfilePaths(profile: "default")
    } catch {
        fatalError("Default profile path is invalid")
    }
    let sessionStore = SessionStore(paths: paths)
    let snapshot: SessionSnapshot
    switch try? sessionStore.loadRecovering() {
    case let .restored(restored), let .recoveredPrevious(restored):
        snapshot = restored
    case .missing, .resetAfterQuarantine, .none:
        snapshot = fallbackSnapshot
    }
    guard let state = ApplicationState(
        snapshot: snapshot,
        sessionStore: sessionStore
    ) else {
        fatalError("Ghostty runtime initialization failed")
    }
    retainedState = state
    state.installCommands(on: application)

    let window = ApplicationWindowRef(application: application)
    window.title = "awesoMux"
    window.setDefaultSize(width: 1440, height: 900)

    let root = BoxRef(orientation: .horizontal, spacing: 0)
    root.add(cssClass: "aw-root")
    state.installChromeStyles(for: WidgetRef(root))
    let sidebar = BoxRef(orientation: .vertical, spacing: 8)
    sidebar.add(cssClass: "aw-sidebar")
    sidebar.setSizeRequest(width: 248, height: -1)
    sidebar.set(marginStart: 12)
    sidebar.set(marginEnd: 12)
    sidebar.setMarginTop(margin: 16)
    sidebar.setMarginBottom(margin: 16)

    let brand = LabelRef(str: "awesoMux")
    brand.xalign = 0
    brand.add(cssClass: "aw-brand")
    sidebar.append(child: brand)

    let stack = StackRef()
    stack.setHexpand(expand: true)
    stack.setVexpand(expand: true)
    stack.set(hhomogeneous: true)
    stack.set(vhomogeneous: true)

    func buildLayout(
        _ layout: PaneLayout,
        workspace: WorkspaceSnapshot
    ) -> (widget: WidgetRef, surfaces: [TerminalSurface])? {
        switch layout {
        case let .pane(pane):
            let ordinal = (workspace.layout.paneIDs.firstIndex(of: pane.id) ?? 0) + 1
            guard let surface = state.makeSurface(
                pane: pane,
                workspaceID: workspace.id,
                accessibleLabel: "\(workspace.name) \(pane.title)",
                accessibleDescription: "Terminal pane \(ordinal) of \(workspace.layout.paneCount) in the \(workspace.name) workspace"
            ) else { return nil }
            return (surface.widget, [surface])
        case let .split(axis, fraction, first, second):
            guard let firstPage = buildLayout(first, workspace: workspace),
                  let secondPage = buildLayout(second, workspace: workspace)
            else { return nil }
            let paned = PanedRef(
                orientation: axis == .horizontal ? .horizontal : .vertical
            )
            let available = axis == .horizontal ? 1160.0 : 850.0
            paned.set(position: Int(available * min(max(fraction, 0.1), 0.9)))
            paned.setWideHandle(wide: true)
            paned.setStart(child: firstPage.widget)
            paned.setEnd(child: secondPage.widget)
            return (WidgetRef(paned), firstPage.surfaces + secondPage.surfaces)
        }
    }

    for group in snapshot.groups where !group.isCollapsed {
        let groupLabel = LabelRef(str: group.name.uppercased())
        groupLabel.xalign = 0
        groupLabel.add(cssClass: "aw-group-label")
        groupLabel.setMarginTop(margin: 18)
        sidebar.append(child: groupLabel)

        for workspace in group.workspaces where !workspace.isSoftClosed {
            guard let page = buildLayout(workspace.layout, workspace: workspace),
                  let focusedSurface = state.surface(for: workspace.focusedPaneID)
            else {
                fatalError("Ghostty terminal surface initialization failed")
            }
            let pageName = workspace.id.uuidString
            _ = pageName.withCString { stack.addNamed(child: page.widget, name: $0) }
            let row = ButtonRef(label: workspace.name)
            row.add(cssClass: "aw-workspace-row")
            row.setHalign(align: .fill)
            row.setMarginTop(margin: 8)
            row.setMarginBottom(margin: 8)
            row.onClicked { [weak state] _ in
                state?.selectWorkspace(workspace.id)
            }
            sidebar.append(child: row)
            state.install(
                stack: stack,
                workspaceID: workspace.id,
                pageName: pageName,
                root: page.widget,
                surfaces: page.surfaces,
                focusedPaneID: workspace.focusedPaneID,
                focusedSurface: focusedSurface,
                row: row
            )
        }
    }

    root.append(child: sidebar)
    root.append(child: stack)
    window.set(child: root)
    window.present()
    if let selectedWorkspaceID = snapshot.selectedWorkspaceID {
        state.selectWorkspace(selectedWorkspaceID)
    }
}

let status = Application.run(
    id: "com.interactivebuffoonery.awesomux",
    arguments: CommandLine.arguments,
    activationHandler: buildWindow
)

guard let status else {
    fatalError("Could not create GTK application")
}
exit(Int32(status))
