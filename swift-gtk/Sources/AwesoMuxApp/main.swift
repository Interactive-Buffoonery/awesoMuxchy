import AwesoMuxCore
import AwesoMuxTerminal
import CGtk
import Dispatch
import Foundation
import GIO
import GLib
import Gtk
import Pango

private final class GTKMainLoopWork: @unchecked Sendable {
    let action: () -> Void
    init(_ action: @escaping () -> Void) { self.action = action }
}

private func performOnGTKMain(_ action: @escaping () -> Void) {
    let pointer = Unmanaged.passRetained(GTKMainLoopWork(action)).toOpaque()
    _ = GLib.idleAddOnce(function: { data in
        guard let data else { return }
        Unmanaged<GTKMainLoopWork>.fromOpaque(data).takeRetainedValue().action()
    }, data: pointer)
}

private final class ApplicationState: @unchecked Sendable {
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
    private let preferencesStore: AppPreferencesStore
    private var preferences: AppPreferences
    private(set) var isPersistencePaused = false
    private let styles = CSSProvider(from: """
      .aw-root,.aw-content{background:#1e1e2e;}.aw-titlebar{min-height:38px;background:#11111b;border-bottom:1px solid #313244;}
      .aw-brand{min-width:60px;color:#cdd6f4;background:#181825;border-right:1px solid #313244;font-size:13px;font-weight:700;}
      .aw-window-title{color:#a6adc8;font-size:12px;font-weight:600;}.aw-sidebar{background:#181825;border-right:1px solid #313244;}
      searchentry.aw-search{min-height:30px;color:#cdd6f4;background-color:#313244;background-image:none;border:1px solid #45475a;border-radius:7px;font-size:11px;box-shadow:none;}
      searchentry.aw-search > text,.aw-search-text{color:#cdd6f4;background-color:#313244;background-image:none;border-color:#45475a;border-radius:7px;box-shadow:none;caret-color:#cdd6f4;}
      button.aw-add{min-width:30px;min-height:30px;padding:0;color:#a6adc8;background:#313244;border:1px solid #45475a;border-radius:7px;font-size:18px;}
      button.aw-rail-control,button.aw-rail-row{min-width:40px;min-height:40px;padding:0;color:#a6adc8;background:transparent;border:1px solid transparent;border-radius:8px;font-family:monospace;font-size:12px;font-weight:700;}
      button.aw-rail-control:hover,button.aw-rail-row:hover{color:#cdd6f4;background:rgba(205,214,244,.07);}button.aw-rail-row:checked{color:#cdd6f4;background:#313244;border-color:rgba(137,180,250,.55);box-shadow:inset 3px 0 #89b4fa;}
      .aw-rail{min-width:60px;background:#181825;border-right:1px solid #313244;}.aw-rail-footer{min-height:38px;border-top:1px solid #313244;}
      button.aw-add:hover{color:#cdd6f4;background:#3a3b4d;}button.aw-group{min-height:22px;padding:0 4px;color:#7f849c;background:transparent;border:0;font-family:monospace;font-size:10px;font-weight:700;letter-spacing:1px;}
      button.aw-group:hover{color:#a6adc8;background:transparent;}.aw-count{color:#6c7086;font-size:10px;}.aw-marker{font-size:9px;}
      .aw-mauve{color:#cba6f7;}.aw-peach{color:#fab387;}.aw-green{color:#a6e3a1;}.aw-teal{color:#94e2d5;}.aw-blue{color:#89b4fa;}.aw-pink{color:#f5c2e7;}.aw-yellow{color:#f9e2af;}.aw-red{color:#f38ba8;}.aw-gray{color:#9399b2;}.aw-sky{color:#89dceb;}.aw-lavender{color:#b4befe;}
      button.aw-row{min-height:48px;padding:7px 8px;color:#bac2de;background:transparent;border:1px solid transparent;border-radius:8px;}
      button.aw-row:hover{background:rgba(205,214,244,.06);}button.aw-row:checked{color:#cdd6f4;background:#313244;border-color:rgba(205,214,244,.14);box-shadow:inset 3px 0 #89b4fa;}
      .aw-shell{min-width:32px;min-height:32px;color:#89b4fa;background:#252538;border:1px solid #45475a;border-radius:7px;font-family:monospace;font-size:11px;font-weight:700;}
      .aw-row-title{color:#cdd6f4;font-size:12px;font-weight:600;}.aw-row-meta{color:#7f849c;font-family:monospace;font-size:10px;}
      .aw-sidebar-footer{min-height:38px;color:#7f849c;background:#181825;border-top:1px solid #313244;font-family:monospace;font-size:10px;}
      .aw-pathbar{min-height:38px;color:#a6adc8;background:#181825;border-top:1px solid rgba(205,214,244,.14);font-family:"Noto Sans Mono","DejaVu Sans Mono",monospace;font-size:11px;}
      .aw-path-project{color:#a6adc8;font-weight:600;}.aw-path-location{color:#7f849c;font-weight:400;}.aw-path-hierarchy{color:#6c7086;font-size:8px;font-weight:600;}.aw-path-chevron{color:#6c7086;font-size:8px;font-weight:700;}
      separator.aw-path-divider{min-width:1px;min-height:12px;background:rgba(108,112,134,.65);}
      menubutton.aw-path-menu>button{min-height:24px;padding:2px 6px;background:rgba(203,166,247,.08);border:1px solid rgba(203,166,247,.38);border-radius:5px;box-shadow:none;}
      menubutton.aw-path-menu>button:hover{background:rgba(203,166,247,.18);}
      menubutton.aw-chip>button,.aw-chip-dirty,.aw-chip-remote{min-height:20px;padding:3px 7px;border:1px solid transparent;border-radius:5px;box-shadow:none;font-family:"Noto Sans Mono","DejaVu Sans Mono",monospace;font-size:10px;font-weight:500;}
      .aw-chip-icon{font-size:11px;font-weight:600;}.aw-chip-hint{opacity:.65;}
      menubutton.aw-chip-branch>button{color:#fab387;background:rgba(250,179,135,.10);border-color:rgba(250,179,135,.38);} .aw-chip-dirty{color:#f9e2af;background:rgba(249,226,175,.12);border-color:rgba(249,226,175,.40);}
      menubutton.aw-chip-pr>button{color:#a6e3a1;background:rgba(166,227,161,.10);border-color:rgba(166,227,161,.38);} menubutton.aw-chip-pr-draft>button{color:#cba6f7;background:rgba(203,166,247,.10);border-color:rgba(203,166,247,.38);} menubutton.aw-chip-pr-review>button{color:#89dceb;background:rgba(137,220,235,.10);border-color:rgba(137,220,235,.38);}
      menubutton.aw-chip-ci>button{color:#89dceb;background:rgba(137,220,235,.10);border-color:rgba(137,220,235,.38);} menubutton.aw-chip-ci-failing>button{color:#f38ba8;background:rgba(243,139,168,.10);border-color:rgba(243,139,168,.38);} .aw-chip-remote{color:#89dceb;background:rgba(137,220,235,.10);border-color:rgba(137,220,235,.38);}
      popover contents{background:#252538;border:1px solid #45475a;border-radius:9px;box-shadow:0 8px 24px rgba(0,0,0,.35);}
      .aw-popover{min-width:190px;}.aw-menu-title{padding:5px 7px;color:#cdd6f4;font-size:13px;font-weight:700;}
      .aw-menu-heading{padding:5px 7px 2px;color:#7f849c;font-family:monospace;font-size:9px;font-weight:700;letter-spacing:1px;}
      button.aw-menu-row{min-height:30px;padding:4px 7px;color:#cdd6f4;background:transparent;border:0;border-radius:5px;font-size:11px;}
      button.aw-menu-row:hover{background:#3a3b4d;}.aw-menu-disabled{padding:7px;color:#6c7086;font-size:10px;}
      button.aw-row.aw-search-current{outline:2px solid #89b4fa;outline-offset:-2px;}
      .aw-no-matches{padding:14px;background:rgba(250,179,135,.10);border:1px dashed rgba(250,179,135,.35);border-radius:9px;}.aw-no-matches-title{color:#fab387;font-family:monospace;font-size:10px;font-weight:700;letter-spacing:1px;}.aw-no-matches-copy{color:#7f849c;font-size:11px;}button.aw-clear-search{min-height:24px;padding:4px 9px;color:#11111b;background:#fab387;border:0;border-radius:12px;font-family:monospace;font-size:10px;font-weight:700;}
      menubutton.aw-icon-menu>button,button.aw-icon-button,button.aw-agent-total{min-width:22px;min-height:22px;padding:0;color:#7f849c;background:transparent;border:0;border-radius:5px;}
      menubutton.aw-icon-menu>button:hover,button.aw-icon-button:hover,button.aw-agent-total:hover{color:#cdd6f4;background:rgba(205,214,244,.09);}
      .aw-agent-panel{background:#181825;border-top:1px solid #313244;}.aw-agent-state{padding:1px 4px;font-family:monospace;font-size:9px;font-weight:700;}
      .aw-agent-thinking{color:#cba6f7;}.aw-agent-output{color:#89dceb;}.aw-agent-attention{color:#f38ba8;}
      button.aw-theme-choice{min-height:26px;padding:2px 8px;color:#a6adc8;background:#313244;border:1px solid #45475a;border-radius:5px;font-size:10px;}
      button.aw-theme-choice.aw-selected{color:#11111b;background:#89b4fa;border-color:#89b4fa;font-weight:700;}
      .theme-light.aw-root,.theme-light .aw-content{background:#eff1f5;}.theme-light .aw-titlebar{background:#dce0e8;border-color:#bcc0cc;}
      .theme-light .aw-sidebar,.theme-light .aw-sidebar-footer,.theme-light .aw-pathbar,.theme-light .aw-agent-panel{background:#e6e9ef;border-color:#bcc0cc;}
      .theme-light .aw-brand{color:#4c4f69;background:#dce0e8;border-color:#bcc0cc;}.theme-light .aw-row-title,.theme-light .aw-path-project{color:#4c4f69;}
      .theme-light .aw-row-meta,.theme-light .aw-path-location,.theme-light .aw-window-title{color:#6c6f85;}
    """)
    var surfaces: [TerminalSurface] = []
    private(set) var focusedSurface: TerminalSurface?
    private(set) var focusedPaneID: UUID?
    private var surfacesByPane: [UUID: TerminalSurface] = [:]
    private var workspaceByPane: [UUID: UUID] = [:]
    private var runtimes: [UUID: WorkspaceRuntime] = [:]
    private var rows: [UUID: ToggleButtonRef] = [:]
    private var railRows: [UUID: ToggleButtonRef] = [:]
    private var metadata: [UUID: LabelRef] = [:]
    private var workspaceIDsByGroup: [UUID: [UUID]] = [:]
    private var groupRoots: [UUID: BoxRef] = [:]
    private var groupBodies: [UUID: BoxRef] = [:]
    private var groupChevrons: [UUID: LabelRef] = [:]
    private var groupCounts: [UUID: LabelRef] = [:]
    private var noMatchesRoot: BoxRef?
    private var noMatchesDescription: LabelRef?
    private var sidebarSearchEntry: SearchEntryRef?
    private var searchResultIDs: [UUID] = []
    private var searchResultIndex = 0
    private var stack: StackRef?
    private var title: LabelRef?
    private var rootWidget: BoxRef?
    private var sidebarFooter: SidebarStatusFooter?
    private var sidebarPaned: PanedRef?
    private var sidebarBrand: LabelRef?
    private var sidebarWidget: BoxRef?
    private var expandedSidebarWidget: BoxRef?
    private var collapsedSidebarWidget: BoxRef?
    private var sidebarRailRows: BoxRef?
    private var isApplyingSidebarWidth = false
    private var context = FocusedPaneContextCoordinator()
    private var actions: [GIO.SimpleAction] = []
    private var menu: GIO.Menu?

    init?(snapshot: SessionSnapshot, store: SessionStore, preferencesStore: AppPreferencesStore) {
        guard let runtime = TerminalRuntime() else { return nil }
        terminalRuntime = runtime
        self.snapshot = snapshot
        self.store = store
        self.preferencesStore = preferencesStore
        preferences = preferencesStore.load()
    }

    func installStyles(on widget: WidgetRef) {
        gtk_style_context_add_provider_for_display(widget.getDisplay().display_ptr,
            styles.styleProvider.style_provider_ptr, UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
    }

    func attach(stack: StackRef, title: LabelRef, root: BoxRef, sidebarFooter: SidebarStatusFooter) {
        self.stack = stack; self.title = title; rootWidget = root; self.sidebarFooter = sidebarFooter
        applyTheme(); sidebarFooter.update(AgentFooterSummary(snapshot: snapshot))
    }

    func attachSidebar(
        paned: PanedRef,
        brand: LabelRef,
        sidebar: BoxRef,
        expanded: BoxRef,
        collapsed: BoxRef,
        railRows: BoxRef
    ) {
        sidebarPaned = paned
        sidebarBrand = brand
        sidebarWidget = sidebar
        expandedSidebarWidget = expanded
        collapsedSidebarWidget = collapsed
        sidebarRailRows = railRows
        paned.setResizeStartChild(resize: false)
        paned.setShrinkStartChild(resize: true)
        paned.setResizeEndChild(resize: true)
        paned.setShrinkEndChild(resize: false)
        applySidebarWidth(preferences.sidebarWidth, persist: false)
        updateSidebarVisibility()
        _ = paned.onNotifyPosition { [weak self] paned, _ in
            self?.sidebarPositionChanged(paned.getPosition())
        }
    }

    private func sidebarPositionChanged(_ proposedWidth: Int) {
        guard !isApplyingSidebarWidth else { return }
        let committed = SidebarWidthPolicy.committedWidth(for: Double(proposedWidth))
        if committed != proposedWidth {
            applySidebarWidth(committed, persist: true)
            return
        }
        preferences.lastExpandedSidebarWidth = SidebarWidthPolicy.updatedLastNonCollapsedWidth(
            currentWidth: Double(committed),
            previousLastNonCollapsedWidth: Double(preferences.lastExpandedSidebarWidth)
        )
        preferences.sidebarWidth = committed
        updateSidebarGeometry(committed)
        try? preferencesStore.save(preferences)
    }

    private func applySidebarWidth(_ width: Int, persist: Bool) {
        let committed = SidebarWidthPolicy.committedWidth(for: Double(width))
        isApplyingSidebarWidth = true
        sidebarPaned?.set(position: committed)
        isApplyingSidebarWidth = false
        preferences.sidebarWidth = committed
        preferences.lastExpandedSidebarWidth = SidebarWidthPolicy.updatedLastNonCollapsedWidth(
            currentWidth: Double(committed),
            previousLastNonCollapsedWidth: Double(preferences.lastExpandedSidebarWidth)
        )
        updateSidebarGeometry(committed)
        if persist { try? preferencesStore.save(preferences) }
    }

    private func toggleSidebarWidth() {
        let target = SidebarWidthPolicy.toggleWidth(
            currentWidth: Double(preferences.sidebarWidth),
            lastNonCollapsedWidth: Double(preferences.lastExpandedSidebarWidth)
        )
        applySidebarWidth(target, persist: true)
    }

    private func toggleSidebarVisibility() {
        preferences.isSidebarHidden.toggle()
        if preferences.isSidebarHidden { focusedSurface?.focus() }
        updateSidebarVisibility()
        try? preferencesStore.save(preferences)
    }

    private func updateSidebarVisibility() {
        sidebarWidget?.set(visible: !preferences.isSidebarHidden)
        sidebarBrand?.set(visible: !preferences.isSidebarHidden)
    }

    private func updateSidebarGeometry(_ width: Int) {
        sidebarBrand?.setSizeRequest(width: width, height: 38)
        sidebarBrand?.label = width < SidebarWidthPolicy.railThreshold ? ">_" : ">_  awesoMux"
        sidebarWidget?.setSizeRequest(width: SidebarWidthPolicy.collapsedWidth, height: -1)
        if width < SidebarWidthPolicy.railThreshold {
            expandedSidebarWidget?.set(visible: false)
            collapsedSidebarWidget?.set(visible: true)
        } else {
            collapsedSidebarWidget?.set(visible: false)
            expandedSidebarWidget?.set(visible: true)
        }
    }

    func makePathBar() -> FocusedPanePathBar {
        FocusedPanePathBar(actions: .init(
            copy: { [weak self] in self?.copy($0) }, reveal: { [weak self] in self?.reveal($0) },
            openEditor: { [weak self] in self?.openEditor($0, path: $1) },
            insertCommand: { [weak self] in self?.focusedSurface?.send(text: $0) },
            openURL: { [weak self] in self?.openURL($0) }
        ))
    }

    func makeSidebarFooter() -> SidebarStatusFooter {
        SidebarStatusFooter(preferences: preferences, actions: .init(
            selectPane: { [weak self] workspace, pane in self?.select(workspace); self?.focus(pane) },
            updatePreferences: { [weak self] in self?.updatePreferences($0) },
            showWelcome: { [weak self] in self?.showInformation(title: "Welcome to awesoMux", body: "Workspaces live in the sidebar, splits stay inside one native window, and the focused pane owns the Git and agent context shown in the footer.") },
            reportBug: { [weak self] in self?.openFeedback() }, suggestFeature: { [weak self] in self?.openFeedback() },
            showSettings: { [weak self] in self?.showInformation(title: "Settings", body: "Theme and notification controls are available in Quick settings. More application settings will appear here as their features land on Linux.") }
        ))
    }

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
        workspaceIDsByGroup[group.id] = group.rows.map(\.id)
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
        let projection = SidebarSearchProjection.project(snapshot: snapshot, query: query)
        searchResultIDs = projection.isFiltering ? projection.orderedWorkspaceIDs : []
        searchResultIndex = 0
        updateSearchResultHighlight()
        let visibleWorkspaceIDs = Set(projection.orderedWorkspaceIDs)
        let visibleGroupIDs = Set(projection.groups.map(\.id))
        for group in snapshot.groups {
            for id in workspaceIDsByGroup[group.id] ?? [] {
                rows[id]?.set(visible: !projection.isFiltering || visibleWorkspaceIDs.contains(id))
            }
            groupRoots[group.id]?.set(visible: !projection.isFiltering || visibleGroupIDs.contains(group.id))
            groupBodies[group.id]?.set(visible: projection.isFiltering ? visibleGroupIDs.contains(group.id) : !group.isCollapsed)
        }
        let showsNoMatches = projection.isFiltering && !projection.hasMatches
        noMatchesRoot?.set(visible: showsNoMatches)
        if showsNoMatches {
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            noMatchesDescription?.label = "Nothing matched \"\(ChromeText.sanitized(normalized, limit: 120))\"."
        }
    }

    func attachSearch(entry: SearchEntryRef, noMatches: BoxRef, description: LabelRef) {
        sidebarSearchEntry = entry
        noMatchesRoot = noMatches
        noMatchesDescription = description
    }

    func clearSidebarSearch() {
        sidebarSearchEntry?.text = ""
        filter("")
    }

    private func updateSearchResultHighlight() {
        for row in rows.values { row.remove(cssClass: "aw-search-current") }
        guard searchResultIDs.indices.contains(searchResultIndex) else { return }
        rows[searchResultIDs[searchResultIndex]]?.add(cssClass: "aw-search-current")
    }

    func handleSidebarSearchKey(_ keyval: UInt) -> Bool {
        switch keyval {
        case UInt(GDK_KEY_Escape):
            if !(sidebarSearchEntry?.text ?? "").isEmpty {
                clearSidebarSearch()
            } else {
                focusedSurface?.focus()
            }
            return true
        case UInt(GDK_KEY_Down):
            guard !searchResultIDs.isEmpty else { return true }
            searchResultIndex = min(searchResultIndex + 1, searchResultIDs.count - 1)
            updateSearchResultHighlight()
            return true
        case UInt(GDK_KEY_Up):
            guard !searchResultIDs.isEmpty else { return true }
            searchResultIndex = max(searchResultIndex - 1, 0)
            updateSearchResultHighlight()
            return true
        case UInt(GDK_KEY_Return), UInt(GDK_KEY_KP_Enter):
            guard searchResultIDs.indices.contains(searchResultIndex) else { return true }
            select(searchResultIDs[searchResultIndex])
            return true
        default:
            return false
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
        if !(workspaceIDsByGroup[groupID] ?? []).contains(workspace.id) { workspaceIDsByGroup[groupID, default: []].append(workspace.id) }
        return row
    }

    func makeRailRow(workspace: WorkspaceSnapshot) -> ToggleButtonRef {
        let button = ToggleButtonRef()
        button.set(iconName: "utilities-terminal-symbolic")
        button.add(cssClass: "aw-rail-row")
        button.setSizeRequest(width: 40, height: 40)
        button.setTooltip(text: ChromeText.sanitized(workspace.name, limit: 120))
        button.onClicked { [weak self] _ in self?.select(workspace.id) }
        railRows[workspace.id] = button
        return button
    }

    func select(_ workspaceID: UUID) {
        guard let runtime = runtimes[workspaceID], let stack else { return }
        try? snapshot.selectWorkspace(workspaceID)
        runtime.pageName.withCString { stack.setVisibleChild(name: $0) }
        for (id, row) in rows { row.setActive(isActive: id == workspaceID) }
        for (id, row) in railRows { row.setActive(isActive: id == workspaceID) }
        title?.label = ChromeText.sanitized(snapshot.workspace(id: workspaceID)?.name ?? "", limit: 120)
        updateChrome(workspaceID); focus(runtime.focusedPaneID); persist()
    }

    private func updateChrome(_ workspaceID: UUID) {
        guard let runtime = runtimes[workspaceID], let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: runtime.focusedPaneID) else { return }
        let identity = context.begin(workspaceID: workspaceID, paneID: pane.id)
        let candidate = FocusedPaneContext.resolve(identity: identity, workingDirectory: pane.workingDirectory)
        guard context.publish(candidate) else { return }
        let isRemote = pane.ownership != .local
        runtime.pathBar.updatePreview(candidate, isRemote: isRemote)
        if !isRemote {
            let pathBar = runtime.pathBar
            DispatchQueue.global(qos: .utility).async {
                let details = TerminalFooterResolver().resolve(candidate)
                performOnGTKMain { pathBar.updateDetails(details) }
            }
        }
        let suffix = workspace.layout.paneCount > 1 ? "  ·  ▮▮ \(workspace.layout.paneCount)" : ""
        metadata[workspaceID]?.label = candidate.path + suffix
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
    }

    private func copy(_ text: String) {
        rootWidget?.getClipboard()?.set(text: text)
    }

    private func reveal(_ path: String) {
        openURL(URL(fileURLWithPath: path, isDirectory: true))
    }

    private func openURL(_ url: URL) {
        guard ["https", "file"].contains(url.scheme?.lowercased() ?? "") else { return }
        _ = try? GIO.appInfoLaunchDefaultFor(uri: url.absoluteString, context: nil as GIO.AppLaunchContextRef?)
    }

    private func openEditor(_ editor: InstalledEditor, path: String) {
        let canonical = URL(fileURLWithPath: path, isDirectory: true).resolvingSymlinksInPath().standardized.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.isExecutableFile(atPath: editor.executable),
              FileManager.default.fileExists(atPath: canonical, isDirectory: &isDirectory), isDirectory.boolValue else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: editor.executable)
            process.arguments = [canonical]
            process.currentDirectoryURL = URL(fileURLWithPath: canonical, isDirectory: true)
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
        }
    }

    private func updatePreferences(_ value: AppPreferences) {
        preferences = value
        try? preferencesStore.save(value)
        applyTheme()
    }

    private func applyTheme() {
        guard let rootWidget else { return }
        for theme in AppTheme.allCases { rootWidget.remove(cssClass: "theme-\(theme.rawValue.lowercased())") }
        rootWidget.add(cssClass: "theme-\(preferences.theme.rawValue.lowercased())")
    }

    private func openFeedback() {
        openURL(URL(string: "https://github.com/Interactive-Buffoonery/awesomux/issues/new/choose")!)
    }

    private func showInformation(title: String, body: String) {
        let window = WindowRef()
        window.title = title
        window.setDefaultSize(width: 520, height: 220)
        let box = BoxRef(orientation: .vertical, spacing: 14)
        box.setMarginStart(margin: 24); box.setMarginEnd(margin: 24)
        box.setMarginTop(margin: 24); box.setMarginBottom(margin: 24)
        let heading = LabelRef(str: title); heading.add(cssClass: "aw-menu-title"); heading.xalign = 0
        let message = LabelRef(str: body); message.set(wrap: true); message.xalign = 0; message.setVexpand(expand: true)
        let close = ButtonRef(label: "Done"); close.setHalign(align: .end)
        close.onClicked { [window] _ in window.close() }
        box.append(child: heading); box.append(child: message); box.append(child: close)
        window.set(child: box); window.present()
    }

    func showCommandPalette() {
        let window = WindowRef()
        window.title = "Command Palette"
        window.setDefaultSize(width: 520, height: 420)
        let root = BoxRef(orientation: .vertical, spacing: 8)
        root.setMarginStart(margin: 16); root.setMarginEnd(margin: 16)
        root.setMarginTop(margin: 16); root.setMarginBottom(margin: 16)
        let search = SearchEntryRef(); search.setPlaceholder(text: "Search workspaces and actions...")
        let results = BoxRef(orientation: .vertical, spacing: 3)
        let implemented: Set<CommandID> = [.newWorkspace, .newWorkspaceInCurrentDirectory,
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
            .toggleSidebarWidth, .toggleSidebarVisibility]
        var commandRows: [(String, ButtonRef)] = []
        for definition in CommandCatalog.definitions where implemented.contains(definition.id) {
            let button = ButtonRef(label: definition.action)
            button.add(cssClass: "aw-menu-row"); button.setHalign(align: .fill)
            button.onClicked { [weak self, window] _ in
                window.close(); self?.perform(definition.id)
            }
            results.append(child: button)
            commandRows.append((definition.action.lowercased(), button))
        }
        search.onSearchChanged { entry in
            let query = (entry.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            for (title, button) in commandRows { button.set(visible: query.isEmpty || title.contains(query)) }
        }
        let scroller = ScrolledWindowRef(); scroller.setVexpand(expand: true); scroller.set(child: results)
        root.append(child: search); root.append(child: scroller)
        window.set(child: root); window.present()
    }

    private func persist() {
        do { try store.save(snapshot); isPersistencePaused = false } catch { isPersistencePaused = true }
    }

    func installCommands(on application: Gtk.ApplicationRef) {
        let implemented: Set<CommandID> = [.newWorkspace, .newWorkspaceInCurrentDirectory,
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
            .toggleSidebarWidth, .toggleSidebarVisibility]
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
        let names = ["/":"slash","[":"bracketleft","]":"bracketright","-":"minus","=":"equal","\\":"backslash"]
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
        case .toggleSidebarWidth: toggleSidebarWidth()
        case .toggleSidebarVisibility: toggleSidebarVisibility()
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
        let pathBar = makePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
        surface.widget.setVexpand(expand: true); page.append(child: surface.widget); page.append(child: pathBar.root)
        let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
        body.append(child: makeRow(workspace: workspace, groupID: group.id)); body.set(visible: true)
        sidebarRailRows?.append(child: makeRailRow(workspace: workspace))
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
    let preferencesStore = AppPreferencesStore(
        url: paths.snapshotURL.deletingLastPathComponent().appendingPathComponent("preferences.json")
    )
    let snapshot: SessionSnapshot
    switch try? store.loadRecovering() {
    case let .restored(value), let .recoveredPrevious(value): snapshot = value
    case .missing, .resetAfterQuarantine, .none: snapshot = fallback
    }
    guard let state = ApplicationState(snapshot: snapshot, store: store, preferencesStore: preferencesStore) else { fatalError("Ghostty runtime initialization failed") }
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
    sidebar.setSizeRequest(width: SidebarWidthPolicy.collapsedWidth, height: -1); sidebar.setHexpand(expand: false)
    let sidebarModes = BoxRef(orientation: .vertical, spacing: 0)
    sidebarModes.setHexpand(expand: true); sidebarModes.setVexpand(expand: true)
    let expandedSidebar = BoxRef(orientation: .vertical, spacing: 0)
    let header = BoxRef(orientation: .horizontal, spacing: 6)
    header.setMarginStart(margin: 10); header.setMarginEnd(margin: 10); header.setMarginTop(margin: 10); header.setMarginBottom(margin: 8)
    let search = SearchEntryRef(); search.add(cssClass: "aw-search"); search.setHexpand(expand: true)
    search.getFirstChild()?.add(cssClass: "aw-search-text")
    search.setPlaceholder(text: "Search sessions"); search.setSizeRequest(width: 108, height: 30)
    search.setWidthChars(nChars: 8); search.setMaxWidthChars(nChars: 8)
    search.onSearchChanged { [weak state] entry in state?.filter(entry.text ?? "") }
    let add = ButtonRef(label: "+"); add.add(cssClass: "aw-add")
    add.setTooltip(text: "New Workspace in Current Directory"); add.onClicked { [weak state] _ in state?.createWorkspace() }
    header.append(child: search); header.append(child: add); expandedSidebar.append(child: header)

    let groups = BoxRef(orientation: .vertical, spacing: 14)
    groups.setMarginStart(margin: 10); groups.setMarginEnd(margin: 10); groups.setMarginTop(margin: 6); groups.setMarginBottom(margin: 8)
    let scroller = ScrolledWindowRef(); scroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
    let noMatches = BoxRef(orientation: .vertical, spacing: 10); noMatches.add(cssClass: "aw-no-matches")
    let noMatchesTitle = LabelRef(str: "●  NO MATCHES"); noMatchesTitle.add(cssClass: "aw-no-matches-title"); noMatchesTitle.xalign = 0
    let noMatchesDescription = LabelRef(str: ""); noMatchesDescription.add(cssClass: "aw-no-matches-copy")
    noMatchesDescription.xalign = 0; noMatchesDescription.set(wrap: true)
    let clearSearch = ButtonRef(label: "Clear search"); clearSearch.add(cssClass: "aw-clear-search"); clearSearch.setHalign(align: .start)
    clearSearch.onClicked { [weak state] _ in state?.clearSidebarSearch() }
    noMatches.append(child: noMatchesTitle); noMatches.append(child: noMatchesDescription); noMatches.append(child: clearSearch)
    noMatches.set(visible: false); groups.append(child: noMatches)
    state.attachSearch(entry: search, noMatches: noMatches, description: noMatchesDescription)
    let searchKeys = EventControllerKey()
    searchKeys.onKeyPressed { [weak state] _, keyval, _, _ in
        state?.handleSidebarSearchKey(keyval) ?? false
    }
    gtk_widget_add_controller(search.widget_ptr, searchKeys.event_controller_ptr)
    scroller.setVexpand(expand: true); scroller.set(child: groups); expandedSidebar.append(child: scroller)
    let sidebarFooter = state.makeSidebarFooter()
    expandedSidebar.append(child: sidebarFooter.root)

    let rail = BoxRef(orientation: .vertical, spacing: 6); rail.add(cssClass: "aw-rail")
    rail.setMarginStart(margin: 10); rail.setMarginEnd(margin: 10)
    rail.setMarginTop(margin: 10); rail.setMarginBottom(margin: 0)
    let railSearch = ButtonRef(); railSearch.set(iconName: "system-search-symbolic")
    railSearch.add(cssClass: "aw-rail-control")
    railSearch.setTooltip(text: "Search workspaces and actions")
    railSearch.onClicked { [weak state] _ in state?.showCommandPalette() }
    let railAdd = ButtonRef(); railAdd.set(iconName: "list-add-symbolic")
    railAdd.add(cssClass: "aw-rail-control")
    railAdd.setTooltip(text: "New Workspace in Current Directory")
    railAdd.onClicked { [weak state] _ in state?.createWorkspace() }
    rail.append(child: railSearch); rail.append(child: railAdd)
    let railRows = BoxRef(orientation: .vertical, spacing: 5)
    let railScroller = ScrolledWindowRef(); railScroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
    railScroller.setVexpand(expand: true); railScroller.set(child: railRows); rail.append(child: railScroller)
    sidebarFooter.collapsedRoot.add(cssClass: "aw-rail-footer")
    rail.append(child: sidebarFooter.collapsedRoot)
    sidebarModes.append(child: expandedSidebar); sidebarModes.append(child: rail)
    expandedSidebar.set(visible: true); rail.set(visible: false)
    sidebar.append(child: sidebarModes)

    let stack = StackRef(); stack.add(cssClass: "aw-content"); stack.setHexpand(expand: true); stack.setVexpand(expand: true)
    stack.set(hhomogeneous: true); stack.set(vhomogeneous: true)
    state.attach(stack: stack, title: title, root: root, sidebarFooter: sidebarFooter)

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
            let pathBar = state.makePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
            page.append(child: layout.0); page.append(child: pathBar.root)
            let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
            body.append(child: state.makeRow(workspace: workspace, groupID: group.id))
            railRows.append(child: state.makeRailRow(workspace: workspace))
            state.install(workspace: workspace, groupID: group.id, pageName: pageName, pathBar: pathBar, focusedSurface: focused)
        }
    }

    stack.setSizeRequest(width: 480, height: -1)
    let sidebarPaned = PanedRef(orientation: .horizontal)
    sidebarPaned.setWideHandle(wide: false)
    sidebarPaned.setStart(child: sidebar)
    sidebarPaned.setEnd(child: stack)
    sidebarPaned.setHexpand(expand: true)
    sidebarPaned.setVexpand(expand: true)
    state.attachSidebar(
        paned: sidebarPaned,
        brand: brand,
        sidebar: sidebar,
        expanded: expandedSidebar,
        collapsed: rail,
        railRows: railRows
    )
    main.append(child: sidebarPaned); root.append(child: main)
    window.set(child: root); window.present()
    if let selected = snapshot.selectedWorkspaceID { state.select(selected) }
}

let status = Application.run(id: "com.interactivebuffoonery.awesomux", arguments: CommandLine.arguments,
    activationHandler: buildWindow)
guard let status else { fatalError("Could not create GTK application") }
exit(Int32(status))
