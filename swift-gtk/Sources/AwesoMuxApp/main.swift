import AwesoMuxCore
import AwesoMuxTerminal
import CGtk
import Foundation
import Gtk

private final class ApplicationState {
    private final class WorkspaceRuntime {
        let name: String
        let pageName: String
        let root: WidgetRef
        let surfaces: [TerminalSurface]
        var focusedPaneID: UUID
        var focusedSurface: TerminalSurface

        init(
            name: String,
            pageName: String,
            root: WidgetRef,
            surfaces: [TerminalSurface],
            focusedPaneID: UUID,
            focusedSurface: TerminalSurface
        ) {
            self.name = name
            self.pageName = pageName
            self.root = root
            self.surfaces = surfaces
            self.focusedPaneID = focusedPaneID
            self.focusedSurface = focusedSurface
        }
    }

    let terminalRuntime: TerminalRuntime
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
    private var workspaceNameByPaneID: [UUID: String] = [:]
    private var workspaces: [String: WorkspaceRuntime] = [:]
    private var workspaceRows: [String: ButtonRef] = [:]
    private var workspaceStack: StackRef?
    private(set) var selectedWorkspaceName: String?

    init?() {
        guard let runtime = TerminalRuntime() else { return nil }
        terminalRuntime = runtime
    }

    deinit {
        focusedSurface = nil
        surfaces.removeAll()
    }

    func makeSurface(
        paneID: UUID,
        workspaceName: String,
        workingDirectory: String,
        accessibleLabel: String,
        accessibleDescription: String
    ) -> TerminalSurface? {
        guard let surface = terminalRuntime.makeSurface(
            workingDirectory: workingDirectory,
            accessibleLabel: accessibleLabel,
            accessibleDescription: accessibleDescription,
            onFocusChanged: { [weak self] focused in
                guard focused else { return }
                self?.terminalDidFocus(paneID: paneID)
            }
        ) else { return nil }
        surfaces.append(surface)
        surfacesByPaneID[paneID] = surface
        workspaceNameByPaneID[paneID] = workspaceName
        return surface
    }

    private func terminalDidFocus(paneID: UUID) {
        guard let surface = surfacesByPaneID[paneID],
              let workspaceName = workspaceNameByPaneID[paneID],
              let workspace = workspaces[workspaceName]
        else { return }
        workspace.focusedPaneID = paneID
        workspace.focusedSurface = surface
        focusedPaneID = paneID
        focusedSurface = surface
    }

    func focus(paneID: UUID) {
        guard let surface = surfacesByPaneID[paneID] else { return }
        terminalDidFocus(paneID: paneID)
        surface.focus()
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
        workspace: String,
        pageName: String,
        root: WidgetRef,
        surfaces: [TerminalSurface],
        focusedPaneID: UUID,
        focusedSurface: TerminalSurface,
        row: ButtonRef
    ) {
        workspaceStack = stack
        workspaces[workspace] = WorkspaceRuntime(
            name: workspace,
            pageName: pageName,
            root: root,
            surfaces: surfaces,
            focusedPaneID: focusedPaneID,
            focusedSurface: focusedSurface
        )
        workspaceRows[workspace] = row
    }

    func selectWorkspace(_ name: String) {
        guard let workspace = workspaces[name], let stack = workspaceStack else { return }
        workspace.pageName.withCString { stack.setVisibleChild(name: $0) }
        selectedWorkspaceName = name
        for (rowName, row) in workspaceRows {
            if rowName == name {
                row.add(cssClass: "suggested-action")
            } else {
                row.remove(cssClass: "suggested-action")
            }
        }
        focus(paneID: workspace.focusedPaneID)
    }
}

nonisolated(unsafe) private var retainedState: ApplicationState?

private func buildWindow(for application: ApplicationRef) {
    guard let state = ApplicationState() else {
        fatalError("Ghostty runtime initialization failed")
    }
    retainedState = state

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

    let groupLabel = LabelRef(str: "LOCAL")
    groupLabel.xalign = 0
    groupLabel.add(cssClass: "aw-group-label")
    groupLabel.setMarginTop(margin: 18)
    sidebar.append(child: groupLabel)

    let directory = FileManager.default.currentDirectoryPath
    let developmentPrimaryID = UUID()
    let developmentSecondaryID = UUID()
    let reviewPrimaryID = UUID()
    guard let developmentPrimary = state.makeSurface(
        paneID: developmentPrimaryID,
        workspaceName: "Development",
        workingDirectory: directory,
        accessibleLabel: "Development primary terminal",
        accessibleDescription: "First terminal pane in the Development workspace"
    ), let developmentSecondary = state.makeSurface(
        paneID: developmentSecondaryID,
        workspaceName: "Development",
        workingDirectory: directory,
        accessibleLabel: "Development secondary terminal",
        accessibleDescription: "Second terminal pane in the Development workspace"
    ), let reviewPrimary = state.makeSurface(
        paneID: reviewPrimaryID,
        workspaceName: "Review",
        workingDirectory: directory,
        accessibleLabel: "Review primary terminal",
        accessibleDescription: "Terminal pane in the Review workspace"
    ) else {
        fatalError("Ghostty terminal surface initialization failed")
    }

    let stack = StackRef()
    stack.setHexpand(expand: true)
    stack.setVexpand(expand: true)
    stack.set(hhomogeneous: true)
    stack.set(vhomogeneous: true)

    let developmentPanes = PanedRef(orientation: .horizontal)
    developmentPanes.set(position: 580)
    developmentPanes.setWideHandle(wide: true)
    developmentPanes.setStart(child: developmentPrimary.widget)
    developmentPanes.setEnd(child: developmentSecondary.widget)
    _ = stack.addNamed(child: developmentPanes, name: "development")

    let reviewPage = BoxRef(orientation: .vertical, spacing: 0)
    reviewPage.append(child: reviewPrimary.widget)
    _ = stack.addNamed(child: reviewPage, name: "review")

    let workspaceDefinitions: [(String, String, WidgetRef, [TerminalSurface], UUID, TerminalSurface)] = [
        ("Development", "development", WidgetRef(developmentPanes), [developmentPrimary, developmentSecondary], developmentPrimaryID, developmentPrimary),
        ("Review", "review", WidgetRef(reviewPage), [reviewPrimary], reviewPrimaryID, reviewPrimary),
    ]
    for (title, pageName, page, workspaceSurfaces, workspaceFocusID, workspaceFocus) in workspaceDefinitions {
        let row = ButtonRef(label: title)
        row.add(cssClass: "aw-workspace-row")
        row.setHalign(align: .fill)
        row.setMarginTop(margin: 8)
        row.setMarginBottom(margin: 8)
        row.onClicked { [weak state] _ in
            state?.selectWorkspace(title)
        }
        sidebar.append(child: row)
        state.install(
            stack: stack,
            workspace: title,
            pageName: pageName,
            root: page,
            surfaces: workspaceSurfaces,
            focusedPaneID: workspaceFocusID,
            focusedSurface: workspaceFocus,
            row: row
        )
    }

    root.append(child: sidebar)
    root.append(child: stack)
    window.set(child: root)
    window.present()
    state.selectWorkspace("Development")
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
