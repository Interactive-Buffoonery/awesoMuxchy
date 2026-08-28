import AwesoMuxCore
import AwesoMuxTerminal
import CGtk
import Foundation
import GIO
import GLib
import Gtk
import Pango

private final class FocusedPanePathBar {
    let root = BoxRef(orientation: .horizontal, spacing: 8)
    private let project = LabelRef(str: "")
    private let path = LabelRef(str: "")
    private let pane = LabelRef(str: "")

    init() {
        root.add(cssClass: "aw-pathbar")
        root.setMarginStart(margin: 12)
        root.setMarginEnd(margin: 12)
        let folder = ImageRef(iconName: "folder-symbolic")
        folder.add(cssClass: "aw-path-project")
        root.append(child: folder)
        project.add(cssClass: "aw-path-project")
        project.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
        project.setMaxWidthChars(nChars: 28)
        root.append(child: project)
        let chevron = LabelRef(str: "›")
        chevron.add(cssClass: "aw-path-muted")
        root.append(child: chevron)
        path.add(cssClass: "aw-path-location")
        path.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        path.setHexpand(expand: true)
        path.xalign = 0
        root.append(child: path)
        pane.add(cssClass: "aw-path-muted")
        root.append(child: pane)
    }

    func update(_ context: FocusedPaneContext, ordinal: Int, count: Int) {
        project.label = context.project
        path.label = context.path
        path.setTooltip(text: context.copyPath)
        pane.label = count > 1 ? "Pane \(ordinal) of \(count)" : ""
    }
}

private final class ApplicationState {
    private final class WorkspaceRuntime {
        let groupID: UUID
        let pageName: String
        let pathBar: FocusedPanePathBar
        var focusedPaneID: UUID
        var focusedSurface: TerminalSurface

        init(groupID: UUID, pageName: String, pathBar: FocusedPanePathBar,
             focusedPaneID: UUID, focusedSurface: TerminalSurface) {
            self.groupID = groupID
            self.pageName = pageName
            self.pathBar = pathBar
            self.focusedPaneID = focusedPaneID
            self.focusedSurface = focusedSurface
        }
    }

    let terminalRuntime: TerminalRuntime
    private(set) var snapshot: SessionSnapshot
    private let store: SessionStore
    private(set) var isPersistencePaused = false
    private let styles = CSSProvider(from: """
      .aw-root,.aw-content{background:#1e1e2e;}.aw-titlebar{min-height:38px;background:#11111b;border-bottom:1px solid #313244;}
      .aw-brand{min-width:188px;color:#cdd6f4;background:#181825;border-right:1px solid #313244;font-size:13px;font-weight:700;}
      .aw-window-title{color:#a6adc8;font-size:12px;font-weight:600;}.aw-sidebar{min-width:188px;background:#181825;border-right:1px solid #313244;}
      searchentry.aw-search entry{min-height:30px;color:#cdd6f4;background:#313244;border:1px solid #45475a;border-radius:7px;font-size:11px;}
      button.aw-add{min-width:30px;min-height:30px;padding:0;color:#a6adc8;background:#313244;border:1px solid #45475a;border-radius:7px;font-size:18px;}
      button.aw-add:hover{color:#cdd6f4;background:#3a3b4d;}button.aw-group{min-height:22px;padding:0 4px;color:#7f849c;background:transparent;border:0;font-family:monospace;font-size:10px;font-weight:700;letter-spacing:1px;}
      button.aw-group:hover{color:#a6adc8;background:transparent;}.aw-count{color:#6c7086;font-size:10px;}.aw-marker{font-size:9px;}
      .aw-mauve{color:#cba6f7;}.aw-peach{color:#fab387;}.aw-green{color:#a6e3a1;}.aw-teal{color:#94e2d5;}.aw-blue{color:#89b4fa;}.aw-pink{color:#f5c2e7;}.aw-yellow{color:#f9e2af;}.aw-red{color:#f38ba8;}.aw-gray{color:#9399b2;}.aw-sky{color:#89dceb;}.aw-lavender{color:#b4befe;}
      button.aw-row{min-height:48px;padding:7px 8px;color:#bac2de;background:transparent;border:1px solid transparent;border-radius:8px;}
      button.aw-row:hover{background:rgba(205,214,244,.06);}button.aw-row:checked{color:#cdd6f4;background:#313244;border-color:rgba(205,214,244,.14);box-shadow:inset 3px 0 #89b4fa;}
      .aw-shell{min-width:32px;min-height:32px;color:#89b4fa;background:#252538;border:1px solid #45475a;border-radius:7px;font-family:monospace;font-size:11px;font-weight:700;}
      .aw-row-title{color:#cdd6f4;font-size:12px;font-weight:600;}.aw-row-meta{color:#7f849c;font-family:monospace;font-size:10px;}
      .aw-sidebar-footer{min-height:38px;color:#7f849c;background:#181825;border-top:1px solid #313244;font-family:monospace;font-size:10px;}
      .aw-pathbar{min-height:38px;color:#a6adc8;background:#181825;border-top:1px solid #313244;font-family:monospace;font-size:11px;}
      .aw-path-project{color:#cdd6f4;font-weight:700;}.aw-path-location{color:#a6adc8;}.aw-path-muted{color:#6c7086;}
    """)
    var surfaces: [TerminalSurface] = []
    private(set) var focusedSurface: TerminalSurface?
    private(set) var focusedPaneID: UUID?
    private var surfacesByPane: [UUID: TerminalSurface] = [:]
    private var workspaceByPane: [UUID: UUID] = [:]
    private var runtimes: [UUID: WorkspaceRuntime] = [:]
    private var rows: [UUID: ToggleButtonRef] = [:]
    private var metadata: [UUID: LabelRef] = [:]
    private var searchText: [UUID: String] = [:]
    private var workspaceIDsByGroup: [UUID: [UUID]] = [:]
    private var groupRoots: [UUID: BoxRef] = [:]
    private var groupBodies: [UUID: BoxRef] = [:]
    private var groupChevrons: [UUID: LabelRef] = [:]
    private var groupCounts: [UUID: LabelRef] = [:]
    private var groupNames: [UUID: String] = [:]
    private var stack: StackRef?
    private var title: LabelRef?
    private var context = FocusedPaneContextCoordinator()
    private var actions: [GIO.SimpleAction] = []
    private var menu: GIO.Menu?

    init?(snapshot: SessionSnapshot, store: SessionStore) {
        guard let runtime = TerminalRuntime() else { return nil }
        terminalRuntime = runtime
        self.snapshot = snapshot
        self.store = store
    }

    func installStyles(on widget: WidgetRef) {
        gtk_style_context_add_provider_for_display(widget.getDisplay().display_ptr,
            styles.styleProvider.style_provider_ptr, UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
    }

    func attach(stack: StackRef, title: LabelRef) { self.stack = stack; self.title = title }

    func makeSurface(pane: PaneSnapshot, workspaceID: UUID, label: String, description: String) -> TerminalSurface? {
        guard let surface = terminalRuntime.makeSurface(workingDirectory: pane.workingDirectory,
            accessibleLabel: label, accessibleDescription: description,
            onFocusChanged: { [weak self] focused in if focused { self?.terminalFocused(pane.id) } }) else { return nil }
        surfaces.append(surface); surfacesByPane[pane.id] = surface; workspaceByPane[pane.id] = workspaceID
        return surface
    }

    func surface(for paneID: UUID) -> TerminalSurface? { surfacesByPane[paneID] }

    private func terminalFocused(_ paneID: UUID) {
        guard let surface = surfacesByPane[paneID], let workspaceID = workspaceByPane[paneID],
              let runtime = runtimes[workspaceID] else { return }
        let changed = snapshot.workspace(id: workspaceID)?.focusedPaneID != paneID
        if changed { try? snapshot.focusPane(paneID, in: workspaceID) }
        runtime.focusedPaneID = paneID; runtime.focusedSurface = surface
        focusedPaneID = paneID; focusedSurface = surface
        updateChrome(workspaceID)
        if changed { persist() }
    }

    func focus(_ paneID: UUID) {
        guard let surface = surfacesByPane[paneID] else { return }
        terminalFocused(paneID); surface.focus()
    }

    func registerGroup(_ group: SidebarGroupSection, root: BoxRef, body: BoxRef,
                       chevron: LabelRef, count: LabelRef) {
        groupRoots[group.id] = root; groupBodies[group.id] = body; groupChevrons[group.id] = chevron
        groupCounts[group.id] = count
        groupNames[group.id] = group.name.lowercased(); workspaceIDsByGroup[group.id] = group.rows.map(\.id)
        body.set(visible: group.isExpanded)
    }

    func toggleGroup(_ groupID: UUID) {
        guard (try? snapshot.toggleGroupDisclosure(groupID)) != nil,
              let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        groupBodies[groupID]?.set(visible: !group.isCollapsed)
        groupChevrons[groupID]?.label = group.isCollapsed ? "›" : "⌄"
        persist()
    }

    func filter(_ query: String) {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for group in snapshot.groups {
            var any = false
            for id in workspaceIDsByGroup[group.id] ?? [] {
                let match = needle.isEmpty || searchText[id, default: ""].contains(needle)
                rows[id]?.set(visible: match); any = any || match
            }
            let visible = needle.isEmpty || any || groupNames[group.id, default: ""].contains(needle)
            groupRoots[group.id]?.set(visible: visible)
            groupBodies[group.id]?.set(visible: needle.isEmpty ? !group.isCollapsed : visible)
        }
    }

    func install(workspace: WorkspaceSnapshot, groupID: UUID, pageName: String,
                 pathBar: FocusedPanePathBar, focusedSurface: TerminalSurface) {
        runtimes[workspace.id] = WorkspaceRuntime(groupID: groupID, pageName: pageName,
            pathBar: pathBar, focusedPaneID: workspace.focusedPaneID, focusedSurface: focusedSurface)
    }

    func makeRow(workspace: WorkspaceSnapshot, groupID: UUID) -> ToggleButtonRef {
        let row = ToggleButtonRef(); row.add(cssClass: "aw-row"); row.setHalign(align: .fill)
        let groupColor = snapshot.groups.first(where: { $0.id == groupID })?.color ?? .blue
        row.add(cssClass: "aw-\(groupColor.rawValue)")
        let content = BoxRef(orientation: .horizontal, spacing: 10)
        let shell = LabelRef(str: ">_"); shell.add(cssClass: "aw-shell"); shell.setSizeRequest(width: 32, height: 32)
        content.append(child: shell)
        let details = BoxRef(orientation: .vertical, spacing: 2); details.setHexpand(expand: true)
        let name = LabelRef(str: ChromeText.sanitized(workspace.name, limit: 120))
        name.add(cssClass: "aw-row-title"); name.xalign = 0; name.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
        name.setMaxWidthChars(nChars: 13)
        let pane = workspace.layout.pane(id: workspace.focusedPaneID)
        let location = FocusedPaneContext.displayPath(pane?.workingDirectory ?? "", homeDirectory: NSHomeDirectory())
        let suffix = workspace.layout.paneCount > 1 ? "  ·  ▮▮ \(workspace.layout.paneCount)" : ""
        let meta = LabelRef(str: location + suffix); meta.add(cssClass: "aw-row-meta"); meta.xalign = 0
        meta.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        meta.setMaxWidthChars(nChars: 13)
        details.append(child: name); details.append(child: meta); content.append(child: details); row.set(child: content)
        row.onClicked { [weak self] _ in self?.select(workspace.id) }
        rows[workspace.id] = row; metadata[workspace.id] = meta
        searchText[workspace.id] = "\(workspace.name) \(location)".lowercased()
        if !(workspaceIDsByGroup[groupID] ?? []).contains(workspace.id) { workspaceIDsByGroup[groupID, default: []].append(workspace.id) }
        return row
    }

    func select(_ workspaceID: UUID) {
        guard let runtime = runtimes[workspaceID], let stack else { return }
        try? snapshot.selectWorkspace(workspaceID)
        runtime.pageName.withCString { stack.setVisibleChild(name: $0) }
        for (id, row) in rows { row.setActive(isActive: id == workspaceID) }
        title?.label = ChromeText.sanitized(snapshot.workspace(id: workspaceID)?.name ?? "", limit: 120)
        updateChrome(workspaceID); focus(runtime.focusedPaneID); persist()
    }

    private func updateChrome(_ workspaceID: UUID) {
        guard let runtime = runtimes[workspaceID], let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: runtime.focusedPaneID) else { return }
        let identity = context.begin(workspaceID: workspaceID, paneID: pane.id)
        let candidate = FocusedPaneContext.resolve(identity: identity, workingDirectory: pane.workingDirectory)
        guard context.publish(candidate) else { return }
        let ordinal = (workspace.layout.paneIDs.firstIndex(of: pane.id) ?? 0) + 1
        runtime.pathBar.update(candidate, ordinal: ordinal, count: workspace.layout.paneCount)
        let suffix = workspace.layout.paneCount > 1 ? "  ·  ▮▮ \(workspace.layout.paneCount)" : ""
        metadata[workspaceID]?.label = candidate.path + suffix
        searchText[workspaceID] = "\(workspace.name) \(candidate.project) \(candidate.path)".lowercased()
    }

    private func persist() {
        do { try store.save(snapshot); isPersistencePaused = false } catch { isPersistencePaused = true }
    }

    func installCommands(on application: Gtk.ApplicationRef) {
        let implemented: Set<CommandID> = [.newWorkspace, .newWorkspaceInCurrentDirectory,
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane]
        let menu = GIO.Menu()
        for section in [CommandSection.file, .view, .workspace, .pane] {
            let submenu = GIO.Menu()
            for definition in CommandCatalog.definitions where definition.section == section {
                let action = GIO.SimpleAction(name: definition.id.rawValue, parameterType: nil as VariantTypeRef?)
                action.set(enabled: implemented.contains(definition.id))
                action.onActivate { [weak self] _, _ in self?.perform(definition.id) }
                application.add(action: action)
                submenu.append(label: definition.action, detailedAction: "app.\(definition.id.rawValue)")
                if let chord = definition.defaultChord { install(chord, for: definition.id, on: application) }
                actions.append(action)
            }
            menu.appendSubmenu(label: section.rawValue, submenu: submenu)
        }
        application.set(menubar: menu); self.menu = menu
    }

    private func install(_ chord: KeyChord, for command: CommandID, on application: Gtk.ApplicationRef) {
        let modifiers: [(ShortcutModifier, String)] = [(.control,"<Control>"),(.alt,"<Alt>"),(.shift,"<Shift>"),(.superKey,"<Super>")]
        let names = ["/":"slash","[":"bracketleft","]":"bracketright","-":"minus","=":"equal"]
        let accelerator = modifiers.filter { chord.modifiers.contains($0.0) }.map(\.1).joined() + (names[chord.key] ?? chord.key)
        accelerator.withCString { pointer in
            let pointers: [UnsafePointer<CChar>?] = [pointer, nil]
            pointers.withUnsafeBufferPointer { application.setAccelsForAction(detailedActionName: "app.\(command.rawValue)", accels: $0.baseAddress!) }
        }
    }

    private func perform(_ command: CommandID) {
        if command == .newWorkspace || command == .newWorkspaceInCurrentDirectory { createWorkspace(); return }
        guard let selected = snapshot.selectedWorkspaceID, let runtime = runtimes[selected] else { return }
        switch command {
        case .previousWorkspace: selectRelative(-1)
        case .nextWorkspace: selectRelative(1)
        case .previousPane: focusRelative(-1, runtime)
        case .nextPane: focusRelative(1, runtime)
        default: break
        }
    }

    func createWorkspace() {
        let selectedGroup = snapshot.groups.first(where: { group in
            group.workspaces.contains(where: { $0.id == snapshot.selectedWorkspaceID })
        })
        guard let stack, let group = selectedGroup ?? snapshot.groups.first,
              let body = groupBodies[group.id] else { return }
        let directory = snapshot.selectedWorkspace.flatMap { $0.layout.pane(id: $0.focusedPaneID)?.workingDirectory }
            ?? FileManager.default.currentDirectoryPath
        let pane = PaneSnapshot(title: "Primary terminal", workingDirectory: directory)
        let workspace = WorkspaceSnapshot(name: "Untitled Workspace", focusedPaneID: pane.id, layout: .pane(pane))
        guard let surface = makeSurface(pane: pane, workspaceID: workspace.id,
            label: "Untitled Workspace Primary terminal", description: "Terminal pane 1 of 1 in the Untitled Workspace workspace") else { return }
        do { try snapshot.addWorkspace(workspace, toGroup: group.id) } catch {
            surfacesByPane.removeValue(forKey: pane.id)
            workspaceByPane.removeValue(forKey: pane.id)
            surfaces.removeAll { $0 === surface }
            return
        }
        let pathBar = FocusedPanePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
        surface.widget.setVexpand(expand: true); page.append(child: surface.widget); page.append(child: pathBar.root)
        let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
        body.append(child: makeRow(workspace: workspace, groupID: group.id)); body.set(visible: true)
        groupCounts[group.id]?.label = "\(snapshot.groups.first(where: { $0.id == group.id })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        install(workspace: workspace, groupID: group.id, pageName: pageName, pathBar: pathBar, focusedSurface: surface)
        select(workspace.id)
    }

    private func selectRelative(_ offset: Int) {
        guard (try? snapshot.selectRelativeWorkspace(offset: offset)) != nil, let id = snapshot.selectedWorkspaceID else { return }
        select(id)
    }

    private func focusRelative(_ offset: Int, _ runtime: WorkspaceRuntime) {
        guard let workspaceID = snapshot.selectedWorkspaceID,
              (try? snapshot.focusRelativePane(offset: offset, in: workspaceID)) != nil,
              let id = snapshot.workspace(id: workspaceID)?.focusedPaneID else { return }
        focus(id)
    }
}

nonisolated(unsafe) private var retainedState: ApplicationState?

private func initialSnapshot(_ directory: String) -> SessionSnapshot {
    let first = PaneSnapshot(title: "Primary terminal", workingDirectory: directory)
    let second = PaneSnapshot(title: "Secondary terminal", workingDirectory: directory)
    let review = PaneSnapshot(title: "Primary terminal", workingDirectory: directory)
    let development = WorkspaceSnapshot(name: "Development", focusedPaneID: first.id,
        layout: .split(axis: .horizontal, fraction: 0.5, first: .pane(first), second: .pane(second)))
    let reviewWorkspace = WorkspaceSnapshot(name: "Review", focusedPaneID: review.id, layout: .pane(review))
    return SessionSnapshot(selectedWorkspaceID: development.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", color: .blue, workspaces: [development, reviewWorkspace])])
}

private func buildWindow(for application: Gtk.ApplicationRef) {
    let fallback = initialSnapshot(FileManager.default.currentDirectoryPath)
    let paths: SessionProfilePaths
    do { paths = try SessionProfilePaths(profile: "default") } catch { fatalError("Default profile path is invalid") }
    let store = SessionStore(paths: paths)
    let snapshot: SessionSnapshot
    switch try? store.loadRecovering() {
    case let .restored(value), let .recoveredPrevious(value): snapshot = value
    case .missing, .resetAfterQuarantine, .none: snapshot = fallback
    }
    guard let state = ApplicationState(snapshot: snapshot, store: store) else { fatalError("Ghostty runtime initialization failed") }
    retainedState = state; state.installCommands(on: application)

    let window = ApplicationWindowRef(application: application); window.title = "awesoMux"
    window.setDefaultSize(width: 1440, height: 900)
    let root = BoxRef(orientation: .vertical, spacing: 0); root.add(cssClass: "aw-root")
    state.installStyles(on: WidgetRef(root))
    let titlebar = BoxRef(orientation: .horizontal, spacing: 0); titlebar.add(cssClass: "aw-titlebar")
    let brand = LabelRef(str: ">_  awesoMux"); brand.add(cssClass: "aw-brand")
    brand.setSizeRequest(width: SidebarChromeProjection.width, height: 38)
    let title = LabelRef(str: ""); title.add(cssClass: "aw-window-title"); title.setHexpand(expand: true)
    titlebar.append(child: brand); titlebar.append(child: title); root.append(child: titlebar)

    let main = BoxRef(orientation: .horizontal, spacing: 0); main.setVexpand(expand: true)
    let sidebar = BoxRef(orientation: .vertical, spacing: 0); sidebar.add(cssClass: "aw-sidebar")
    sidebar.setSizeRequest(width: SidebarChromeProjection.width, height: -1); sidebar.setHexpand(expand: false)
    let header = BoxRef(orientation: .horizontal, spacing: 6)
    header.setMarginStart(margin: 10); header.setMarginEnd(margin: 10); header.setMarginTop(margin: 10); header.setMarginBottom(margin: 8)
    let search = SearchEntryRef(); search.add(cssClass: "aw-search"); search.setHexpand(expand: true)
    search.setPlaceholder(text: "Search"); search.setSizeRequest(width: 108, height: 30)
    search.setWidthChars(nChars: 8); search.setMaxWidthChars(nChars: 8)
    search.onSearchChanged { [weak state] entry in state?.filter(entry.text ?? "") }
    let add = ButtonRef(label: "+"); add.add(cssClass: "aw-add")
    add.setTooltip(text: "New Workspace in Current Directory"); add.onClicked { [weak state] _ in state?.createWorkspace() }
    header.append(child: search); header.append(child: add); sidebar.append(child: header)

    let groups = BoxRef(orientation: .vertical, spacing: 14)
    groups.setMarginStart(margin: 10); groups.setMarginEnd(margin: 10); groups.setMarginTop(margin: 6); groups.setMarginBottom(margin: 8)
    let scroller = ScrolledWindowRef(); scroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
    scroller.setVexpand(expand: true); scroller.set(child: groups); sidebar.append(child: scroller)
    let footer = BoxRef(orientation: .horizontal, spacing: 0); footer.add(cssClass: "aw-sidebar-footer")
    footer.setMarginStart(margin: 10); footer.setMarginEnd(margin: 10)
    let spacer = BoxRef(orientation: .horizontal, spacing: 0); spacer.setHexpand(expand: true)
    footer.append(child: spacer); footer.append(child: LabelRef(str: "0 agents")); sidebar.append(child: footer)

    let stack = StackRef(); stack.add(cssClass: "aw-content"); stack.setHexpand(expand: true); stack.setVexpand(expand: true)
    stack.set(hhomogeneous: true); stack.set(vhomogeneous: true); state.attach(stack: stack, title: title)

    func buildLayout(_ layout: PaneLayout, workspace: WorkspaceSnapshot) -> (WidgetRef, [TerminalSurface])? {
        switch layout {
        case let .pane(pane):
            let ordinal = (workspace.layout.paneIDs.firstIndex(of: pane.id) ?? 0) + 1
            guard let surface = state.makeSurface(pane: pane, workspaceID: workspace.id,
                label: "\(workspace.name) \(pane.title)",
                description: "Terminal pane \(ordinal) of \(workspace.layout.paneCount) in the \(workspace.name) workspace") else { return nil }
            surface.widget.setHexpand(expand: true); surface.widget.setVexpand(expand: true)
            return (surface.widget, [surface])
        case let .split(axis, fraction, first, second):
            guard let one = buildLayout(first, workspace: workspace), let two = buildLayout(second, workspace: workspace) else { return nil }
            let paned = PanedRef(orientation: axis == .horizontal ? .horizontal : .vertical)
            paned.set(position: Int((axis == .horizontal ? 1240.0 : 820.0) * min(max(fraction, 0.1), 0.9)))
            paned.setWideHandle(wide: true); paned.setStart(child: one.0); paned.setEnd(child: two.0)
            return (WidgetRef(paned), one.1 + two.1)
        }
    }

    for projection in SidebarChromeProjection(snapshot: snapshot).groups {
        guard let group = snapshot.groups.first(where: { $0.id == projection.id }) else { continue }
        let groupRoot = BoxRef(orientation: .vertical, spacing: 3)
        let disclosure = ButtonRef(); disclosure.add(cssClass: "aw-group"); disclosure.setHalign(align: .fill)
        let disclosureContent = BoxRef(orientation: .horizontal, spacing: 8)
        let chevron = LabelRef(str: projection.isExpanded ? "⌄" : "›")
        let marker = LabelRef(str: "●"); marker.add(cssClass: "aw-marker")
        marker.add(cssClass: "aw-\((projection.color ?? .blue).rawValue)")
        let name = LabelRef(str: projection.name.uppercased()); name.xalign = 0; name.setHexpand(expand: true)
        let count = LabelRef(str: "\(projection.rows.count)"); count.add(cssClass: "aw-count")
        disclosureContent.append(child: chevron); disclosureContent.append(child: marker)
        disclosureContent.append(child: name); disclosureContent.append(child: count); disclosure.set(child: disclosureContent)
        disclosure.onClicked { [weak state] _ in state?.toggleGroup(projection.id) }; groupRoot.append(child: disclosure)
        let body = BoxRef(orientation: .vertical, spacing: 5); groupRoot.append(child: body); groups.append(child: groupRoot)
        state.registerGroup(projection, root: groupRoot, body: body, chevron: chevron, count: count)

        for workspace in group.workspaces where !workspace.isSoftClosed {
            guard let layout = buildLayout(workspace.layout, workspace: workspace),
                  let focused = state.surface(for: workspace.focusedPaneID) else { fatalError("Ghostty terminal surface initialization failed") }
            let pathBar = FocusedPanePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
            page.append(child: layout.0); page.append(child: pathBar.root)
            let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
            body.append(child: state.makeRow(workspace: workspace, groupID: group.id))
            state.install(workspace: workspace, groupID: group.id, pageName: pageName, pathBar: pathBar, focusedSurface: focused)
        }
    }

    main.append(child: sidebar); main.append(child: stack); root.append(child: main)
    window.set(child: root); window.present()
    if let selected = snapshot.selectedWorkspaceID { state.select(selected) }
}

let status = Application.run(id: "com.interactivebuffoonery.awesomux", arguments: CommandLine.arguments,
    activationHandler: buildWindow)
guard let status else { fatalError("Could not create GTK application") }
exit(Int32(status))
