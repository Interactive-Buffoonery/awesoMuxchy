import AwesoMuxCore
import AwesoMuxTerminal
import CGtk
import Dispatch
import Foundation
import GIO
import Gdk
import GLib
import GLibObject
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

private enum LinuxForegroundProcessProbe {
    static func liveness(for surface: TerminalSurface) -> ForegroundProcessLiveness {
        if surface.processExited { return .exited }
        guard let processID = surface.foregroundProcessID,
              processID <= UInt64(Int32.max)
        else { return .indeterminate }
        let identifier = String(processID)
        let command = boundedText(at: "/proc/\(identifier)/comm", maximumBytes: 256)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let children = boundedText(
            at: "/proc/\(identifier)/task/\(identifier)/children", maximumBytes: 4_096
        ).map { !$0.split(whereSeparator: \Character.isWhitespace).isEmpty }
        return ForegroundProcessLiveness.classify(
            processExited: false,
            commandName: command?.isEmpty == false ? command : nil,
            hasChildren: children
        )
    }

    private static func boundedText(at path: String, maximumBytes: Int) -> String? {
        guard let data = FileManager.default.contents(atPath: path),
              data.count <= maximumBytes
        else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

private func applySearchMatches(_ ranges: [Swift.Range<Int>], to label: LabelRef) {
    guard !ranges.isEmpty else { label.setAttributes(attrs: nil as Pango.AttrListRef?); return }
    let attributes = Pango.AttrList()
    for range in ranges {
        guard range.lowerBound >= 0, range.upperBound >= range.lowerBound,
              range.upperBound <= Int(UInt32.max) else { continue }
        if var weight = Pango.attrWeightNew(weight: PangoWeight(rawValue: 700)) {
            weight.startIndex = UInt32(range.lowerBound)
            weight.endIndex = UInt32(range.upperBound)
            attributes.insert(attr: weight)
        }
        if var underline = Pango.attrUnderlineNew(underline: PangoUnderline(rawValue: 1)) {
            underline.startIndex = UInt32(range.lowerBound)
            underline.endIndex = UInt32(range.upperBound)
            attributes.insert(attr: underline)
        }
    }
    label.setAttributes(attrs: attributes)
}

private final class ApplicationState: @unchecked Sendable {
    private enum SidebarDragItem: Equatable {
        case workspace(UUID)
        case pinned(UUID)
        case group(UUID)
    }

    private final class WorkspaceRuntime {
        var groupID: UUID
        let pageName: String
        let page: BoxRef
        var layoutRoot: WidgetRef
        let pathBar: FocusedPanePathBar
        var focusedPaneID: UUID
        var focusedSurface: TerminalSurface

        init(groupID: UUID, pageName: String, page: BoxRef, layoutRoot: WidgetRef,
             pathBar: FocusedPanePathBar,
             focusedPaneID: UUID, focusedSurface: TerminalSurface) {
            self.groupID = groupID
            self.pageName = pageName
            self.page = page
            self.layoutRoot = layoutRoot
            self.pathBar = pathBar
            self.focusedPaneID = focusedPaneID
            self.focusedSurface = focusedSurface
        }
    }

    private final class WorkspaceRowChrome {
        let root: OverlayRef
        let row: ToggleButtonRef
        let close: ButtonRef
        let motion: EventControllerMotion
        let focus: EventControllerFocus
        private var pointerInside = false
        private var focusInside = false

        init(row: ToggleButtonRef, onClose: @escaping () -> Void) {
            self.row = row
            root = OverlayRef(); root.add(cssClass: "aw-workspace-row")
            root.setHalign(align: .fill); root.set(child: row)
            close = ButtonRef(); setDecorativeButtonText(close, "×")
            close.add(cssClass: "aw-row-close")
            close.setSizeRequest(width: 24, height: 24)
            close.setHalign(align: .end); close.setValign(align: .center)
            close.setMarginEnd(margin: 8); close.set(visible: false)
            close.setTooltip(text: "Close Workspace"); setAccessibleLabel(close, "Close Workspace")
            close.onClicked { _ in onClose() }
            root.addOverlay(widget: close)

            motion = EventControllerMotion(); focus = EventControllerFocus()
            motion.onEnter { [weak self] _, _, _ in self?.pointerInside = true; self?.refresh() }
            motion.onLeave { [weak self] _ in self?.pointerInside = false; self?.refresh() }
            focus.onEnter { [weak self] _ in self?.focusInside = true; self?.refresh() }
            focus.onLeave { [weak self] _ in self?.focusInside = false; self?.refresh() }
            _ = motion.ref(); _ = focus.ref()
            gtk_widget_add_controller(root.widget_ptr, motion.event_controller_ptr)
            gtk_widget_add_controller(root.widget_ptr, focus.event_controller_ptr)
        }

        private func refresh() { close.set(visible: pointerInside || focusInside) }

        func detach() {
            gtk_widget_remove_controller(root.widget_ptr, motion.event_controller_ptr)
            gtk_widget_remove_controller(root.widget_ptr, focus.event_controller_ptr)
            root.unparent()
        }
    }

    private final class GroupHeaderChrome {
        let root: OverlayRef
        let close: ButtonRef
        let count: LabelRef
        let motion: EventControllerMotion
        let focus: EventControllerFocus
        var isFiltering = false { didSet { refresh() } }
        var isEmpty: Bool { didSet { refresh() } }
        var isCollapsed: Bool { didSet { refresh() } }
        var isDragActive = false { didSet { refresh() } }
        private var pointerInside = false
        private var focusInside = false

        init(
            disclosure: ButtonRef, count: LabelRef, isEmpty: Bool, isCollapsed: Bool,
            onClose: @escaping () -> Void
        ) {
            self.count = count; self.isEmpty = isEmpty; self.isCollapsed = isCollapsed
            root = OverlayRef(); root.add(cssClass: "aw-group-header")
            root.setHalign(align: .fill); root.setHexpand(expand: true); root.set(child: disclosure)
            close = ButtonRef(); setDecorativeButtonText(close, "×")
            close.add(cssClass: "aw-group-close")
            close.setSizeRequest(width: 24, height: 24)
            close.setHalign(align: .end); close.setValign(align: .center)
            close.setMarginEnd(margin: 2); close.setTooltip(text: "Close Group")
            setAccessibleLabel(close, "Close Group")
            close.onClicked { _ in onClose() }
            root.addOverlay(widget: close)

            motion = EventControllerMotion(); focus = EventControllerFocus()
            motion.onEnter { [weak self] _, _, _ in self?.pointerInside = true; self?.refresh() }
            motion.onLeave { [weak self] _ in self?.pointerInside = false; self?.refresh() }
            focus.onEnter { [weak self] _ in self?.focusInside = true; self?.refresh() }
            focus.onLeave { [weak self] _ in self?.focusInside = false; self?.refresh() }
            _ = motion.ref(); _ = focus.ref()
            gtk_widget_add_controller(root.widget_ptr, motion.event_controller_ptr)
            gtk_widget_add_controller(root.widget_ptr, focus.event_controller_ptr)
            refresh()
        }

        func refresh() {
            let visible = SidebarGroupClosePolicy.showsCloseButton(
                pointerOrFocusInside: pointerInside || focusInside,
                isCollapsedRail: false,
                isFiltering: isFiltering,
                hasResolvedGroup: true,
                isGroupEmpty: isEmpty,
                isGroupCollapsed: isCollapsed,
                isDragActive: isDragActive
            )
            close.set(visible: visible); count.set(visible: !visible)
        }

        func detach() {
            gtk_widget_remove_controller(root.widget_ptr, motion.event_controller_ptr)
            gtk_widget_remove_controller(root.widget_ptr, focus.event_controller_ptr)
            root.unparent()
        }
    }

    let terminalRuntime: TerminalRuntime
    private(set) var snapshot: SessionSnapshot
    private let store: SessionStore
    private let startupRecoveryPresentation: SessionRecoveryPresentation?
    private let preferencesStore: AppPreferencesStore
    private var preferences: AppPreferences
    private(set) var isPersistencePaused = false
    private lazy var persistence = SessionPersistenceCoordinator(store: store) { [weak self] outcome in
        performOnGTKMain { [weak self] in self?.applyPersistenceOutcome(outcome) }
    }
    private let styles = ChromeStyles.makeProvider()
    var surfaces: [TerminalSurface] = []
    private(set) var focusedSurface: TerminalSurface?
    private(set) var focusedPaneID: UUID?
    private var surfacesByPane: [UUID: TerminalSurface] = [:]
    private var retiringSurfaces: [TerminalSurface] = []
    private var workspaceByPane: [UUID: UUID] = [:]
    private var surfaceGenerationByPane: [UUID: Int] = [:]
    private var lastAgentStateChangeAt: [UUID: Foundation.Date] = [:]
    private let runtimeSessionID = UUID()
    private var agentEventWatchers: [UUID: AgentEventWatcher] = [:]
    private var runtimes: [UUID: WorkspaceRuntime] = [:]
    private var rows: [UUID: ToggleButtonRef] = [:]
    private var regularRowChrome: [UUID: WorkspaceRowChrome] = [:]
    private var railRows: [UUID: ToggleButtonRef] = [:]
    private var railJumpNumberLabels: [UUID: LabelRef] = [:]
    private var railGroupRows: [UUID: MenuButtonRef] = [:]
    private var railGroupAttentionLabels: [UUID: LabelRef] = [:]
    private var metadata: [UUID: LabelRef] = [:]
    private var workspaceTitles: [UUID: LabelRef] = [:]
    private var regularAgentTileHosts: [UUID: BoxRef] = [:]
    private var regularAgentTiles: [UUID: OverlayRef] = [:]
    private var railAgentTileHosts: [UUID: BoxRef] = [:]
    private var railAgentTiles: [UUID: OverlayRef] = [:]
    private var workspaceIDsByGroup: [UUID: [UUID]] = [:]
    private var groupRoots: [UUID: BoxRef] = [:]
    private var groupBodies: [UUID: BoxRef] = [:]
    private var groupChevrons: [UUID: LabelRef] = [:]
    private var groupCounts: [UUID: LabelRef] = [:]
    private var groupNames: [UUID: LabelRef] = [:]
    private var groupMarkers: [UUID: LabelRef] = [:]
    private var groupAttentionLabels: [UUID: LabelRef] = [:]
    private var groupCreateRows: [UUID: ButtonRef] = [:]
    private var groupDisclosures: [UUID: ButtonRef] = [:]
    private var groupHeaderChrome: [UUID: GroupHeaderChrome] = [:]
    private var groupMoveUpActions: [UUID: ButtonRef] = [:]
    private var groupMoveDownActions: [UUID: ButtonRef] = [:]
    private var groupCloseActions: [UUID: ButtonRef] = [:]
    private var groupDefaultColorActions: [UUID: ButtonRef] = [:]
    private var groupColorActions: [UUID: [WorkspaceGroupColor: ButtonRef]] = [:]
    private var workspaceOptionMenus: [(menu: MenuButtonRef, includesPrimary: Bool)] = []
    private var isSidebarFiltering = false
    private var attentionSectionRoot: Revealer?
    private var pinnedSectionRoot: Revealer?
    private var attentionSectionContent: BoxRef?
    private var pinnedSectionContent: BoxRef?
    private var attentionSectionBody: BoxRef?
    private var pinnedSectionBody: BoxRef?
    private var hasAppliedLiftedSectionVisibility = false
    private var attentionRows: [UUID: ToggleButtonRef] = [:]
    private var pinnedRows: [UUID: ToggleButtonRef] = [:]
    private var liftedRowChrome: [UUID: WorkspaceRowChrome] = [:]
    private var liftedTitles: [UUID: LabelRef] = [:]
    private var workspaceContextControllers: [UUID: GestureClick] = [:]
    private var workspaceContextKeyControllers: [UUID: EventControllerKey] = [:]
    private var workspaceContextPopovers: [UUID: PopoverRef] = [:]
    private enum PanePeekPresence: Hashable { case rowPointer, rowFocus, cardPointer }
    private var workspacePanePeekPopovers: [UUID: PopoverRef] = [:]
    private var workspacePanePeekPresence: [UUID: Set<PanePeekPresence>] = [:]
    private var workspacePanePeekGeneration: [UUID: Int] = [:]
    private var workspacePanePeekMotionControllers: [UUID: [EventControllerMotion]] = [:]
    private var workspacePanePeekFocusControllers: [UUID: [EventControllerFocus]] = [:]
    private var workspacePanePeekHosts: [UUID: ToggleButtonRef] = [:]
    private var workspacePanePeekCards: [UUID: BoxRef] = [:]
    private var workspacePanePeekCardMotionControllers: [UUID: [EventControllerMotion]] = [:]
    private var workspacePanePeekCardMotionHosts: [UUID: [WidgetRef]] = [:]
    private var regularPinActions: [UUID: ButtonRef] = [:]
    private var liftedPinActions: [UUID: ButtonRef] = [:]
    private var liftedContextControllers: [UUID: GestureClick] = [:]
    private var liftedContextKeyControllers: [UUID: EventControllerKey] = [:]
    private var liftedContextPopovers: [UUID: PopoverRef] = [:]
    private var groupsContainer: BoxRef?
    private var noMatchesRoot: BoxRef?
    private var noMatchesDescription: LabelRef?
    private var sidebarSearchEntry: SearchEntryRef?
    private var searchResultIDs: [UUID] = []
    private var searchResultIndex = 0
    private var stack: StackRef?
    private var window: ApplicationWindowRef?
    private var title: LabelRef?
    private var rootWidget: BoxRef?
    private var sidebarFooter: SidebarStatusFooter?
    private var sidebarPaned: PanedRef?
    private var sidebarHost: OverlayRef?
    private var sidebarBrand: LabelRef?
    private var sidebarWidget: BoxRef?
    private var expandedSidebarWidget: BoxRef?
    private var collapsedSidebarWidget: BoxRef?
    private var renderedSidebarMode: SidebarWidthMode?
    private var sidebarRailRows: BoxRef?
    private var collapsedEmptyAction: ButtonRef?
    private var emptyWorkspacePage: BoxRef?
    private var emptyWorkspaceCopy: LabelRef?
    private var emptyWorkspaceReopen: ButtonRef?
    private var sidebarEdgeTab: ButtonRef?
    private var isApplyingSidebarWidth = false
    private var isSidebarOverlayMounted = false
    private var isSidebarTemporarilyRevealed = false
    private var sidebarRevealGeneration = 0
    private let attentionAcknowledgementDwell = AttentionAcknowledgementDwellCoordinator {
        delayMilliseconds, action in
        timeout(add: delayMilliseconds) {
            action()
            return false
        }
    }
    private var sidebarMotionController: EventControllerMotion?
    private var searchKeyController: EventControllerKey?
    private var sidebarNavigationKeyController: EventControllerKey?
    private var globalModifierKeyController: EventControllerKey?
    private var activeSheetWindow: WindowRef?
    private var activeSheetKeyController: EventControllerKey?
    private var isWorkspaceJumpModifierHeld = false
    private let sidebarDragNonce = UUID().uuidString
    private var activeSidebarDrag: SidebarDragItem?
    private var regularWorkspaceDragSources: [UUID: DragSource] = [:]
    private var regularWorkspaceDropTargets: [UUID: DropTarget] = [:]
    private var pinnedWorkspaceDragSources: [UUID: DragSource] = [:]
    private var pinnedWorkspaceDropTargets: [UUID: DropTarget] = [:]
    private var groupDragSources: [UUID: DragSource] = [:]
    private var groupDropTargets: [UUID: DropTarget] = [:]
    private var lastWorkspaceCreateAt: ContinuousClock.Instant?
    private var context = FocusedPaneContextCoordinator()
    private var actions: [GIO.SimpleAction] = []
    private var commandActions: [CommandID: GIO.SimpleAction] = [:]
    private var menu: GIO.Menu?

    init?(
        snapshot: SessionSnapshot,
        store: SessionStore,
        preferencesStore: AppPreferencesStore,
        startupRecoveryPresentation: SessionRecoveryPresentation? = nil
    ) {
        guard let runtime = TerminalRuntime() else { return nil }
        terminalRuntime = runtime
        self.snapshot = snapshot
        self.snapshot.reconcileAttentionWorkspaceIDs()
        self.snapshot.pruneRecentlyClosedWorkspaces()
        self.store = store
        self.startupRecoveryPresentation = startupRecoveryPresentation
        self.preferencesStore = preferencesStore
        preferences = preferencesStore.load()
    }

    var configuredSidebarPosition: SidebarPosition { preferences.sidebarPosition }

    func installStyles(on widget: WidgetRef) {
        gtk_style_context_add_provider_for_display(widget.getDisplay().display_ptr,
            styles.styleProvider.style_provider_ptr, UInt32(GTK_STYLE_PROVIDER_PRIORITY_APPLICATION))
    }

    func attach(window: ApplicationWindowRef, stack: StackRef, title: LabelRef, root: BoxRef, sidebarFooter: SidebarStatusFooter) {
        self.window = window; self.stack = stack; self.title = title; rootWidget = root; self.sidebarFooter = sidebarFooter
        applyTheme(); sidebarFooter.update(AgentFooterSummary(snapshot: snapshot))
    }

    func attachSidebar(
        paned: PanedRef,
        brand: LabelRef,
        sidebar: BoxRef,
        expanded: BoxRef,
        collapsed: BoxRef,
        railRows: BoxRef,
        edgeTab: ButtonRef,
        host: OverlayRef
    ) {
        sidebarPaned = paned
        sidebarHost = host
        sidebarBrand = brand
        sidebarWidget = sidebar
        expandedSidebarWidget = expanded
        collapsedSidebarWidget = collapsed
        sidebarRailRows = railRows
        sidebarEdgeTab = edgeTab
        let isRight = preferences.sidebarPosition == .right
        paned.setResizeStartChild(resize: isRight)
        paned.setShrinkStartChild(resize: !isRight)
        paned.setResizeEndChild(resize: !isRight)
        paned.setShrinkEndChild(resize: isRight)
        applySidebarWidth(preferences.sidebarWidth, persist: false)
        updateSidebarVisibility()
        _ = paned.onNotifyPosition { [weak self] paned, _ in
            self?.sidebarPositionChanged(paned.getPosition())
        }
    }

    private func sidebarPositionChanged(_ proposedWidth: Int) {
        guard !isApplyingSidebarWidth else { return }
        let paneExtent = sidebarPaned?.getWidth() ?? 0
        guard paneExtent > 0 else { return }
        let proposedSidebarWidth = SidebarPresentationPolicy.sidebarWidth(
            dividerCoordinate: proposedWidth,
            paneExtent: paneExtent,
            position: preferences.sidebarPosition
        )
        let maximum = max(SidebarWidthPolicy.collapsedWidth, paneExtent - 480)
        let committed = SidebarWidthPolicy.constrainedLiveWidth(
            for: Double(proposedSidebarWidth), maximumWidth: Double(maximum)
        )
        if committed != proposedSidebarWidth {
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
        if let sidebarPaned {
            let paneExtent = sidebarPaned.getWidth()
            let divider: Int
            if preferences.sidebarPosition == .left {
                divider = committed
            } else {
                let effectiveExtent = paneExtent > 0 ? paneExtent : 1_440
                divider = SidebarPresentationPolicy.dividerCoordinate(
                    sidebarWidth: committed,
                    paneExtent: effectiveExtent,
                    position: .right
                )
            }
            sidebarPaned.set(position: divider)
        }
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

    private func focusSidebar() {
        if preferences.isSidebarHidden {
            preferences.isSidebarHidden = false
            updateSidebarVisibility()
            try? preferencesStore.save(preferences)
        }
        timeout(add: 0) { [weak self] in
            guard let self else { return false }
            if self.preferences.sidebarWidth < SidebarWidthPolicy.railThreshold {
                let targetID = self.snapshot.selectedWorkspaceID ?? self.workspaceJumpOrder().first
                if let targetID, self.railRows[targetID]?.grabFocus() == true { return false }
                _ = self.collapsedEmptyAction?.grabFocus()
            } else {
                _ = self.sidebarSearchEntry?.grabFocus()
            }
            return false
        }
    }

    private func restoreSidebarFocus(to workspaceID: UUID) {
        timeout(add: 10) { [weak self] in
            guard let self, !self.preferences.isSidebarHidden else { return false }
            if self.preferences.sidebarWidth < SidebarWidthPolicy.railThreshold {
                _ = self.railRows[workspaceID]?.grabFocus()
                return false
            }
            let candidates = [
                self.pinnedRows[workspaceID],
                self.attentionRows[workspaceID],
                self.rows[workspaceID],
            ]
            for row in candidates where row?.getVisible() == true {
                if row?.grabFocus() == true { break }
            }
            return false
        }
    }

    private func sidebarOwnsKeyboardFocus(for workspaceID: UUID) -> Bool {
        sidebarWidget?.getFocusChild() != nil
            || workspaceContextPopovers[workspaceID]?.getVisible() == true
            || liftedContextPopovers[workspaceID]?.getVisible() == true
    }

    private func restoreSidebarFocus(toGroup groupID: UUID) {
        timeout(add: 10) { [weak self] in
            guard let self, !self.preferences.isSidebarHidden,
                  self.preferences.sidebarWidth >= SidebarWidthPolicy.railThreshold
            else { return false }
            _ = self.groupDisclosures[groupID]?.grabFocus()
            return false
        }
    }

    private func updateSidebarVisibility() {
        mountSidebarOverlay(preferences.isSidebarHidden)
        isSidebarTemporarilyRevealed = false
        sidebarWidget?.set(visible: !preferences.isSidebarHidden)
        sidebarBrand?.set(visible: !preferences.isSidebarHidden)
        sidebarEdgeTab?.set(visible:
            preferences.isSidebarHidden && SidebarPresentationPolicy.hasAttention(snapshot)
        )
    }

    private func mountSidebarOverlay(_ overlay: Bool) {
        guard overlay != isSidebarOverlayMounted,
              let sidebarWidget, let sidebarPaned, let sidebarHost else { return }
        _ = sidebarWidget.ref()
        if overlay {
            if preferences.sidebarPosition == .left { sidebarPaned.setStart() } else { sidebarPaned.setEnd() }
            sidebarWidget.setHalign(align: preferences.sidebarPosition == .left ? .start : .end)
            sidebarWidget.setValign(align: .fill)
            sidebarWidget.setSizeRequest(width: preferences.sidebarWidth, height: -1)
            sidebarHost.addOverlay(widget: sidebarWidget)
        } else {
            sidebarHost.removeOverlay(widget: sidebarWidget)
            sidebarWidget.setHalign(align: .fill)
            if preferences.sidebarPosition == .left {
                sidebarPaned.setStart(child: sidebarWidget)
            } else {
                sidebarPaned.setEnd(child: sidebarWidget)
            }
            applySidebarWidth(preferences.sidebarWidth, persist: false)
        }
        sidebarWidget.unref()
        isSidebarOverlayMounted = overlay
    }

    func sidebarPointerMoved(x: Double, width: Double) {
        guard preferences.isSidebarHidden else { return }
        let proximity = SidebarPresentationPolicy.proximity(
            pointerX: x, containerWidth: width, position: preferences.sidebarPosition
        )
        let withinRevealedBody: Bool
        if preferences.sidebarPosition == .left {
            withinRevealedBody = x <= Double(preferences.sidebarWidth)
        } else {
            withinRevealedBody = x >= width - Double(preferences.sidebarWidth)
        }
        if proximity == .revealed || (isSidebarTemporarilyRevealed && withinRevealedBody) {
            sidebarRevealGeneration += 1
            isSidebarTemporarilyRevealed = true
            sidebarWidget?.set(visible: true)
            sidebarEdgeTab?.set(visible: false)
        } else if isSidebarTemporarilyRevealed {
            scheduleSidebarOverlayHide()
        }
    }

    func sidebarPointerLeft() {
        guard preferences.isSidebarHidden, isSidebarTemporarilyRevealed else { return }
        scheduleSidebarOverlayHide()
    }

    private func scheduleSidebarOverlayHide() {
        sidebarRevealGeneration += 1
        let generation = sidebarRevealGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(220)) { [weak self] in
            performOnGTKMain {
                guard let self, self.preferences.isSidebarHidden,
                      self.sidebarRevealGeneration == generation else { return }
                self.isSidebarTemporarilyRevealed = false
                self.sidebarWidget?.set(visible: false)
                self.sidebarEdgeTab?.set(visible: SidebarPresentationPolicy.hasAttention(self.snapshot))
            }
        }
    }

    func showSidebarPersistently() {
        guard preferences.isSidebarHidden else { return }
        preferences.isSidebarHidden = false
        updateSidebarVisibility()
        try? preferencesStore.save(preferences)
    }

    private func updateSidebarGeometry(_ width: Int) {
        let mode = SidebarWidthPolicy.mode(for: Double(width))
        let previousMode = renderedSidebarMode
        let sidebarOwnedFocus = previousMode != nil && sidebarWidget?.getFocusChild() != nil
        if previousMode != mode, mode == .collapsed {
            sidebarSearchEntry?.text = ""
            filter("")
        }
        sidebarFooter?.sidebarModeChanged(to: mode)
        sidebarBrand?.setSizeRequest(width: width, height: 38)
        sidebarBrand?.label = mode == .collapsed ? ">_" : ">_  awesoMux"
        sidebarWidget?.setSizeRequest(width: SidebarWidthPolicy.collapsedWidth, height: -1)
        if mode == .collapsed {
            expandedSidebarWidget?.set(visible: false)
            collapsedSidebarWidget?.set(visible: true)
        } else {
            collapsedSidebarWidget?.set(visible: false)
            expandedSidebarWidget?.set(visible: true)
        }
        renderedSidebarMode = mode
        refreshRailJumpNumbers()
        if previousMode != nil, previousMode != mode, sidebarOwnedFocus {
            restoreSidebarFocusAfterModeChange(mode)
        }
    }

    private func restoreSidebarFocusAfterModeChange(_ mode: SidebarWidthMode) {
        if let selected = snapshot.selectedWorkspaceID {
            restoreSidebarFocus(to: selected)
            return
        }
        timeout(add: 10) { [weak self] in
            guard let self, !self.preferences.isSidebarHidden else { return false }
            if mode == .collapsed { _ = self.collapsedEmptyAction?.grabFocus() }
            else { _ = self.sidebarSearchEntry?.grabFocus() }
            return false
        }
    }

    func makePathBar() -> FocusedPanePathBar {
        FocusedPanePathBar(actions: .init(
            copy: { [weak self] in self?.copy($0) }, reveal: { [weak self] in self?.reveal($0) },
            openEditor: { [weak self] in self?.openEditor($0, path: $1) },
            insertCommand: { [weak self] in self?.focusedSurface?.send(text: $0) },
            canInsertCommand: { [weak self] in self?.canInsertFocusedFooterCommand() == true },
            openURL: { [weak self] in self?.openURL($0) }
        ))
    }

    private func canInsertFocusedFooterCommand() -> Bool {
        guard let workspaceID = snapshot.selectedWorkspaceID,
              let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: workspace.focusedPaneID),
              surfacesByPane[pane.id] != nil else { return false }
        return FocusedPaneCommandGate.canInsert(
            ownership: pane.ownership,
            agentName: pane.agent
        )
    }

    func makeSidebarFooter() -> SidebarStatusFooter {
        SidebarStatusFooter(preferences: preferences, actions: .init(
            selectPane: { [weak self] workspace, pane in self?.selectAgentActivityPane(workspace, pane) },
            updatePreferences: { [weak self] in self?.updatePreferences($0) },
            reportBug: { [weak self] in self?.openFeedback() },
            suggestFeature: { [weak self] in self?.openFeedback() }
        ))
    }

    private func selectAgentActivityPane(_ workspaceID: UUID, _ paneID: UUID) {
        if isSidebarFiltering, !searchResultIDs.contains(workspaceID) {
            sidebarSearchEntry?.text = ""
            filter("")
        }
        select(workspaceID)
        focus(paneID)
    }

    func makeSurface(pane: PaneSnapshot, workspaceID: UUID, label: String, description: String) -> TerminalSurface? {
        let generation = (surfaceGenerationByPane[pane.id] ?? 0) + 1
        surfaceGenerationByPane[pane.id] = generation
        let endpoint = try? AgentEventEndpoint(
            profileDirectory: store.snapshotURL.deletingLastPathComponent(),
            sessionID: runtimeSessionID, paneID: pane.id
        )
        guard let surface = terminalRuntime.makeSurface(workingDirectory: pane.workingDirectory,
            environment: endpoint?.environment ?? [:],
            accessibleLabel: label, accessibleDescription: description,
            onFocusChanged: { [weak self] focused in if focused { self?.terminalFocused(pane.id) } },
            onTitleChanged: { [weak self] title in
                performOnGTKMain { [weak self] in
                    self?.publishPaneTitle(title, paneID: pane.id, workspaceID: workspaceID, generation: generation)
                }
            },
            onWorkingDirectoryChanged: { [weak self] directory in
                performOnGTKMain { [weak self] in
                    self?.publishPaneWorkingDirectory(
                        directory, paneID: pane.id, workspaceID: workspaceID, generation: generation
                    )
                }
            }) else {
            surfaceGenerationByPane.removeValue(forKey: pane.id)
            if let endpoint { try? FileManager.default.removeItem(at: endpoint.fileURL) }
            return nil
        }
        surfaces.append(surface); surfacesByPane[pane.id] = surface; workspaceByPane[pane.id] = workspaceID
        if let endpoint {
            let watcher = AgentEventWatcher(fileURL: endpoint.fileURL) { [weak self] update in
                performOnGTKMain { [weak self] in
                    self?.publishPaneAgentUpdate(
                        update, paneID: pane.id, workspaceID: workspaceID, generation: generation
                    )
                }
            }
            agentEventWatchers[pane.id] = watcher
            watcher.start()
        }
        return surface
    }

    private func acceptsPanePublication(_ paneID: UUID, workspaceID: UUID, generation: Int) -> Bool {
        surfaceGenerationByPane[paneID] == generation
            && workspaceByPane[paneID] == workspaceID
            && snapshot.workspace(id: workspaceID)?.layout.paneIDs.contains(paneID) == true
    }

    private func publishPaneTitle(_ rawTitle: String, paneID: UUID, workspaceID: UUID, generation: Int) {
        guard acceptsPanePublication(paneID, workspaceID: workspaceID, generation: generation),
              (try? snapshot.updatePanePresentation(
                  paneID: paneID, workspaceID: workspaceID, title: rawTitle
              )) != nil
        else { return }
        refreshWorkspaceRowPresentation(workspaceID)
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        persist()
    }

    private func publishPaneWorkingDirectory(
        _ rawDirectory: String, paneID: UUID, workspaceID: UUID, generation: Int
    ) {
        guard acceptsPanePublication(paneID, workspaceID: workspaceID, generation: generation),
              (try? snapshot.updatePanePresentation(
                  paneID: paneID, workspaceID: workspaceID, workingDirectory: rawDirectory
              )) != nil,
              let workspace = snapshot.workspace(id: workspaceID)
        else { return }
        if workspace.focusedPaneID == paneID {
            refreshWorkspaceRowPresentation(workspaceID)
            if snapshot.selectedWorkspaceID == workspaceID { updateChrome(workspaceID) }
            else { sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot)) }
        } else {
            sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        }
        persist()
    }

    private func publishPaneAgentUpdate(
        _ update: AgentRuntimeUpdate, paneID: UUID, workspaceID: UUID, generation: Int
    ) {
        let previousState = snapshot.workspace(id: workspaceID)?.layout.pane(id: paneID)?.agentState
        let wasUnanswered = snapshot.unansweredTurnPaneIDs.contains(paneID)
        let wasLifted = snapshot.attentionWorkspaceIDs.contains(workspaceID)
        let previousRollup = snapshot.workspace(id: workspaceID).map(
            SidebarAgentTilePresentation.project(workspace:)
        )
        guard acceptsPanePublication(paneID, workspaceID: workspaceID, generation: generation),
              (try? snapshot.updatePaneAgentRuntime(
                  paneID: paneID, workspaceID: workspaceID, update: update
              )) != nil
        else { return }
        if previousState != update.state { lastAgentStateChangeAt[paneID] = Foundation.Date() }
        let promotedUnansweredTurn = update.reportsUnansweredTurn
            && !snapshot.pinnedWorkspaceIDs.contains(workspaceID)
            && !wasUnanswered
            && !wasLifted
            && snapshot.attentionWorkspaceIDs.contains(workspaceID)
        refreshWorkspaceAgentTile(workspaceID)
        refreshWorkspaceRowPresentation(workspaceID)
        refreshLiftedRows()
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        persist()
        if snapshot.selectedWorkspaceID == workspaceID,
           runtimes[workspaceID]?.focusedPaneID == paneID
        {
            // Attention can arrive after focus has already settled. Start the
            // same passive-read dwell used by focus entry in that event order.
            scheduleAttentionAcknowledgement(workspaceID: workspaceID, paneID: paneID)
        }
        if promotedUnansweredTurn, let workspace = snapshot.workspace(id: workspaceID) {
            announce(SidebarAnnouncement.unansweredTurnPromoted(
                title: SidebarWorkspaceTitle.resolve(workspace: workspace)
            ))
        } else if update.state == .needsAttention,
                  !wasLifted,
                  !snapshot.pinnedWorkspaceIDs.contains(workspaceID),
                  snapshot.attentionWorkspaceIDs.contains(workspaceID),
                  snapshot.selectedWorkspaceID != workspaceID,
                  let workspace = snapshot.workspace(id: workspaceID)
        {
            announce(SidebarAnnouncement.attentionPromoted(
                agent: ChromeText.sanitized(update.agent, limit: 80),
                title: SidebarWorkspaceTitle.resolve(workspace: workspace)
            ))
        } else if snapshot.selectedWorkspaceID != workspaceID,
                  let previousRollup,
                  let workspace = snapshot.workspace(id: workspaceID)
        {
            let rollup = SidebarAgentTilePresentation.project(workspace: workspace)
            guard rollup.state != previousRollup.state else { return }
            switch rollup.state {
            case .done:
                announce(SidebarAnnouncement.agentCompleted(
                    agent: rollup.name, title: SidebarWorkspaceTitle.resolve(workspace: workspace)
                ))
            case .error:
                announce(SidebarAnnouncement.agentReportedError(
                    agent: rollup.name, title: SidebarWorkspaceTitle.resolve(workspace: workspace)
                ))
            default:
                announceAttentionReturnIfNeeded(workspaceID, wasAttention: wasLifted)
            }
        } else {
            announceAttentionReturnIfNeeded(workspaceID, wasAttention: wasLifted)
        }
    }

    private func refreshWorkspaceAgentTile(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID) else { return }
        let presentation = SidebarAgentTilePresentation.project(workspace: workspace)
        if let host = regularAgentTileHosts[workspaceID] {
            if let previous = regularAgentTiles[workspaceID] { host.remove(child: previous) }
            let tile = makeAgentTile(presentation, size: 32)
            host.append(child: tile); regularAgentTiles[workspaceID] = tile
        }
        if let host = railAgentTileHosts[workspaceID] {
            if let previous = railAgentTiles[workspaceID] { host.remove(child: previous) }
            let tile = makeAgentTile(presentation, size: 28, collapsed: true)
            host.append(child: tile); railAgentTiles[workspaceID] = tile
        }
    }

    private func refreshWorkspaceRowPresentation(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: workspace.focusedPaneID)
        else { return }
        let displayedTitle = SidebarWorkspaceTitle.resolve(workspace: workspace)
        let location = FocusedPaneContext.displayPath(
            pane.workingDirectory, homeDirectory: NSHomeDirectory()
        )
        let suffix = workspace.layout.paneCount > 1 ? "  ·  ▮▮ \(workspace.layout.paneCount)" : ""
        workspaceTitles[workspaceID]?.label = displayedTitle
        metadata[workspaceID]?.label = location + suffix
        railRows[workspaceID]?.setTooltip(text: displayedTitle)
        let groupName = snapshot.groups
            .first(where: { $0.workspaces.contains { $0.id == workspaceID } })
            .map { ChromeText.sanitized($0.name, limit: 120) } ?? "workspace group"
        if let row = rows[workspaceID] {
            setAccessibleLabel(row, displayedTitle)
            let panes = workspace.layout.paneCount > 1 ? ", \(workspace.layout.paneCount) panes" : ""
            setAccessibleDescription(row, "Workspace in \(groupName); \(location)\(panes)")
        }
        if let row = railRows[workspaceID] { setAccessibleLabel(row, displayedTitle) }
        liftedTitles[workspaceID]?.label = displayedTitle
        if let liftedRow = attentionRows[workspaceID] ?? pinnedRows[workspaceID] {
            setAccessibleLabel(liftedRow, displayedTitle)
        }
        if snapshot.selectedWorkspaceID == workspaceID { title?.label = displayedTitle }
        configureWorkspacePanePeek(workspaceID)
        filter(sidebarSearchEntry?.text ?? "")
    }

    func buildLayout(_ layout: PaneLayout, workspace: WorkspaceSnapshot) -> (WidgetRef, [TerminalSurface])? {
        switch layout {
        case let .pane(pane):
            let ordinal = (workspace.layout.paneIDs.firstIndex(of: pane.id) ?? 0) + 1
            guard let surface = makeSurface(pane: pane, workspaceID: workspace.id,
                label: "\(workspace.name) \(pane.title)",
                description: "Terminal pane \(ordinal) of \(workspace.layout.paneCount) in the \(workspace.name) workspace")
            else { return nil }
            surface.widget.setHexpand(expand: true); surface.widget.setVexpand(expand: true)
            return (surface.widget, [surface])
        case let .split(axis, fraction, first, second):
            guard let one = buildLayout(first, workspace: workspace), let two = buildLayout(second, workspace: workspace) else { return nil }
            let paned = PanedRef(orientation: axis == .horizontal ? .horizontal : .vertical)
            paned.setWideHandle(wide: true); paned.setStart(child: one.0); paned.setEnd(child: two.0)
            configurePaneDivider(
                paned, axis: axis, fraction: fraction,
                workspaceID: workspace.id, splitPaneIDs: layout.paneIDs
            )
            return (WidgetRef(paned), one.1 + two.1)
        }
    }

    private func buildMountedLayout(_ layout: PaneLayout, workspaceID: UUID) -> WidgetRef? {
        switch layout {
        case let .pane(pane):
            guard let surface = surfacesByPane[pane.id] else { return nil }
            surface.widget.setHexpand(expand: true)
            surface.widget.setVexpand(expand: true)
            return surface.widget
        case let .split(axis, fraction, first, second):
            guard let one = buildMountedLayout(first, workspaceID: workspaceID),
                  let two = buildMountedLayout(second, workspaceID: workspaceID) else {
                return nil
            }
            let paned = PanedRef(orientation: axis == .horizontal ? .horizontal : .vertical)
            paned.setWideHandle(wide: true)
            paned.setStart(child: one)
            paned.setEnd(child: two)
            configurePaneDivider(
                paned, axis: axis, fraction: fraction,
                workspaceID: workspaceID, splitPaneIDs: layout.paneIDs
            )
            return WidgetRef(paned)
        }
    }

    private func configurePaneDivider(
        _ paned: PanedRef,
        axis: SplitAxis,
        fraction: Double,
        workspaceID: UUID,
        splitPaneIDs: [UUID]
    ) {
        let boundedFraction = min(max(fraction, 0.1), 0.9)
        var appliedInitialPosition = false
        var isApplyingPosition = false
        let releaseController = EventControllerLegacy()
        releaseController.setPropagation(phase: .capture)
        _ = releaseController.onEvent { [weak self] _, event in
            guard event.getEventType() == .buttonRelease,
                  gdk_button_event_get_button(event.event_ptr) == 1,
                  appliedInitialPosition,
                  !isApplyingPosition
            else { return false }
            let extent = axis == .horizontal ? paned.getWidth() : paned.getHeight()
            guard extent > 1 else { return false }
            let proposed = Double(paned.getPosition()) / Double(extent)
            let bounded = min(max(proposed, 0.1), 0.9)
            if bounded != proposed {
                isApplyingPosition = true
                paned.set(position: Int((Double(extent) * bounded).rounded()))
                isApplyingPosition = false
            }
            self?.paneDividerMoved(
                workspaceID: workspaceID,
                splitPaneIDs: splitPaneIDs,
                fraction: bounded
            )
            return false
        }
        _ = releaseController.ref()
        gtk_widget_add_controller(paned.widget_ptr, releaseController.event_controller_ptr)
        _ = paned.onNotifyMaxPosition { paned, _ in
            guard !appliedInitialPosition else { return }
            let extent = axis == .horizontal ? paned.getWidth() : paned.getHeight()
            guard extent > 1 else { return }
            isApplyingPosition = true
            paned.set(position: Int((Double(extent) * boundedFraction).rounded()))
            isApplyingPosition = false
            appliedInitialPosition = true
        }
    }

    private func paneDividerMoved(
        workspaceID: UUID,
        splitPaneIDs: [UUID],
        fraction: Double
    ) {
        guard (try? snapshot.setSplitFraction(
            in: workspaceID, splitPaneIDs: splitPaneIDs, to: fraction
        )) == true else { return }
        persist()
    }

    private func remountWorkspaceLayout(_ workspaceID: UUID) -> Bool {
        guard let workspace = snapshot.workspace(id: workspaceID),
              let runtime = runtimes[workspaceID],
              workspace.layout.paneIDs.allSatisfy({ surfacesByPane[$0] != nil })
        else { return false }

        // Include panes removed by the just-committed model mutation. Their
        // surfaces still belong to this workspace until remount succeeds and
        // must be detached before their Ghostty runtime is destroyed.
        let mountedWidgets = workspaceByPane.compactMap { paneID, ownerID in
            ownerID == workspaceID ? surfacesByPane[paneID]?.widget : nil
        }
        for widget in mountedWidgets { _ = widget.ref() }
        if runtime.layoutRoot.getParent()?.widget_ptr == runtime.page.widget_ptr {
            runtime.page.remove(child: runtime.layoutRoot)
        } else if runtime.layoutRoot.getParent() != nil {
            runtime.layoutRoot.unparent()
        }
        // `runtime.layoutRoot` intentionally retains the old GtkPaned tree
        // until the replacement is mounted. Removing that root from the page
        // therefore does not detach its terminal children by itself; release
        // each surviving surface from the old container before reparenting it.
        for widget in mountedWidgets where widget.getParent() != nil {
            widget.unparent()
        }
        guard let root = buildMountedLayout(workspace.layout, workspaceID: workspaceID) else {
            for widget in mountedWidgets { widget.unref() }
            return false
        }
        runtime.page.prepend(child: root)
        runtime.layoutRoot = root
        for widget in mountedWidgets { widget.unref() }
        return true
    }

    private func discardPaneRuntime(_ paneID: UUID) {
        let surface = surfacesByPane.removeValue(forKey: paneID)
        workspaceByPane.removeValue(forKey: paneID)
        surfaceGenerationByPane.removeValue(forKey: paneID)
        lastAgentStateChangeAt.removeValue(forKey: paneID)
        agentEventWatchers.removeValue(forKey: paneID)?.stop()
        guard let surface else { return }
        surfaces.removeAll { $0 === surface }
        surface.requestClose()
        retiringSurfaces.append(surface)
        timeout(add: 50) { [weak self, weak surface] in
            guard let self, let surface else { return false }
            guard surface.processExited else { return true }
            self.retiringSurfaces.removeAll { $0 === surface }
            return false
        }
    }

    func surface(for paneID: UUID) -> TerminalSurface? { surfacesByPane[paneID] }

    private func terminalFocused(_ paneID: UUID) {
        guard let surface = surfacesByPane[paneID], let workspaceID = workspaceByPane[paneID],
              let runtime = runtimes[workspaceID] else { return }
        let changed = snapshot.workspace(id: workspaceID)?.focusedPaneID != paneID
        if changed { try? snapshot.focusPane(paneID, in: workspaceID) }
        runtime.focusedPaneID = paneID; runtime.focusedSurface = surface
        focusedPaneID = paneID; focusedSurface = surface
        if changed { refreshWorkspaceRowPresentation(workspaceID) }
        updateChrome(workspaceID)
        scheduleAttentionAcknowledgement(workspaceID: workspaceID, paneID: paneID)
        if changed { persist() }
    }

    func focus(_ paneID: UUID) {
        guard let surface = surfacesByPane[paneID] else { return }
        terminalFocused(paneID); surface.focus()
    }

    func registerGroup(_ group: SidebarGroupSection, root: BoxRef, body: BoxRef,
                       chevron: LabelRef, count: LabelRef, name: LabelRef? = nil, marker: LabelRef? = nil) {
        groupRoots[group.id] = root; groupBodies[group.id] = body; groupChevrons[group.id] = chevron
        groupCounts[group.id] = count
        if let name { groupNames[group.id] = name }
        if let marker { groupMarkers[group.id] = marker }
        workspaceIDsByGroup[group.id] = group.rows.map(\.id)
        body.set(visible: group.isExpanded)
        applySidebarDensityGeometry()
    }

    func attachGroupsContainer(_ groups: BoxRef) {
        groupsContainer = groups
        applySidebarDensityGeometry()
    }

    func attachEmptyState(
        page: BoxRef, copy: LabelRef, reopen: ButtonRef, collapsedAction: ButtonRef
    ) {
        emptyWorkspacePage = page
        emptyWorkspaceCopy = copy
        emptyWorkspaceReopen = reopen
        collapsedEmptyAction = collapsedAction
        refreshEmptyState()
    }

    private func refreshEmptyState() {
        let presentation = EmptyWorkspacePresentation.resolve(snapshot: snapshot, isFiltering: isSidebarFiltering)
        collapsedEmptyAction?.set(visible: presentation.showsCollapsedSidebarAction)
        emptyWorkspaceReopen?.set(visible: presentation.showsReopenAction)
        emptyWorkspaceCopy?.label = presentation.visibleCopy
        if let copy = emptyWorkspaceCopy { setAccessibleDescription(copy, presentation.accessibleCopy) }
        if snapshot.selectedWorkspaceID == nil, let stack {
            "awesomux-empty-workspace".withCString { stack.setVisibleChild(name: $0) }
            title?.label = ""
            focusedPaneID = nil; focusedSurface = nil
        }
    }

    func reopenLastClosedWorkspace() { reopenMostRecentlyClosedWorkspace() }

    func attachLiftedSections(
        attention: (Revealer, BoxRef, BoxRef), pinned: (Revealer, BoxRef, BoxRef)
    ) {
        attentionSectionRoot = attention.0
        attentionSectionContent = attention.1
        attentionSectionBody = attention.2
        pinnedSectionRoot = pinned.0
        pinnedSectionContent = pinned.1
        pinnedSectionBody = pinned.2
        applySidebarDensityGeometry()
    }

    private func updateLiftedSectionVisibility(
        _ revealer: Revealer?, content: BoxRef?, visible: Bool,
        isFiltering: Bool
    ) {
        guard let revealer, let content else { return }
        let appearance = GTKChromeAppearance.resolve(preference: preferences.theme)
        let duration = SidebarStructuralMotionPolicy.duration(
            reducesMotion: appearance.reducesMotion,
            isFiltering: isFiltering,
            isInitialLayout: !hasAppliedLiftedSectionVisibility
        )
        revealer.setTransition(duration: duration)
        if visible {
            revealer.set(visible: true)
            setAccessibleHidden(content, false)
            revealer.set(revealChild: true)
        } else {
            setAccessibleHidden(content, true)
            revealer.set(revealChild: false)
            guard duration > 0 else {
                revealer.set(visible: false)
                return
            }
            timeout(add: duration + 20) { [weak revealer] in
                guard let revealer, !revealer.getRevealChild() else { return false }
                revealer.set(visible: false)
                return false
            }
        }
    }

    func toggleGroup(_ groupID: UUID) {
        guard (try? snapshot.toggleGroupDisclosure(groupID)) != nil,
              let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        groupBodies[groupID]?.set(visible: !group.isCollapsed)
        groupChevrons[groupID]?.label = group.isCollapsed ? "›" : "⌄"
        groupHeaderChrome[groupID]?.isCollapsed = group.isCollapsed
        refreshGroupAttention(groupID)
        if let disclosure = groupDisclosures[groupID] { setAccessibleExpanded(disclosure, !group.isCollapsed) }
        announce("\(ChromeText.sanitized(group.name, limit: 120)) group \(group.isCollapsed ? "collapsed" : "expanded")")
        persist()
    }

    func filter(_ query: String) {
        let projection = SidebarLiftedProjection.project(snapshot: snapshot, query: query)
        isSidebarFiltering = projection.isFiltering
        searchResultIDs = projection.isFiltering ? projection.orderedWorkspaceIDs : []
        searchResultIndex = 0
        updateSearchResultHighlight()
        let regularWorkspaceIDs = Set(projection.groups.flatMap { $0.rows.map(\.id) })
        let attentionWorkspaceIDs = Set(projection.attention.map { $0.row.id })
        let pinnedWorkspaceIDs = Set(projection.pinned.map { $0.row.id })
        let projectedRows = projection.attention.map(\.row) + projection.pinned.map(\.row)
            + projection.groups.flatMap(\.rows)
        let projectedByID = Dictionary(uniqueKeysWithValues: projectedRows.map { ($0.id, $0) })
        for (id, label) in workspaceTitles { applySearchMatches(projectedByID[id]?.titleMatches ?? [], to: label) }
        for (id, label) in metadata { applySearchMatches(projectedByID[id]?.locationMatches ?? [], to: label) }
        for (id, label) in liftedTitles { applySearchMatches(projectedByID[id]?.titleMatches ?? [], to: label) }
        let visibleGroupIDs = Set(projection.groups.map(\.id))
        for (index, group) in projection.groups.enumerated() {
            if let disclosure = groupDisclosures[group.id] {
                setAccessibleSetPosition(disclosure, position: index + 1, count: projection.groups.count)
                refreshGroupAttention(group.id, projectedPosition: (index + 1, projection.groups.count))
            }
            for (rowIndex, projectedRow) in group.rows.enumerated() {
                if let row = rows[projectedRow.id] {
                    setAccessibleSetPosition(row, position: rowIndex + 1, count: group.rows.count)
                    refreshRegularWorkspaceAccessibility(
                        projectedRow.id, position: (rowIndex + 1, group.rows.count)
                    )
                }
            }
        }
        for (index, item) in projection.attention.enumerated() {
            if let row = attentionRows[item.row.id] {
                setAccessibleSetPosition(row, position: index + 1, count: projection.attention.count)
                refreshLiftedWorkspaceAccessibility(
                    item, attention: true, position: (index + 1, projection.attention.count)
                )
            }
        }
        for (index, item) in projection.pinned.enumerated() {
            if let row = pinnedRows[item.row.id] {
                setAccessibleSetPosition(row, position: index + 1, count: projection.pinned.count)
                refreshLiftedWorkspaceAccessibility(
                    item, attention: false, position: (index + 1, projection.pinned.count)
                )
            }
        }
        for group in snapshot.groups {
            for id in workspaceIDsByGroup[group.id] ?? [] {
                let visible = regularWorkspaceIDs.contains(id)
                rows[id]?.set(visible: visible); regularRowChrome[id]?.root.set(visible: visible)
            }
            groupRoots[group.id]?.set(visible: !projection.isFiltering || visibleGroupIDs.contains(group.id))
            groupBodies[group.id]?.set(visible: projection.isFiltering ? visibleGroupIDs.contains(group.id) : !group.isCollapsed)
        }
        for (id, row) in attentionRows {
            let visible = attentionWorkspaceIDs.contains(id)
            row.set(visible: visible); liftedRowChrome[id]?.root.set(visible: visible)
        }
        for (id, row) in pinnedRows {
            let visible = pinnedWorkspaceIDs.contains(id)
            row.set(visible: visible); liftedRowChrome[id]?.root.set(visible: visible)
        }
        updateLiftedSectionVisibility(
            attentionSectionRoot, content: attentionSectionContent,
            visible: !projection.attention.isEmpty, isFiltering: projection.isFiltering
        )
        updateLiftedSectionVisibility(
            pinnedSectionRoot, content: pinnedSectionContent,
            visible: !projection.pinned.isEmpty, isFiltering: projection.isFiltering
        )
        hasAppliedLiftedSectionVisibility = true
        refreshRailProjection(projection)
        let showsNoMatches = projection.isFiltering && projection.orderedWorkspaceIDs.isEmpty
        noMatchesRoot?.set(visible: showsNoMatches)
        if showsNoMatches {
            let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
            noMatchesDescription?.label = "Nothing matched \"\(ChromeText.sanitized(normalized, limit: 120))\"."
        }
        refreshGroupTints()
        refreshGroupActionEnablement()
        refreshEmptyState()
    }

    private func refreshRailProjection(_ projection: SidebarLiftedOutput) {
        guard let sidebarRailRows else { return }
        let visible = Set(projection.orderedWorkspaceIDs)
        let attention = Set(projection.attention.map { $0.row.id })
        let pinned = Set(projection.pinned.map { $0.row.id })
        var previous: WidgetRef?
        for (index, id) in projection.orderedWorkspaceIDs.enumerated() {
            guard let row = railRows[id] else { continue }
            setAccessibleSetPosition(row, position: index + 1, count: projection.orderedWorkspaceIDs.count)
            refreshRailWorkspaceAccessibility(
                id, attention: attention.contains(id), pinned: pinned.contains(id),
                position: (index + 1, projection.orderedWorkspaceIDs.count)
            )
            row.set(visible: true)
            row.remove(cssClass: "aw-lifted-attention"); row.remove(cssClass: "aw-lifted-pinned")
            if attention.contains(id) {
                row.add(cssClass: "aw-lifted-attention")
                let name = snapshot.workspace(id: id)?.name ?? "Workspace"
                row.setTooltip(text: "Needs input: \(ChromeText.sanitized(name, limit: 120))")
            } else if pinned.contains(id) {
                row.add(cssClass: "aw-lifted-pinned")
                let name = snapshot.workspace(id: id)?.name ?? "Workspace"
                row.setTooltip(text: "Pinned: \(ChromeText.sanitized(name, limit: 120))")
            } else {
                row.setTooltip(text: ChromeText.sanitized(snapshot.workspace(id: id)?.name ?? "Workspace", limit: 120))
            }
            if let previous {
                sidebarRailRows.reorderChildAfter(child: WidgetRef(row), sibling: previous)
            } else {
                sidebarRailRows.reorderChildAfter(child: WidgetRef(row), sibling: nil as WidgetRef?)
            }
            previous = WidgetRef(row)
        }
        for (id, row) in railRows where !visible.contains(id) { row.set(visible: false) }
        refreshRailJumpNumbers()
        guard !projection.isFiltering else {
            for row in railGroupRows.values { row.set(visible: false) }
            return
        }
        let lifted = Set(projection.attention.map { $0.row.id } + projection.pinned.map { $0.row.id })
        for (index, group) in snapshot.groups.enumerated() {
            guard let groupRow = railGroupRows[group.id] else { continue }
            setAccessibleSetPosition(groupRow, position: index + 1, count: snapshot.groups.count)
            groupRow.set(visible: true)
            sidebarRailRows.reorderChildAfter(child: WidgetRef(groupRow), sibling: previous)
            previous = WidgetRef(groupRow)
            for workspace in group.workspaces where !workspace.isSoftClosed && !lifted.contains(workspace.id) {
                guard let row = railRows[workspace.id] else { continue }
                sidebarRailRows.reorderChildAfter(child: WidgetRef(row), sibling: previous)
                previous = WidgetRef(row)
            }
        }
    }

    private func refreshRailJumpNumbers() {
        let order = SidebarLiftedProjection.project(snapshot: snapshot, query: "").orderedWorkspaceIDs
        let indexed = Dictionary(
            uniqueKeysWithValues: order.prefix(9).enumerated().map { ($0.element, $0.offset + 1) }
        )
        let display = SidebarJumpNumberDisplay.resolve(
            collapsed: preferences.sidebarWidth < SidebarWidthPolicy.railThreshold,
            alwaysShow: false,
            primaryModifierHeld: isWorkspaceJumpModifierHeld
        )
        for (id, label) in railJumpNumberLabels {
            guard let index = indexed[id] else { label.set(visible: false); continue }
            label.label = "\(index)"
            label.set(visible: display == .overlay)
        }
    }

    func attachSearch(entry: SearchEntryRef, noMatches: BoxRef, description: LabelRef) {
        sidebarSearchEntry = entry
        noMatchesRoot = noMatches
        noMatchesDescription = description
    }

    func retainSearchController(_ controller: EventControllerKey) {
        searchKeyController = controller
    }

    func retainSidebarNavigationController(_ controller: EventControllerKey) {
        sidebarNavigationKeyController = controller
    }

    func retainGlobalModifierController(_ controller: EventControllerKey) {
        globalModifierKeyController = controller
    }

    func handleGlobalKeyPressed(_ keyval: UInt, state: Gdk.ModifierType) -> Bool {
        let held = keyval == UInt(GDK_KEY_Control_L)
            || keyval == UInt(GDK_KEY_Control_R)
            || state.contains(.controlMask)
        if held != isWorkspaceJumpModifierHeld {
            isWorkspaceJumpModifierHeld = held
            refreshRailJumpNumbers()
        }
        return false
    }

    func handleGlobalKeyReleased(_ keyval: UInt, state: Gdk.ModifierType) {
        let held = keyval != UInt(GDK_KEY_Control_L)
            && keyval != UInt(GDK_KEY_Control_R)
            && state.contains(.controlMask)
        if held != isWorkspaceJumpModifierHeld {
            isWorkspaceJumpModifierHeld = held
            refreshRailJumpNumbers()
        }
    }

    private func sidebarNavigationWidgets() -> [WidgetRef] {
        var result: [WidgetRef] = []
        for id in snapshot.attentionWorkspaceIDs {
            if let row = attentionRows[id], row.getVisible() { result.append(WidgetRef(row)) }
        }
        for id in snapshot.pinnedWorkspaceIDs where attentionRows[id] == nil {
            if let row = pinnedRows[id], row.getVisible() { result.append(WidgetRef(row)) }
        }
        for group in snapshot.groups {
            guard groupRoots[group.id]?.getVisible() == true else { continue }
            if let disclosure = groupDisclosures[group.id] { result.append(WidgetRef(disclosure)) }
            guard groupBodies[group.id]?.getVisible() == true else { continue }
            for id in workspaceIDsByGroup[group.id] ?? [] {
                if let row = rows[id], row.getVisible() { result.append(WidgetRef(row)) }
            }
            if let create = groupCreateRows[group.id], create.getVisible() { result.append(WidgetRef(create)) }
        }
        return result
    }

    func handleSidebarNavigationKey(_ keyval: UInt) -> Bool {
        let key: SidebarNavigationKey
        switch keyval {
        case UInt(GDK_KEY_Up): key = .previous
        case UInt(GDK_KEY_Down): key = .next
        case UInt(GDK_KEY_Home): key = .first
        case UInt(GDK_KEY_End): key = .last
        default: return false
        }
        let widgets = sidebarNavigationWidgets()
        let current = widgets.firstIndex { gtk_widget_has_focus($0.widget_ptr) != 0 }
        guard let destination = SidebarKeyboardNavigationPolicy.destination(
            current: current, count: widgets.count, key: key
        ) else { return true }
        _ = widgets[destination].grabFocus()
        return true
    }

    func retainSidebarMotionController(_ controller: EventControllerMotion) {
        sidebarMotionController = controller
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
            guard SidebarKeyboardNavigationPolicy.searchConsumesArrow(
                resultCount: searchResultIDs.count
            ) else { return handleSidebarNavigationKey(keyval) }
            searchResultIndex = min(searchResultIndex + 1, searchResultIDs.count - 1)
            updateSearchResultHighlight()
            return true
        case UInt(GDK_KEY_Up):
            guard SidebarKeyboardNavigationPolicy.searchConsumesArrow(
                resultCount: searchResultIDs.count
            ) else { return handleSidebarNavigationKey(keyval) }
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
                 page: BoxRef, layoutRoot: WidgetRef, pathBar: FocusedPanePathBar,
                 focusedSurface: TerminalSurface) {
        runtimes[workspace.id] = WorkspaceRuntime(groupID: groupID, pageName: pageName,
            page: page, layoutRoot: layoutRoot,
            pathBar: pathBar, focusedPaneID: workspace.focusedPaneID, focusedSurface: focusedSurface)
    }

    private func sidebarDragPayload(for item: SidebarDragItem) -> String {
        let kind: String
        let id: UUID
        switch item {
        case let .workspace(value): kind = "workspace"; id = value
        case let .pinned(value): kind = "pinned"; id = value
        case let .group(value): kind = "group"; id = value
        }
        return "awesomux-sidebar:\(sidebarDragNonce):\(kind):\(id.uuidString)"
    }

    private func sidebarDragItem(from value: ValueRef) -> SidebarDragItem? {
        guard let payload = value.getString() else { return nil }
        let fields = payload.split(separator: ":", omittingEmptySubsequences: false)
        guard fields.count == 4, fields[0] == "awesomux-sidebar",
              fields[1] == Substring(sidebarDragNonce), let id = UUID(uuidString: String(fields[3]))
        else { return nil }
        switch fields[2] {
        case "workspace": return .workspace(id)
        case "pinned": return .pinned(id)
        case "group": return .group(id)
        default: return nil
        }
    }

    private func makeSidebarDragSource(on host: WidgetRef, item: SidebarDragItem) -> DragSource {
        let source = DragSource()
        source.set(actions: isSidebarFiltering ? Gdk.DragAction(rawValue: 0) : .move)
        source.set(content: Gdk.ContentProvider(value: Value(sidebarDragPayload(for: item))))
        source.onDragBegin { [weak self] _, _ in self?.beginSidebarDrag(item) }
        source.onDragEnd { [weak self] _, _, _ in self?.endSidebarDrag(item) }
        source.onDragCancel { [weak self] _, _, _ in self?.endSidebarDrag(item); return false }
        _ = source.ref()
        gtk_widget_add_controller(host.widget_ptr, source.event_controller_ptr)
        return source
    }

    private func beginSidebarDrag(_ item: SidebarDragItem) {
        guard !isSidebarFiltering else { return }
        activeSidebarDrag = item
        for chrome in groupHeaderChrome.values { chrome.isDragActive = true }
        for id in workspacePanePeekPopovers.keys { dismissWorkspacePanePeek(id) }
    }

    private func endSidebarDrag(_ item: SidebarDragItem) {
        guard activeSidebarDrag == item else { return }
        activeSidebarDrag = nil
        clearSidebarDropIndicators()
        for chrome in groupHeaderChrome.values { chrome.isDragActive = false }
    }

    private func clearSidebarDropIndicators() {
        for chrome in regularRowChrome.values { clearDropIndicator(on: WidgetRef(chrome.root)) }
        for chrome in liftedRowChrome.values { clearDropIndicator(on: WidgetRef(chrome.root)) }
        for chrome in groupHeaderChrome.values { clearDropIndicator(on: WidgetRef(chrome.root)) }
    }

    private func clearDropIndicator(on widget: WidgetRef) {
        widget.remove(cssClass: "aw-drop-before")
        widget.remove(cssClass: "aw-drop-after")
        widget.remove(cssClass: "aw-drop-into")
    }

    private func showDropIndicator(on widget: WidgetRef, edge: SidebarInsertionEdge) {
        clearSidebarDropIndicators()
        widget.add(cssClass: edge == .before ? "aw-drop-before" : "aw-drop-after")
    }

    private func insertionEdge(y: Double, in widget: WidgetRef) -> SidebarInsertionEdge {
        y < Double(max(widget.getHeight(), 1)) / 2 ? .before : .after
    }

    private func installRegularWorkspaceDrag(on chrome: WorkspaceRowChrome, workspaceID: UUID) {
        let source = makeSidebarDragSource(on: WidgetRef(chrome.row), item: .workspace(workspaceID))
        regularWorkspaceDragSources[workspaceID] = source
        let target = DropTarget(type: GType.string, actions: .move)
        target.onEnter { [weak self, root = chrome.root] _, _, y in
            self?.updateWorkspaceDropIndicator(targetID: workspaceID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onMotion { [weak self, root = chrome.root] _, _, y in
            self?.updateWorkspaceDropIndicator(targetID: workspaceID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onLeave { [weak self, root = chrome.root] _ in self?.clearDropIndicator(on: WidgetRef(root)) }
        target.onDrop { [weak self, root = chrome.root] _, value, _, y in
            guard let self, self.sidebarDragItem(from: value) == self.activeSidebarDrag else { return false }
            let accepted = self.dropWorkspace(on: workspaceID, edge: self.insertionEdge(y: y, in: WidgetRef(root)))
            self.clearSidebarDropIndicators()
            return accepted
        }
        _ = target.ref(); gtk_widget_add_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        regularWorkspaceDropTargets[workspaceID] = target
    }

    private func updateWorkspaceDropIndicator(
        targetID: UUID, root: OverlayRef, y: Double
    ) -> Gdk.DragAction {
        guard !isSidebarFiltering, case let .workspace(sourceID) = activeSidebarDrag,
              workspaceDropDestination(
                sourceID: sourceID, targetID: targetID,
                edge: insertionEdge(y: y, in: WidgetRef(root))
              ) != nil else {
            clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
        }
        showDropIndicator(on: WidgetRef(root), edge: insertionEdge(y: y, in: WidgetRef(root)))
        return .move
    }

    private func installPinnedWorkspaceDrag(on chrome: WorkspaceRowChrome, workspaceID: UUID) {
        let source = makeSidebarDragSource(on: WidgetRef(chrome.row), item: .pinned(workspaceID))
        pinnedWorkspaceDragSources[workspaceID] = source
        let target = DropTarget(type: GType.string, actions: .move)
        target.onEnter { [weak self, root = chrome.root] _, _, y in
            self?.updatePinnedDropIndicator(targetID: workspaceID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onMotion { [weak self, root = chrome.root] _, _, y in
            self?.updatePinnedDropIndicator(targetID: workspaceID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onLeave { [weak self, root = chrome.root] _ in self?.clearDropIndicator(on: WidgetRef(root)) }
        target.onDrop { [weak self, root = chrome.root] _, value, _, y in
            guard let self, self.sidebarDragItem(from: value) == self.activeSidebarDrag else { return false }
            let accepted = self.dropPinnedWorkspace(on: workspaceID, edge: self.insertionEdge(y: y, in: WidgetRef(root)))
            self.clearSidebarDropIndicators()
            return accepted
        }
        _ = target.ref(); gtk_widget_add_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        pinnedWorkspaceDropTargets[workspaceID] = target
    }

    private func updatePinnedDropIndicator(
        targetID: UUID, root: OverlayRef, y: Double
    ) -> Gdk.DragAction {
        guard !isSidebarFiltering, case let .pinned(sourceID) = activeSidebarDrag,
              pinnedDropDestination(
                sourceID: sourceID, targetID: targetID,
                edge: insertionEdge(y: y, in: WidgetRef(root))
              ) != nil else {
            clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
        }
        showDropIndicator(on: WidgetRef(root), edge: insertionEdge(y: y, in: WidgetRef(root)))
        return .move
    }

    private func installGroupDrag(on chrome: GroupHeaderChrome, groupID: UUID) {
        groupDragSources[groupID] = makeSidebarDragSource(on: WidgetRef(chrome.root), item: .group(groupID))
        let target = DropTarget(type: GType.string, actions: .move)
        target.onEnter { [weak self, root = chrome.root] _, _, y in
            self?.updateGroupDropIndicator(targetID: groupID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onMotion { [weak self, root = chrome.root] _, _, y in
            self?.updateGroupDropIndicator(targetID: groupID, root: root, y: y) ?? Gdk.DragAction(rawValue: 0)
        }
        target.onLeave { [weak self, root = chrome.root] _ in self?.clearDropIndicator(on: WidgetRef(root)) }
        target.onDrop { [weak self, root = chrome.root] _, value, _, y in
            guard let self, self.sidebarDragItem(from: value) == self.activeSidebarDrag else { return false }
            let accepted = self.drop(onGroupHeader: groupID, edge: self.insertionEdge(y: y, in: WidgetRef(root)))
            self.clearSidebarDropIndicators()
            return accepted
        }
        _ = target.ref(); gtk_widget_add_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        groupDropTargets[groupID] = target
    }

    private func detachRegularWorkspaceDrag(_ workspaceID: UUID) {
        if let source = regularWorkspaceDragSources.removeValue(forKey: workspaceID),
           let row = rows[workspaceID] {
            gtk_widget_remove_controller(row.widget_ptr, source.event_controller_ptr)
        }
        if let target = regularWorkspaceDropTargets.removeValue(forKey: workspaceID),
           let chrome = regularRowChrome[workspaceID] {
            gtk_widget_remove_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        }
    }

    private func detachPinnedWorkspaceDrag(_ workspaceID: UUID) {
        if let source = pinnedWorkspaceDragSources.removeValue(forKey: workspaceID),
           let row = pinnedRows[workspaceID] {
            gtk_widget_remove_controller(row.widget_ptr, source.event_controller_ptr)
        }
        if let target = pinnedWorkspaceDropTargets.removeValue(forKey: workspaceID),
           let chrome = liftedRowChrome[workspaceID] {
            gtk_widget_remove_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        }
    }

    private func detachGroupDrag(_ groupID: UUID) {
        guard let chrome = groupHeaderChrome[groupID] else {
            groupDragSources.removeValue(forKey: groupID)
            groupDropTargets.removeValue(forKey: groupID)
            return
        }
        if let source = groupDragSources.removeValue(forKey: groupID) {
            gtk_widget_remove_controller(chrome.root.widget_ptr, source.event_controller_ptr)
        }
        if let target = groupDropTargets.removeValue(forKey: groupID) {
            gtk_widget_remove_controller(chrome.root.widget_ptr, target.event_controller_ptr)
        }
    }

    private func refreshSidebarDragAvailability() {
        let actions: Gdk.DragAction = isSidebarFiltering ? Gdk.DragAction(rawValue: 0) : .move
        for source in regularWorkspaceDragSources.values { source.set(actions: actions) }
        for source in pinnedWorkspaceDragSources.values { source.set(actions: actions) }
        for source in groupDragSources.values { source.set(actions: actions) }
        for target in regularWorkspaceDropTargets.values { target.set(actions: actions) }
        for target in pinnedWorkspaceDropTargets.values { target.set(actions: actions) }
        for target in groupDropTargets.values { target.set(actions: actions) }
        if isSidebarFiltering {
            activeSidebarDrag = nil
            clearSidebarDropIndicators()
            for chrome in groupHeaderChrome.values { chrome.isDragActive = false }
        }
    }

    private func updateGroupDropIndicator(
        targetID: UUID, root: OverlayRef, y: Double
    ) -> Gdk.DragAction {
        guard !isSidebarFiltering, let activeSidebarDrag else {
            clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
        }
        switch activeSidebarDrag {
        case let .group(sourceID):
            guard groupDropDestination(
                sourceID: sourceID, targetID: targetID,
                edge: insertionEdge(y: y, in: WidgetRef(root))
            ) != nil else {
                clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
            }
            showDropIndicator(on: WidgetRef(root), edge: insertionEdge(y: y, in: WidgetRef(root)))
        case let .workspace(sourceID):
            guard groupHeaderWorkspaceDestination(sourceID: sourceID, groupID: targetID) != nil else {
                clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
            }
            clearSidebarDropIndicators(); root.add(cssClass: "aw-drop-into")
        case .pinned:
            clearDropIndicator(on: WidgetRef(root)); return Gdk.DragAction(rawValue: 0)
        }
        return .move
    }

    func makeRow(workspace: WorkspaceSnapshot, groupID: UUID) -> OverlayRef {
        let row = makeAccessibleToggleButton(role: GTK_ACCESSIBLE_ROLE_TREE_ITEM)
        row.add(cssClass: "aw-row"); row.setHalign(align: .fill)
        setAccessibleLevel(row, 2)
        let groupIndex = snapshot.groups.firstIndex(where: { $0.id == groupID }) ?? 0
        let group = snapshot.groups[groupIndex]
        let groupColor = SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: groupIndex)
        row.add(cssClass: "aw-\(groupColor.rawValue)")
        let content = BoxRef(orientation: .horizontal, spacing: 10); content.setMarginEnd(margin: 28)
        let agentTile = SidebarAgentTilePresentation.project(workspace: workspace)
        let agentHost = BoxRef(orientation: .horizontal, spacing: 0)
        let agentWidget = makeAgentTile(agentTile, size: 32)
        agentHost.append(child: agentWidget); content.append(child: agentHost)
        let details = BoxRef(orientation: .vertical, spacing: 2); details.setHexpand(expand: true)
        let name = LabelRef(str: SidebarWorkspaceTitle.resolve(workspace: workspace))
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
        let safeName = SidebarWorkspaceTitle.resolve(workspace: workspace)
        setAccessibleLabel(row, safeName)
        let paneDescription = workspace.layout.paneCount > 1 ? ", \(workspace.layout.paneCount) panes" : ""
        setAccessibleDescription(row, "Workspace in \(ChromeText.sanitized(group.name, limit: 120)); \(location)\(paneDescription); \(agentTile.accessibilityLabel); Actions menu: Shift+F10")
        setAccessibleHasPopup(row)
        installWorkspaceContextMenu(on: row, workspaceID: workspace.id, groupID: groupID)
        installWorkspacePanePeek(on: row, workspace: workspace)
        rows[workspace.id] = row; metadata[workspace.id] = meta; workspaceTitles[workspace.id] = name
        regularAgentTileHosts[workspace.id] = agentHost; regularAgentTiles[workspace.id] = agentWidget
        if !(workspaceIDsByGroup[groupID] ?? []).contains(workspace.id) { workspaceIDsByGroup[groupID, default: []].append(workspace.id) }
        let chrome = WorkspaceRowChrome(row: row) { [weak self] in self?.requestSoftCloseWorkspace(workspace.id) }
        regularRowChrome[workspace.id] = chrome
        installRegularWorkspaceDrag(on: chrome, workspaceID: workspace.id)
        return chrome.root
    }

    func makeRailRow(workspace: WorkspaceSnapshot) -> ToggleButtonRef {
        let button = makeAccessibleToggleButton(role: GTK_ACCESSIBLE_ROLE_LIST_ITEM)
        button.add(cssClass: "aw-rail-row")
        button.setSizeRequest(width: 40, height: 40)
        let agentTile = SidebarAgentTilePresentation.project(workspace: workspace)
        let content = OverlayRef()
        let agentHost = BoxRef(orientation: .horizontal, spacing: 0)
        let agentWidget = makeAgentTile(agentTile, size: 28, collapsed: true)
        agentHost.append(child: agentWidget); content.set(child: agentHost)
        let jumpNumber = LabelRef(str: ""); jumpNumber.add(cssClass: "aw-jump-overlay")
        jumpNumber.setSizeRequest(width: 40, height: 40)
        jumpNumber.setHalign(align: .center); jumpNumber.setValign(align: .center)
        jumpNumber.set(visible: false)
        content.addOverlay(widget: jumpNumber)
        button.set(child: content)
        let displayedTitle = SidebarWorkspaceTitle.resolve(workspace: workspace)
        button.setTooltip(text: displayedTitle)
        setAccessibleLabel(button, displayedTitle)
        setAccessibleDescription(button, "Workspace; \(agentTile.accessibilityLabel)")
        button.onClicked { [weak self] _ in self?.select(workspace.id) }
        railRows[workspace.id] = button
        railAgentTileHosts[workspace.id] = agentHost; railAgentTiles[workspace.id] = agentWidget
        railJumpNumberLabels[workspace.id] = jumpNumber
        refreshRailJumpNumbers()
        return button
    }

    func makeRailGroupRow(group: WorkspaceGroupSnapshot, color: WorkspaceGroupColor?) -> MenuButtonRef {
        let button = MenuButtonRef(); button.add(cssClass: "aw-rail-group")
        button.set(alwaysShowArrow: false); button.set(hasFrame: false)
        button.setSizeRequest(width: 40, height: 28)
        let content = BoxRef(orientation: .vertical, spacing: 2)
        let marker = LabelRef(str: "━"); marker.add(cssClass: "aw-rail-group-marker")
        marker.add(cssClass: "aw-\((color ?? .blue).rawValue)")
        let attention = LabelRef(str: ""); attention.add(cssClass: "aw-rail-group-attention")
        content.append(child: marker); content.append(child: attention); button.set(child: content)
        railGroupRows[group.id] = button; railGroupAttentionLabels[group.id] = attention
        refreshRailGroupRoster(group.id); refreshGroupAttention(group.id)
        return button
    }

    private func paneStateLabel(_ state: AgentState) -> String {
        switch state {
        case .idle: "Idle"
        case .running: "Running"
        case .waiting: "Waiting"
        case .thinking: "Thinking"
        case .output: "Output"
        case .needsAttention: "Needs Attention"
        case .done: "Done"
        case .error: "Error"
        }
    }

    private func makeAgentTile(
        _ presentation: SidebarAgentTilePresentation, size: Int, collapsed: Bool = false
    ) -> OverlayRef {
        let tile = OverlayRef(); tile.add(cssClass: "aw-agent-tile")
        tile.setSizeRequest(width: collapsed ? size : size + 5, height: collapsed ? size : size + 5)
        let symbol = LabelRef(str: ""); symbol.add(cssClass: "aw-agent-symbol")
        symbol.setSizeRequest(width: size, height: size)
        symbol.setHalign(align: collapsed ? .center : .start)
        symbol.setValign(align: collapsed ? .center : .start)
        tile.set(child: symbol)
        let glyph = AgentGlyphDrawing.make(kind: presentation.kind, tileSize: size)
        glyph.setHalign(align: collapsed ? .center : .start)
        glyph.setValign(align: collapsed ? .center : .start)
        tile.addOverlay(widget: glyph)
        if presentation.showsBadge {
            let loudGlyph = [.needsAttention, .error].contains(presentation.state)
            let badgeText = collapsed && !loudGlyph ? "" : presentation.badgeSymbol
            let badge = LabelRef(str: badgeText); badge.add(cssClass: "aw-agent-status")
            badge.add(cssClass: "aw-agent-status-\(presentation.stateToken)")
            if collapsed { badge.add(cssClass: "aw-agent-status-collapsed") }
            badge.setSizeRequest(width: collapsed ? 13 : 14, height: collapsed ? 13 : 14)
            badge.setHalign(align: .end); badge.setValign(align: .end)
            tile.addOverlay(widget: badge)
        }
        setAccessibleLabel(tile, presentation.accessibilityLabel)
        return tile
    }

    private func configureWorkspacePanePeek(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID),
              let popover = workspacePanePeekPopovers[workspaceID]
        else { return }
        if let hosts = workspacePanePeekCardMotionHosts[workspaceID],
           let controllers = workspacePanePeekCardMotionControllers[workspaceID] {
            for (host, controller) in zip(hosts, controllers) {
                gtk_widget_remove_controller(host.widget_ptr, controller.event_controller_ptr)
            }
        }
        let box = BoxRef(orientation: .vertical, spacing: 3); box.add(cssClass: "aw-pane-peek")
        var cardMotionHosts: [WidgetRef] = []
        var cardMotionControllers: [EventControllerMotion] = []
        func retainCardPointer(on host: WidgetRef) {
            let motion = EventControllerMotion(); motion.propagationPhase = .capture
            motion.onEnter { [weak self] _, _, _ in
                self?.setPanePeekPresence(.cardPointer, present: true, workspaceID: workspaceID)
            }
            motion.onLeave { [weak self] _ in
                self?.setPanePeekPresence(.cardPointer, present: false, workspaceID: workspaceID)
            }
            _ = motion.ref(); gtk_widget_add_controller(host.widget_ptr, motion.event_controller_ptr)
            cardMotionHosts.append(host); cardMotionControllers.append(motion)
        }
        retainCardPointer(on: WidgetRef(box))
        box.setSizeRequest(width: 204, height: -1)
        let header = BoxRef(orientation: .horizontal, spacing: 8)
        let rollup = SidebarAgentTilePresentation.project(workspace: workspace)
        let headerText = BoxRef(orientation: .vertical, spacing: 1); headerText.setHexpand(expand: true)
        let heading = LabelRef(str: SidebarWorkspaceTitle.resolve(workspace: workspace))
        heading.add(cssClass: "aw-pane-peek-heading"); heading.xalign = 0
        heading.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3)); heading.setMaxWidthChars(nChars: 18)
        let summary = LabelRef(str: paneStateLabel(rollup.state)); summary.add(cssClass: "aw-pane-peek-summary")
        summary.xalign = 0
        headerText.append(child: heading); headerText.append(child: summary)
        header.append(child: makeAgentTile(rollup, size: 28)); header.append(child: headerText); box.append(child: header)
        if let focused = workspace.layout.pane(id: workspace.focusedPaneID) {
            let prefix = focused.ownership == .remoteZmx ? "⌁  " : ""
            let location = LabelRef(str: prefix + FocusedPaneContext.displayPath(
                focused.workingDirectory, homeDirectory: NSHomeDirectory()
            ))
            location.add(cssClass: "aw-pane-peek-location"); location.xalign = 0
            location.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2)); location.setMaxWidthChars(nChars: 28)
            box.append(child: location)
        }
        let divider = SeparatorRef(orientation: .horizontal); divider.add(cssClass: "aw-pane-peek-divider")
        box.append(child: divider)
        for item in SidebarPanePeekItem.project(workspace: workspace) {
            let row = ButtonRef(); row.add(cssClass: "aw-pane-peek-row"); row.setHalign(align: .fill)
            let content = BoxRef(orientation: .horizontal, spacing: 8)
            let number = LabelRef(str: "\(item.paneNumber)"); number.add(cssClass: "aw-pane-peek-number")
            let paneTile = SidebarAgentTilePresentation.project(agent: item.agent, state: item.state)
            let title = LabelRef(str: item.title); title.add(cssClass: "aw-pane-peek-title"); title.xalign = 0
            title.setHexpand(expand: true); title.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
            title.setMaxWidthChars(nChars: item.isRemote ? 12 : 18)
            content.append(child: number); content.append(child: makeAgentTile(paneTile, size: 20)); content.append(child: title)
            if item.isRemote {
                let remote = LabelRef(str: "⌁ Remote"); remote.add(cssClass: "aw-pane-peek-meta")
                content.append(child: remote)
            }
            row.set(child: content); row.setTooltip(text: item.location)
            setAccessibleLabel(row, item.accessibilityLabel)
            row.onClicked { [weak self, popover] _ in
                self?.select(workspaceID); self?.focus(item.id); popover.popdown()
            }
            retainCardPointer(on: WidgetRef(row))
            box.append(child: row)
        }
        workspacePanePeekCards[workspaceID] = box
        workspacePanePeekCardMotionHosts[workspaceID] = cardMotionHosts
        workspacePanePeekCardMotionControllers[workspaceID] = cardMotionControllers
        popover.set(child: box)
    }

    private func setPanePeekPresence(
        _ source: PanePeekPresence, present: Bool, workspaceID: UUID
    ) {
        if present { workspacePanePeekPresence[workspaceID, default: []].insert(source) }
        else { workspacePanePeekPresence[workspaceID, default: []].remove(source) }
        let generation = (workspacePanePeekGeneration[workspaceID] ?? 0) + 1
        workspacePanePeekGeneration[workspaceID] = generation
        let delay = workspacePanePeekPresence[workspaceID]?.isEmpty == false ? 180 : 220
        timeout(add: delay) { [weak self] in
            self?.settlePanePeekPresence(workspaceID: workspaceID, generation: generation) ?? false
        }
    }

    private func settlePanePeekPresence(workspaceID: UUID, generation: Int) -> Bool {
        guard workspacePanePeekGeneration[workspaceID] == generation,
              let popover = workspacePanePeekPopovers[workspaceID]
        else { return false }
        let hasPublishedPresence = workspacePanePeekPresence[workspaceID]?.isEmpty == false
        let pointerIsInsideCard = workspacePanePeekCardMotionControllers[workspaceID]?
            .contains(where: { $0.containsPointer() }) == true
        if hasPublishedPresence || pointerIsInsideCard {
            popover.popup()
            if !hasPublishedPresence && pointerIsInsideCard {
                timeout(add: 80) { [weak self] in
                    self?.settlePanePeekPresence(workspaceID: workspaceID, generation: generation) ?? false
                }
            }
        } else {
            popover.popdown()
        }
        return false
    }

    private func dismissWorkspacePanePeek(_ workspaceID: UUID) {
        workspacePanePeekPresence[workspaceID] = []
        workspacePanePeekGeneration[workspaceID] = (workspacePanePeekGeneration[workspaceID] ?? 0) + 1
        workspacePanePeekPopovers[workspaceID]?.popdown()
    }

    private func removeWorkspacePanePeek(_ workspaceID: UUID) {
        dismissWorkspacePanePeek(workspaceID)
        if let host = workspacePanePeekHosts[workspaceID],
           let controllers = workspacePanePeekMotionControllers[workspaceID], !controllers.isEmpty {
            gtk_widget_remove_controller(host.widget_ptr, controllers[0].event_controller_ptr)
        }
        if let host = workspacePanePeekHosts[workspaceID],
           let controllers = workspacePanePeekFocusControllers[workspaceID], !controllers.isEmpty {
            gtk_widget_remove_controller(host.widget_ptr, controllers[0].event_controller_ptr)
        }
        if let hosts = workspacePanePeekCardMotionHosts[workspaceID],
           let controllers = workspacePanePeekCardMotionControllers[workspaceID] {
            for (host, controller) in zip(hosts, controllers) {
                gtk_widget_remove_controller(host.widget_ptr, controller.event_controller_ptr)
            }
        }
        if let popover = workspacePanePeekPopovers[workspaceID] {
            if let controllers = workspacePanePeekFocusControllers[workspaceID], controllers.count > 1 {
                gtk_widget_remove_controller(popover.widget_ptr, controllers[1].event_controller_ptr)
            }
            popover.unparent()
        }
        workspacePanePeekPopovers.removeValue(forKey: workspaceID)
        workspacePanePeekPresence.removeValue(forKey: workspaceID)
        workspacePanePeekGeneration.removeValue(forKey: workspaceID)
        workspacePanePeekMotionControllers.removeValue(forKey: workspaceID)
        workspacePanePeekFocusControllers.removeValue(forKey: workspaceID)
        workspacePanePeekHosts.removeValue(forKey: workspaceID)
        workspacePanePeekCards.removeValue(forKey: workspaceID)
        workspacePanePeekCardMotionControllers.removeValue(forKey: workspaceID)
        workspacePanePeekCardMotionHosts.removeValue(forKey: workspaceID)
    }

    private func installWorkspacePanePeek(on row: ToggleButtonRef, workspace: WorkspaceSnapshot) {
        guard workspace.layout.paneCount > 1 else { return }
        if workspacePanePeekHosts[workspace.id]?.widget_ptr == row.widget_ptr {
            configureWorkspacePanePeek(workspace.id)
            return
        }
        removeWorkspacePanePeek(workspace.id)
        let popover = PopoverRef(); popover.add(cssClass: "aw-pane-peek-popover")
        popover.set(position: configuredSidebarPosition == .left ? .right : .left)
        popover.set(autohide: false); popover.set(hasArrow: true); popover.set(canFocus: false)
        workspacePanePeekPopovers[workspace.id] = popover
        workspacePanePeekHosts[workspace.id] = row
        configureWorkspacePanePeek(workspace.id)
        gtk_widget_set_parent(popover.widget_ptr, row.widget_ptr)

        let rowMotion = EventControllerMotion()
        rowMotion.onEnter { [weak self] _, _, _ in
            self?.setPanePeekPresence(.rowPointer, present: true, workspaceID: workspace.id)
        }
        rowMotion.onLeave { [weak self] _ in
            self?.setPanePeekPresence(.rowPointer, present: false, workspaceID: workspace.id)
        }
        _ = rowMotion.ref(); gtk_widget_add_controller(row.widget_ptr, rowMotion.event_controller_ptr)

        let rowFocus = EventControllerFocus()
        rowFocus.onEnter { [weak self] _ in
            self?.setPanePeekPresence(.rowFocus, present: true, workspaceID: workspace.id)
        }
        rowFocus.onLeave { [weak self] _ in
            self?.setPanePeekPresence(.rowFocus, present: false, workspaceID: workspace.id)
        }
        _ = rowFocus.ref(); gtk_widget_add_controller(row.widget_ptr, rowFocus.event_controller_ptr)

        workspacePanePeekMotionControllers[workspace.id] = [rowMotion]
        workspacePanePeekFocusControllers[workspace.id] = [rowFocus]
    }

    private func refreshRailGroupRoster(_ groupID: UUID) {
        guard let group = snapshot.groups.first(where: { $0.id == groupID }), let button = railGroupRows[groupID] else { return }
        let safeName = ChromeText.sanitized(group.name, limit: 120)
        button.setTooltip(text: "\(safeName) workspace group")
        setAccessibleLabel(button, "\(safeName) workspace group roster")
        let roster = BoxRef(orientation: .vertical, spacing: 2); roster.add(cssClass: "aw-popover")
        let heading = LabelRef(str: safeName.uppercased())
        heading.add(cssClass: "aw-menu-heading"); heading.xalign = 0; roster.append(child: heading)
        for workspace in group.workspaces where !workspace.isSoftClosed {
            let workspaceName = ChromeText.sanitized(workspace.name, limit: 120)
            let row = ButtonRef(label: workspaceName); row.add(cssClass: "aw-menu-row"); row.setHalign(align: .fill)
            setAccessibleLabel(row, "Jump to \(workspaceName)")
            row.onClicked { [weak self, button] _ in self?.select(workspace.id); button.popdown() }
            roster.append(child: row)
        }
        let popover = PopoverRef(); popover.set(child: roster); button.set(popover: popover)
    }

    private func refreshGroupAttention(
        _ groupID: UUID, projectedPosition: (position: Int, count: Int)? = nil
    ) {
        guard let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        let summary = CollapsedGroupAttention.resolve(group: group)
        let visible = group.isCollapsed && summary.primaryState != nil
        let symbol: String
        switch summary.primaryState {
        case .needsAttention: symbol = "!"
        case .error: symbol = "×"
        case .thinking: symbol = "…"
        case nil: symbol = ""
        }
        groupAttentionLabels[groupID]?.label = visible ? symbol : ""
        groupAttentionLabels[groupID]?.set(visible: visible)
        railGroupAttentionLabels[groupID]?.label = visible ? symbol : ""
        railGroupAttentionLabels[groupID]?.set(visible: visible)
        let count = group.workspaces.filter { !$0.isSoftClosed }.count
        let suffix = visible ? "; \(summary.accessibilityPhrase)" : ""
        let groupIndex = snapshot.groups.firstIndex(where: { $0.id == groupID }) ?? 0
        let position = projectedPosition ?? (groupIndex + 1, snapshot.groups.count)
        let positionCopy = SidebarAccessibilityCopy.position(position.position, of: position.count)
            .map { "; \($0)" } ?? ""
        if let disclosure = groupDisclosures[groupID] {
            let color = SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: groupIndex)
            setAccessibleDescription(disclosure, "\(SidebarAccessibilityCopy.workspaceCount(count)); \(color.rawValue.capitalized) color; \(group.isCollapsed ? "Collapsed" : "Expanded")\(suffix)\(positionCopy)")
        }
        if let rail = railGroupRows[groupID] {
            let color = SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: groupIndex)
            setAccessibleDescription(rail, "\(SidebarAccessibilityCopy.workspaceCount(count)); \(color.rawValue.capitalized) color\(suffix)\(positionCopy). Open roster to choose a workspace")
        }
    }

    private func refreshRegularWorkspaceAccessibility(
        _ workspaceID: UUID, position: (position: Int, count: Int)
    ) {
        guard let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: workspace.focusedPaneID),
              let group = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } }),
              let row = rows[workspaceID]
        else { return }
        let location = FocusedPaneContext.displayPath(
            pane.workingDirectory, homeDirectory: NSHomeDirectory()
        )
        let panes = workspace.layout.paneCount > 1 ? ", \(workspace.layout.paneCount) panes" : ""
        let agent = SidebarAgentTilePresentation.project(workspace: workspace).accessibilityLabel
        let positionCopy = SidebarAccessibilityCopy.position(position.position, of: position.count) ?? ""
        setAccessibleDescription(row, "Workspace in \(ChromeText.sanitized(group.name, limit: 120)); \(location)\(panes); \(agent); \(positionCopy); Actions menu: Shift+F10")
    }

    private func refreshLiftedWorkspaceAccessibility(
        _ item: LiftedSidebarWorkspaceRow, attention: Bool,
        position: (position: Int, count: Int)
    ) {
        guard let workspace = snapshot.workspace(id: item.row.id),
              let row = attention ? attentionRows[item.row.id] : pinnedRows[item.row.id]
        else { return }
        let origin = attention
            ? "Needs input from \(item.originGroupName)" : "Pinned from \(item.originGroupName)"
        let agent = SidebarAgentTilePresentation.project(workspace: workspace).accessibilityLabel
        let positionCopy = SidebarAccessibilityCopy.position(position.position, of: position.count) ?? ""
        setAccessibleDescription(row, "\(origin); \(agent); \(positionCopy); Actions menu: Shift+F10")
    }

    private func refreshRailWorkspaceAccessibility(
        _ workspaceID: UUID, attention: Bool, pinned: Bool,
        position: (position: Int, count: Int)
    ) {
        guard let workspace = snapshot.workspace(id: workspaceID), let row = railRows[workspaceID] else { return }
        let state = attention ? "Needs Input; " : pinned ? "Pinned; " : ""
        let agent = SidebarAgentTilePresentation.project(workspace: workspace).accessibilityLabel
        let positionCopy = SidebarAccessibilityCopy.position(position.position, of: position.count) ?? ""
        setAccessibleDescription(row, "Workspace; \(state)\(agent); \(positionCopy)")
    }

    func makeLiftedRow(_ item: LiftedSidebarWorkspaceRow, attention: Bool) -> OverlayRef? {
        guard let workspace = snapshot.workspace(id: item.row.id) else { return nil }
        let button = makeAccessibleToggleButton(role: GTK_ACCESSIBLE_ROLE_LIST_ITEM)
        button.add(cssClass: "aw-row"); button.setHalign(align: .fill)
        button.add(cssClass: "aw-\((item.originGroupColor ?? .blue).rawValue)")
        let content = BoxRef(orientation: .horizontal, spacing: 10); content.setMarginEnd(margin: 28)
        let agentTile = SidebarAgentTilePresentation.project(workspace: workspace)
        content.append(child: makeAgentTile(agentTile, size: 32))
        let details = BoxRef(orientation: .vertical, spacing: 2); details.setHexpand(expand: true)
        let title = LabelRef(str: item.row.title); title.add(cssClass: "aw-row-title"); title.xalign = 0
        title.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3)); title.setMaxWidthChars(nChars: 13)
        applySearchMatches(item.row.titleMatches, to: title)
        let origin = LabelRef(str: attention ? "Needs input from \(item.originGroupName)" : "Pinned from \(item.originGroupName)")
        origin.add(cssClass: "aw-lifted-origin"); origin.xalign = 0
        origin.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3)); origin.setMaxWidthChars(nChars: 18)
        details.append(child: title); details.append(child: origin); content.append(child: details); button.set(child: content)
        button.setTooltip(text: origin.label ?? "")
        setAccessibleLabel(button, item.row.title)
        setAccessibleDescription(button, "\(origin.label ?? ""); \(agentTile.accessibilityLabel); Actions menu: Shift+F10")
        setAccessibleHasPopup(button)
        button.onClicked { [weak self] _ in self?.select(workspace.id) }
        installWorkspaceContextMenu(on: button, workspaceID: workspace.id, groupID: item.originGroupID, isLifted: true)
        liftedTitles[workspace.id] = title
        if attention { attentionRows[workspace.id] = button } else { pinnedRows[workspace.id] = button }
        let chrome = WorkspaceRowChrome(row: button) { [weak self] in self?.requestSoftCloseWorkspace(workspace.id) }
        liftedRowChrome[workspace.id] = chrome
        if !attention { installPinnedWorkspaceDrag(on: chrome, workspaceID: workspace.id) }
        return chrome.root
    }

    private func installWorkspaceContextMenu(
        on row: ToggleButtonRef, workspaceID: UUID, groupID: UUID, isLifted: Bool = false
    ) {
        let popover = PopoverRef(); let box = BoxRef(orientation: .vertical, spacing: 2); box.add(cssClass: "aw-popover")
        func action(_ label: String, sensitive: Bool = true, run: @escaping () -> Void) -> ButtonRef {
            let button = ButtonRef(label: label); button.add(cssClass: "aw-menu-row"); button.setHalign(align: .fill)
            button.set(sensitive: sensitive)
            button.onClicked { _ in run(); popover.popdown() }; box.append(child: button); return button
        }
        _ = action("New Workspace Here") { [weak self] in self?.createWorkspace(here: workspaceID, fallbackGroupID: groupID) }
        _ = action("Rename Workspace…") { [weak self] in self?.presentWorkspaceNameDialog(workspaceID) }
        if let workspace = snapshot.workspace(id: workspaceID),
           workspace.layout.panes.contains(where: {
               $0.agentState == .needsAttention && !workspace.acknowledgedAttentionPaneIDs.contains($0.id)
           }) {
            _ = action("Acknowledge Workspace") { [weak self] in self?.acknowledgeWorkspace(workspaceID) }
        }
        let muteTitle = snapshot.workspace(id: workspaceID)?.notificationsMuted == true
            ? "Unmute Notifications" : "Mute Notifications"
        _ = action(muteTitle) { [weak self] in self?.toggleWorkspaceNotifications(workspaceID) }
        if let workspace = snapshot.workspace(id: workspaceID), workspace.layout.paneCount > 1 {
            let heading = LabelRef(str: "Panes"); heading.add(cssClass: "aw-menu-heading"); heading.xalign = 0
            box.append(child: heading)
            for item in SidebarPanePeekItem.project(workspace: workspace) {
                _ = action(item.accessibilityLabel) { [weak self] in
                    self?.select(workspaceID); self?.focus(item.id)
                }
            }
        }
        let pin = action(snapshot.pinnedWorkspaceIDs.contains(workspaceID) ? "Unpin" : "Pin") { [weak self] in
            self?.togglePinned(workspaceID)
        }
        if isLifted, let pinnedIndex = snapshot.pinnedWorkspaceIDs.firstIndex(of: workspaceID) {
            if pinnedIndex > 0 {
                _ = action("Move Workspace Up") { [weak self] in self?.movePinned(workspaceID, offset: -1) }
            }
            if pinnedIndex < snapshot.pinnedWorkspaceIDs.count - 1 {
                _ = action("Move Workspace Down") { [weak self] in self?.movePinned(workspaceID, offset: 1) }
            }
        } else if let availability = WorkspaceMoveAvailability.resolve(snapshot: snapshot, workspaceID: workspaceID) {
            _ = action("Move Workspace Up", sensitive: availability.canMoveUp) { [weak self] in
                self?.moveWorkspaceWithinGroup(workspaceID, offset: -1)
            }
            _ = action("Move Workspace Down", sensitive: availability.canMoveDown) { [weak self] in
                self?.moveWorkspaceWithinGroup(workspaceID, offset: 1)
            }
            if let previous = availability.previousGroup {
                _ = action("Move to Previous Group (\(previous.name))") { [weak self] in
                    self?.moveWorkspace(workspaceID, to: previous.id)
                }
            }
            if let next = availability.nextGroup {
                _ = action("Move to Next Group (\(next.name))") { [weak self] in
                    self?.moveWorkspace(workspaceID, to: next.id)
                }
            }
        }
        let otherGroups = snapshot.groups.filter { $0.id != groupID }
        if !otherGroups.isEmpty {
            let heading = LabelRef(str: "Move to Group…"); heading.add(cssClass: "aw-menu-heading"); heading.xalign = 0
            box.append(child: heading)
            for group in otherGroups {
                _ = action(group.name) { [weak self] in self?.moveWorkspace(workspaceID, to: group.id) }
            }
        }
        box.append(child: SeparatorRef(orientation: .horizontal))
        _ = action("Close Workspace") { [weak self] in self?.requestSoftCloseWorkspace(workspaceID) }
        box.append(child: SeparatorRef(orientation: .horizontal))
        _ = action("Clear Workspace") { [weak self] in self?.presentClearWorkspaceConfirmation(workspaceID) }
        if isLifted { liftedPinActions[workspaceID] = pin } else { regularPinActions[workspaceID] = pin }
        popover.set(child: box); gtk_widget_set_parent(popover.widget_ptr, row.widget_ptr)
        let click = GestureClick(); click.set(button: 3)
        click.onPressed { [weak self, popover] _, _, _, _ in
            self?.dismissWorkspacePanePeek(workspaceID); popover.popup()
        }
        _ = click.ref()
        if isLifted { liftedContextControllers[workspaceID] = click } else { workspaceContextControllers[workspaceID] = click }
        gtk_widget_add_controller(row.widget_ptr, click.event_controller_ptr)
        let key = EventControllerKey()
        key.propagationPhase = .capture
        key.onKeyPressed { _, keyval, _, modifiers in
            let opensMenu = keyval == UInt(GDK_KEY_Menu)
                || (keyval == UInt(GDK_KEY_F10) && modifiers.contains(.shiftMask))
            guard opensMenu else { return false }
            popover.popup()
            return true
        }
        _ = key.ref()
        if isLifted { liftedContextKeyControllers[workspaceID] = key }
        else { workspaceContextKeyControllers[workspaceID] = key }
        gtk_widget_add_controller(row.widget_ptr, key.event_controller_ptr)
        if isLifted { liftedContextPopovers[workspaceID] = popover } else { workspaceContextPopovers[workspaceID] = popover }
    }

    private func rebuildWorkspaceContextMenu(_ workspaceID: UUID) {
        guard let row = rows[workspaceID],
              let groupID = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })?.id
        else { return }
        if let controller = workspaceContextControllers.removeValue(forKey: workspaceID) {
            gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
        }
        if let controller = workspaceContextKeyControllers.removeValue(forKey: workspaceID) {
            gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
        }
        workspaceContextPopovers.removeValue(forKey: workspaceID)?.unparent()
        regularPinActions.removeValue(forKey: workspaceID)
        installWorkspaceContextMenu(on: row, workspaceID: workspaceID, groupID: groupID)
    }

    private func acknowledgeWorkspace(_ workspaceID: UUID) {
        attentionAcknowledgementDwell.cancel()
        let shouldRestoreFocus = sidebarOwnsKeyboardFocus(for: workspaceID)
        let wasAttention = snapshot.attentionWorkspaceIDs.contains(workspaceID)
        guard (try? snapshot.acknowledgeWorkspace(workspaceID)) != nil else { return }
        rebuildWorkspaceContextMenu(workspaceID)
        refreshLiftedRows(); updateSidebarVisibility(); persist()
        if shouldRestoreFocus { restoreSidebarFocus(to: workspaceID) }
        announceAttentionReturnIfNeeded(workspaceID, wasAttention: wasAttention)
    }

    private func scheduleAttentionAcknowledgement(workspaceID: UUID, paneID: UUID) {
        attentionAcknowledgementDwell.cancel()
        guard let workspace = snapshot.workspace(id: workspaceID),
              let pane = workspace.layout.pane(id: paneID),
              (snapshot.unansweredTurnPaneIDs.contains(paneID)
                  || (pane.agentState == .needsAttention
                      && !workspace.acknowledgedAttentionPaneIDs.contains(paneID)))
        else { return }
        let request = AttentionAcknowledgementDwellRequest(
            workspaceID: workspaceID,
            paneID: paneID
        )
        attentionAcknowledgementDwell.schedule(
            request: request,
            currentRequest: { [weak self] in
                guard let self,
                      self.snapshot.selectedWorkspaceID == workspaceID,
                      self.runtimes[workspaceID]?.focusedPaneID == paneID
                else { return nil }
                return request
            },
            acknowledge: { [weak self] _ in
                guard let self else { return }
                let wasAttention = self.snapshot.attentionWorkspaceIDs.contains(workspaceID)
                guard (try? self.snapshot.acknowledgePane(
                          paneID, in: workspaceID, passively: true
                      )) == true
                else { return }
                self.rebuildWorkspaceContextMenu(workspaceID)
                self.refreshLiftedRows(); self.updateSidebarVisibility(); self.persist()
                self.announceAttentionReturnIfNeeded(workspaceID, wasAttention: wasAttention)
            }
        )
    }

    private func toggleWorkspaceNotifications(_ workspaceID: UUID) {
        let shouldRestoreFocus = sidebarOwnsKeyboardFocus(for: workspaceID)
        guard (try? snapshot.toggleWorkspaceNotificationsMuted(workspaceID)) != nil else { return }
        rebuildWorkspaceContextMenu(workspaceID)
        refreshLiftedRows(); persist()
        if shouldRestoreFocus { restoreSidebarFocus(to: workspaceID) }
    }

    private func createWorkspace(here workspaceID: UUID, fallbackGroupID: UUID) {
        let workspace = snapshot.workspace(id: workspaceID)
        let directory = workspace.flatMap { $0.layout.pane(id: $0.focusedPaneID)?.workingDirectory }
            ?? FileManager.default.currentDirectoryPath
        let owner = snapshot.groups.first(where: { group in group.workspaces.contains { $0.id == workspaceID } })?.id
        createWorkspace(in: owner ?? fallbackGroupID, directory: directory)
    }

    private func togglePinned(_ workspaceID: UUID) {
        let shouldRestoreFocus = sidebarOwnsKeyboardFocus(for: workspaceID)
        let wasPinned = snapshot.pinnedWorkspaceIDs.contains(workspaceID)
        guard (try? snapshot.togglePinnedWorkspace(workspaceID)) != nil else { return }
        snapshot.reconcileAttentionWorkspaceIDs()
        let isPinned = snapshot.pinnedWorkspaceIDs.contains(workspaceID)
        regularPinActions[workspaceID]?.label = isPinned ? "Unpin" : "Pin"
        liftedPinActions[workspaceID]?.label = isPinned ? "Unpin" : "Pin"
        refreshLiftedRows()
        persist()
        if shouldRestoreFocus { restoreSidebarFocus(to: workspaceID) }
        guard let workspace = snapshot.workspace(id: workspaceID) else { return }
        let title = SidebarWorkspaceTitle.resolve(workspace: workspace)
        if !wasPinned {
            announce("Pinned \(title)")
        } else if snapshot.attentionWorkspaceIDs.contains(workspaceID) {
            announce("Unpinned \(title), moved to Needs Input")
        } else if let group = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } }) {
            announce("Unpinned \(title), returned to \(ChromeText.sanitized(group.name, limit: 120))")
        }
    }

    private func movePinned(_ workspaceID: UUID, offset: Int) {
        guard (try? snapshot.movePinnedWorkspace(workspaceID, offset: offset)) != nil else { return }
        refreshLiftedRows()
        persist()
        restoreSidebarFocus(to: workspaceID)
        announcePinnedReorder(workspaceID)
    }

    private func pinnedDropDestination(
        sourceID: UUID, targetID: UUID, edge: SidebarInsertionEdge
    ) -> (sourceIndex: Int, destinationIndex: Int)? {
        guard let sourceIndex = snapshot.pinnedWorkspaceIDs.firstIndex(of: sourceID),
              let targetIndex = snapshot.pinnedWorkspaceIDs.firstIndex(of: targetID),
              let destination = SidebarInsertionResolver.reorderTarget(
                sourceIndex: sourceIndex, targetIndex: targetIndex,
                edge: edge, count: snapshot.pinnedWorkspaceIDs.count
              ) else { return nil }
        return (sourceIndex, destination)
    }

    private func workspaceDropDestination(
        sourceID: UUID, targetID: UUID, edge: SidebarInsertionEdge
    ) -> (groupID: UUID, destinationIndex: Int)? {
        guard let sourceGroup = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == sourceID } }),
              let destinationGroup = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == targetID } }),
              let sourceIndex = sourceGroup.workspaces.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = destinationGroup.workspaces.firstIndex(where: { $0.id == targetID })
        else { return nil }
        if sourceGroup.id == destinationGroup.id {
            guard let resolved = SidebarInsertionResolver.reorderTarget(
                sourceIndex: sourceIndex, targetIndex: targetIndex,
                edge: edge, count: sourceGroup.workspaces.count
            ) else { return nil }
            return (destinationGroup.id, resolved)
        }
        return (destinationGroup.id,
            SidebarInsertionResolver.preRemovalIndex(targetIndex: targetIndex, edge: edge))
    }

    private func groupDropDestination(
        sourceID: UUID, targetID: UUID, edge: SidebarInsertionEdge
    ) -> (sourceIndex: Int, destinationIndex: Int)? {
        guard let sourceIndex = snapshot.groups.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = snapshot.groups.firstIndex(where: { $0.id == targetID }),
              let destination = SidebarInsertionResolver.reorderTarget(
                sourceIndex: sourceIndex, targetIndex: targetIndex,
                edge: edge, count: snapshot.groups.count
              ) else { return nil }
        return (sourceIndex, destination)
    }

    private func groupHeaderWorkspaceDestination(
        sourceID: UUID, groupID: UUID
    ) -> Int? {
        guard let sourceGroup = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == sourceID } }),
              let sourceIndex = sourceGroup.workspaces.firstIndex(where: { $0.id == sourceID }),
              let destination = snapshot.groups.first(where: { $0.id == groupID }) else { return nil }
        let target = sourceGroup.id == groupID ? max(destination.workspaces.count - 1, 0) : destination.workspaces.count
        return sourceGroup.id == groupID && sourceIndex == target ? nil : target
    }

    private func dropPinnedWorkspace(on targetID: UUID, edge: SidebarInsertionEdge) -> Bool {
        guard !isSidebarFiltering, case let .pinned(sourceID) = activeSidebarDrag,
              let destination = pinnedDropDestination(
                sourceID: sourceID, targetID: targetID, edge: edge
              )
        else { return false }
        movePinned(sourceID, offset: destination.destinationIndex - destination.sourceIndex)
        return true
    }

    private func dropWorkspace(on targetID: UUID, edge: SidebarInsertionEdge) -> Bool {
        guard !isSidebarFiltering, case let .workspace(sourceID) = activeSidebarDrag,
              let destination = workspaceDropDestination(
                sourceID: sourceID, targetID: targetID, edge: edge
              )
        else { return false }
        return moveWorkspace(sourceID, to: destination.groupID, at: destination.destinationIndex)
    }

    private func drop(onGroupHeader groupID: UUID, edge: SidebarInsertionEdge) -> Bool {
        guard !isSidebarFiltering, let activeSidebarDrag else { return false }
        switch activeSidebarDrag {
        case let .workspace(sourceID):
            guard let target = groupHeaderWorkspaceDestination(sourceID: sourceID, groupID: groupID) else { return false }
            return moveWorkspace(sourceID, to: groupID, at: target)
        case let .group(sourceID):
            guard let destination = groupDropDestination(
                sourceID: sourceID, targetID: groupID, edge: edge
            ) else { return false }
            moveGroup(sourceID, offset: destination.destinationIndex - destination.sourceIndex)
            return true
        case .pinned:
            return false
        }
    }

    private func moveWorkspaceWithinGroup(_ workspaceID: UUID, offset: Int) {
        guard let groupID = snapshot.groups.first(where: { group in
            group.workspaces.contains(where: { $0.id == workspaceID })
        })?.id, (try? snapshot.moveWorkspace(workspaceID, offset: offset)) != nil else { return }
        workspaceIDsByGroup[groupID] = snapshot.groups.first(where: { $0.id == groupID })?.workspaces.map(\.id) ?? []
        reorderGroupRows(groupID)
        let affected = workspaceIDsByGroup[groupID] ?? []
        refreshLiftedRows()
        performOnGTKMain { [weak self] in for id in affected { self?.rebuildWorkspaceContextMenu(id) } }
        persist()
        restoreSidebarFocus(to: workspaceID)
        announceWorkspaceReorder(workspaceID)
    }

    private func dismissActiveSheet() {
        let presented = activeSheetWindow
        if let presented, let controller = activeSheetKeyController {
            gtk_widget_remove_controller(presented.widget_ptr, controller.event_controller_ptr)
        }
        activeSheetKeyController = nil
        presented?.close()
        activeSheetWindow = nil
        refreshCommandEnablement()
    }

    private func installActiveSheetDismissal(
        on window: WindowRef,
        destructiveAction: (() -> Void)? = nil
    ) {
        let keys = EventControllerKey()
        keys.onKeyPressed { [weak self] _, keyval, _, modifiers in
            if keyval == UInt(GDK_KEY_Escape) {
                self?.dismissActiveSheet(); return true
            }
            if let destructiveAction,
               (keyval == UInt(GDK_KEY_Return) || keyval == UInt(GDK_KEY_KP_Enter)),
               modifiers.contains(.superMask)
            {
                destructiveAction(); return true
            }
            return false
        }
        _ = keys.ref()
        activeSheetKeyController = keys
        gtk_widget_add_controller(window.widget_ptr, keys.event_controller_ptr)
        window.onCloseRequest { [weak self] _ in
            self?.activeSheetWindow = nil
            self?.activeSheetKeyController = nil
            self?.refreshCommandEnablement()
            return false
        }
    }

    private func presentDestructiveConfirmation(
        title: String,
        bodyText: String,
        keyboardHint: String,
        destructiveTitle: String,
        onConfirm: @escaping () -> Void
    ) {
        if let activeSheetWindow { activeSheetWindow.present(); return }
        guard let parent = window else { return }
        let spokenTitle = DestructiveClosePresentation.spoken(title)
        let window = WindowRef(); activeSheetWindow = window
        window.title = spokenTitle; window.setDefaultSize(width: 480, height: 230)
        window.setTransientFor(parent: parent); window.set(modal: true)
        window.setDestroyWithParent(setting: true); window.set(resizable: false)
        window.add(cssClass: "aw-sheet"); applyThemeClasses(to: window)
        let box = BoxRef(orientation: .vertical, spacing: 14)
        box.add(cssClass: "aw-sheet"); applyThemeClasses(to: box)
        box.setMarginStart(margin: 20); box.setMarginEnd(margin: 20)
        box.setMarginTop(margin: 20); box.setMarginBottom(margin: 20)
        setAccessibleLabel(box, spokenTitle)
        let heading = makeAccessibleLabel(title, role: GTK_ACCESSIBLE_ROLE_HEADING)
        heading.add(cssClass: "aw-menu-title"); heading.xalign = 0
        setAccessibleDescription(heading, spokenTitle)
        let body = LabelRef(str: bodyText); body.add(cssClass: "aw-sheet-body")
        body.xalign = 0; body.set(wrap: true)
        setAccessibleLabel(body, DestructiveClosePresentation.spoken(bodyText))
        let hint = LabelRef(str: keyboardHint); hint.add(cssClass: "aw-sheet-hint")
        hint.xalign = 0; hint.set(wrap: true)
        let actions = BoxRef(orientation: .horizontal, spacing: 8); actions.setHalign(align: .end)
        let cancel = ButtonRef(label: "Cancel")
        let destructive = ButtonRef(label: destructiveTitle)
        cancel.add(cssClass: "aw-sheet-secondary")
        destructive.add(cssClass: "aw-sheet-destructive")
        setAccessibleDescription(destructive, keyboardHint)
        let confirmAndDismiss = { [weak self] in
            guard let self else { return }
            self.dismissActiveSheet()
            onConfirm()
        }
        cancel.onClicked { [weak self] _ in self?.dismissActiveSheet() }
        destructive.onClicked { _ in confirmAndDismiss() }
        window.set(defaultWidget: cancel)
        installActiveSheetDismissal(on: window, destructiveAction: confirmAndDismiss)
        actions.append(child: cancel); actions.append(child: destructive)
        box.append(child: heading); box.append(child: body); box.append(child: hint)
        box.append(child: actions)
        window.set(child: box); refreshCommandEnablement(); window.present(); _ = cancel.grabFocus()
    }

    func presentWorkspaceNameDialog(_ workspaceID: UUID) {
        if let activeSheetWindow { activeSheetWindow.present(); return }
        guard let workspace = snapshot.workspace(id: workspaceID), let parent = window else { return }
        let currentTitle = SidebarWorkspaceTitle.resolve(workspace: workspace)
        let window = WindowRef(); activeSheetWindow = window
        window.title = "Rename Workspace"; window.setDefaultSize(width: 420, height: 190)
        window.setTransientFor(parent: parent); window.set(modal: true)
        window.setDestroyWithParent(setting: true); window.set(resizable: false)
        window.add(cssClass: "aw-sheet"); applyThemeClasses(to: window)
        let box = BoxRef(orientation: .vertical, spacing: 16)
        box.add(cssClass: "aw-sheet"); applyThemeClasses(to: box)
        box.setMarginStart(margin: 20); box.setMarginEnd(margin: 20)
        box.setMarginTop(margin: 20); box.setMarginBottom(margin: 20)
        setAccessibleLabel(box, "Rename Workspace")
        let heading = makeAccessibleLabel(
            WorkspaceRenameDraft.heading(for: currentTitle), role: GTK_ACCESSIBLE_ROLE_HEADING
        )
        heading.add(cssClass: "aw-menu-title"); heading.xalign = 0
        let nameLabel = LabelRef(str: "Name"); nameLabel.add(cssClass: "aw-sheet-label"); nameLabel.xalign = 0
        let entry = EntryRef(); entry.text = currentTitle; entry.setPlaceholder(text: "Workspace name")
        entry.add(cssClass: "aw-sheet-entry")
        setAccessibleLabel(entry, "Workspace name")
        let actions = BoxRef(orientation: .horizontal, spacing: 8); actions.setHalign(align: .end)
        let cancel = ButtonRef(label: "Cancel"); let confirm = ButtonRef(label: "Save")
        cancel.add(cssClass: "aw-sheet-secondary"); confirm.add(cssClass: "aw-sheet-primary")
        func updateSaveState() {
            let enabled = WorkspaceRenameDraft.canSubmit(entry.text ?? "")
            confirm.set(sensitive: enabled)
            setAccessibleDescription(confirm, enabled ? "" : WorkspaceRenameDraft.emptyHint)
        }
        let submit = { [weak self, entry] in
            guard let self else { return }
            let proposed = WorkspaceRenameDraft.sanitized(entry.text ?? "")
            guard !proposed.isEmpty else { return }
            if proposed == WorkspaceRenameDraft.sanitized(currentTitle)
                || self.renameWorkspace(workspaceID, to: proposed) {
                self.dismissActiveSheet()
            }
        }
        cancel.onClicked { [weak self] _ in self?.dismissActiveSheet() }
        confirm.onClicked { _ in submit() }
        entry.onChanged { _ in updateSaveState() }
        entry.onActivate { _ in submit() }
        window.set(defaultWidget: confirm)
        installActiveSheetDismissal(on: window)
        actions.append(child: cancel); actions.append(child: confirm)
        box.append(child: heading); box.append(child: nameLabel); box.append(child: entry); box.append(child: actions)
        updateSaveState(); refreshCommandEnablement()
        window.set(child: box); window.present(); _ = entry.grabFocus()
    }

    @discardableResult private func renameWorkspace(_ workspaceID: UUID, to name: String) -> Bool {
        guard (try? snapshot.renameWorkspace(workspaceID, to: name)) != nil,
              let workspace = snapshot.workspace(id: workspaceID) else {
            showInformation(title: "Rename Workspace", body: "Enter a visible workspace name.")
            return false
        }
        let safeName = ChromeText.sanitized(workspace.name, limit: 120)
        workspaceTitles[workspaceID]?.label = safeName
        railRows[workspaceID]?.setTooltip(text: safeName)
        if let row = rows[workspaceID] { setAccessibleLabel(row, safeName) }
        if let row = railRows[workspaceID] { setAccessibleLabel(row, safeName) }
        refreshLiftedRows()
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        persist()
        return true
    }

    @discardableResult private func moveWorkspace(
        _ workspaceID: UUID, to groupID: UUID, at requestedIndex: Int? = nil
    ) -> Bool {
        guard let sourceID = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })?.id,
              let destinationBefore = snapshot.groups.first(where: { $0.id == groupID })
        else { return false }
        let sourceBefore = snapshot.groups.first(where: { $0.id == sourceID })
        let sourceIndexBefore = sourceBefore?.workspaces.firstIndex(where: { $0.id == workspaceID })
        let targetIndex = requestedIndex ?? destinationBefore.workspaces.count
        let clampedTarget = min(max(targetIndex, 0), sourceID == groupID
            ? max(destinationBefore.workspaces.count - 1, 0) : destinationBefore.workspaces.count)
        guard sourceID != groupID || sourceIndexBefore != clampedTarget,
              (try? snapshot.moveWorkspace(workspaceID, toGroup: groupID, at: targetIndex)) != nil
        else { return false }
        workspaceIDsByGroup[sourceID] = snapshot.groups.first(where: { $0.id == sourceID })?.workspaces.map(\.id) ?? []
        workspaceIDsByGroup[groupID] = snapshot.groups.first(where: { $0.id == groupID })?.workspaces.map(\.id) ?? []
        if let row = rows[workspaceID], let chrome = regularRowChrome[workspaceID], let body = groupBodies[groupID] {
            if sourceID != groupID {
                if let controller = workspaceContextControllers.removeValue(forKey: workspaceID) {
                    gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
                }
                if let controller = workspaceContextKeyControllers.removeValue(forKey: workspaceID) {
                    gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
                }
                workspaceContextPopovers.removeValue(forKey: workspaceID)?.unparent()
                chrome.root.unparent()
                for color in WorkspaceGroupColor.allCases { row.remove(cssClass: "aw-\(color.rawValue)") }
                if let destination = snapshot.groups.first(where: { $0.id == groupID }) {
                    let destinationGroupIndex = snapshot.groups.firstIndex(where: { $0.id == groupID }) ?? 0
                    let color = SidebarTintProjection.resolvedColor(for: destination, unfilteredIndex: destinationGroupIndex)
                    row.add(cssClass: "aw-\(color.rawValue)")
                }
                body.append(child: chrome.root)
                installWorkspaceContextMenu(on: row, workspaceID: workspaceID, groupID: groupID)
            }
        }
        runtimes[workspaceID]?.groupID = groupID
        reorderGroupRows(sourceID)
        if groupID != sourceID { reorderGroupRows(groupID) }
        groupCounts[sourceID]?.label = "\(snapshot.groups.first(where: { $0.id == sourceID })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        groupCounts[groupID]?.label = "\(snapshot.groups.first(where: { $0.id == groupID })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        let affected = (workspaceIDsByGroup[sourceID] ?? []) + (workspaceIDsByGroup[groupID] ?? [])
        refreshLiftedRows(); refreshGroupActionEnablement()
        performOnGTKMain { [weak self] in for id in affected { self?.rebuildWorkspaceContextMenu(id) } }
        persist()
        restoreSidebarFocus(to: workspaceID)
        announceWorkspaceReorder(workspaceID)
        return true
    }

    private func closeRiskInputs(for workspace: WorkspaceSnapshot) -> [PaneCloseRiskInput] {
        workspace.layout.panes.map { pane in
            guard let surface = surfacesByPane[pane.id] else {
                return PaneCloseRiskInput(
                    agentName: pane.agent, agentState: pane.agentState,
                    lastAgentStateChangeAt: lastAgentStateChangeAt[pane.id],
                    terminalPromptObserved: false,
                    terminalAwayFromPrompt: false, liveness: .indeterminate
                )
            }
            return PaneCloseRiskInput(
                agentName: pane.agent, agentState: pane.agentState,
                lastAgentStateChangeAt: lastAgentStateChangeAt[pane.id],
                terminalPromptObserved: surface.hasSeenPrompt,
                terminalAwayFromPrompt: surface.needsConfirmQuit,
                liveness: LinuxForegroundProcessProbe.liveness(for: surface)
            )
        }
    }

    private func workspaceHasCloseRisk(
        _ workspace: WorkspaceSnapshot,
        at now: Foundation.Date = Foundation.Date()
    ) -> Bool {
        WorkspaceCloseRiskPolicy.workspaceHasRisk(closeRiskInputs(for: workspace), at: now)
    }

    private func requestSoftCloseWorkspace(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID), !workspace.isSoftClosed else { return }
        guard workspaceHasCloseRisk(workspace) else { softCloseWorkspace(workspaceID); return }
        let displayedTitle = SidebarWorkspaceTitle.resolve(workspace: workspace)
        presentDestructiveConfirmation(
            title: DestructiveClosePresentation.closeWorkspaceTitle(displayedTitle),
            bodyText: DestructiveClosePresentation.closeWorkspaceBody(displayedTitle),
            keyboardHint: DestructiveClosePresentation.closeWorkspaceHint,
            destructiveTitle: "Close Workspace"
        ) { [weak self] in self?.softCloseWorkspace(workspaceID) }
    }

    private func softCloseWorkspace(_ workspaceID: UUID) {
        let closesLastWorkspace = snapshot.workspaces.filter({ !$0.isSoftClosed }).count == 1
        guard let workspace = snapshot.workspace(id: workspaceID),
              let groupID = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })?.id,
              (try? snapshot.softCloseWorkspace(workspaceID)) != nil else { return }
        removeWorkspaceUI(workspace)
        groupCounts[groupID]?.label = "\(snapshot.groups.first(where: { $0.id == groupID })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        refreshLiftedRows(); refreshGroupActionEnablement(); refreshCommandEnablement()
        if closesLastWorkspace { persist(); window?.close(); return }
        if let selected = snapshot.selectedWorkspaceID { select(selected) } else { persist() }
    }

    private func reopenMostRecentlyClosedWorkspace() {
        pruneExpiredClosedWorkspaces()
        guard let workspaceID = snapshot.recentlyClosedWorkspaces.first?.workspaceID,
              let workspace = snapshot.workspace(id: workspaceID),
              let group = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })
        else { return }
        let rebuiltRuntime = runtimes[workspaceID] == nil
        if runtimes[workspaceID] == nil {
            guard let stack, let body = groupBodies[group.id] else { return }
            guard let layout = buildLayout(workspace.layout, workspace: workspace),
                  let focused = surface(for: workspace.focusedPaneID) else {
                removeWorkspaceUI(workspace); return
            }
            let pathBar = makePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
            page.append(child: layout.0); page.append(child: pathBar.root)
            let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
            appendWorkspaceRow(makeRow(workspace: workspace, groupID: group.id), to: body, groupID: group.id)
            sidebarRailRows?.append(child: makeRailRow(workspace: workspace))
            install(workspace: workspace, groupID: group.id, pageName: pageName,
                page: page, layoutRoot: layout.0, pathBar: pathBar, focusedSurface: focused)
        }
        guard (try? snapshot.reopenMostRecentlyClosedWorkspace()) == workspaceID else {
            if rebuiltRuntime { removeWorkspaceUI(workspace) }
            return
        }
        rows[workspaceID]?.set(visible: true); regularRowChrome[workspaceID]?.root.set(visible: true)
        railRows[workspaceID]?.set(visible: true)
        reorderGroupRows(group.id)
        groupCounts[group.id]?.label = "\(group.workspaces.filter { !$0.isSoftClosed }.count)"
        refreshLiftedRows(); refreshCommandEnablement(); select(workspaceID)
    }

    private func reorderGroupRows(_ groupID: UUID) {
        guard let body = groupBodies[groupID], let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        var previous: OverlayRef?
        for workspace in group.workspaces where !workspace.isSoftClosed {
            guard let root = regularRowChrome[workspace.id]?.root else { continue }
            if let previous { body.reorderChildAfter(child: root, sibling: previous) }
            else { body.reorderChildAfter(child: WidgetRef(root), sibling: nil as WidgetRef?) }
            previous = root
        }
        if let create = groupCreateRows[groupID] {
            if let previous { body.reorderChildAfter(child: WidgetRef(create), sibling: WidgetRef(previous)) }
            else { body.reorderChildAfter(child: WidgetRef(create), sibling: nil as WidgetRef?) }
        }
    }

    private func presentClearWorkspaceConfirmation(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID) else { return }
        let title = SidebarWorkspaceTitle.resolve(workspace: workspace)
        let hasRisk = workspaceHasCloseRisk(workspace)
        presentDestructiveConfirmation(
            title: DestructiveClosePresentation.clearWorkspaceTitle(title),
            bodyText: DestructiveClosePresentation.clearWorkspaceBody(title, hasRisk: hasRisk),
            keyboardHint: DestructiveClosePresentation.clearWorkspaceHint,
            destructiveTitle: "Clear Workspace"
        ) { [weak self] in self?.clearWorkspace(workspaceID) }
    }

    private func clearWorkspace(_ workspaceID: UUID) {
        guard let groupID = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })?.id,
              let removed = try? snapshot.clearWorkspace(workspaceID) else { return }
        removeWorkspaceUI(removed)
        groupCounts[groupID]?.label = "\(snapshot.groups.first(where: { $0.id == groupID })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        refreshLiftedRows(); refreshGroupActionEnablement(); refreshCommandEnablement()
        if let selected = snapshot.selectedWorkspaceID { select(selected) }
        else { refreshEmptyState(); persist() }
    }

    private func removeWorkspaceUI(_ workspace: WorkspaceSnapshot) {
        detachRegularWorkspaceDrag(workspace.id)
        detachPinnedWorkspaceDrag(workspace.id)
        if let row = rows[workspace.id], let controller = workspaceContextControllers.removeValue(forKey: workspace.id) {
            gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
        }
        if let row = rows[workspace.id], let controller = workspaceContextKeyControllers.removeValue(forKey: workspace.id) {
            gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
        }
        workspaceContextPopovers.removeValue(forKey: workspace.id)?.unparent()
        if let liftedRow = attentionRows[workspace.id] ?? pinnedRows[workspace.id] {
            if let controller = liftedContextControllers.removeValue(forKey: workspace.id) {
                gtk_widget_remove_controller(liftedRow.widget_ptr, controller.event_controller_ptr)
            }
            if let controller = liftedContextKeyControllers.removeValue(forKey: workspace.id) {
                gtk_widget_remove_controller(liftedRow.widget_ptr, controller.event_controller_ptr)
            }
        }
        liftedContextPopovers.removeValue(forKey: workspace.id)?.unparent()
        removeWorkspacePanePeek(workspace.id)
        if let child = workspace.id.uuidString.withCString({ stack?.getChildBy(name: $0) }) { stack?.remove(child: child) }
        let paneSurfaces = workspace.layout.paneIDs.compactMap { surfacesByPane[$0] }
        for paneID in workspace.layout.paneIDs {
            surfacesByPane.removeValue(forKey: paneID)
            workspaceByPane.removeValue(forKey: paneID)
            surfaceGenerationByPane.removeValue(forKey: paneID)
            lastAgentStateChangeAt.removeValue(forKey: paneID)
            agentEventWatchers.removeValue(forKey: paneID)?.stop()
        }
        surfaces.removeAll { surface in paneSurfaces.contains { $0 === surface } }
        runtimes.removeValue(forKey: workspace.id); rows.removeValue(forKey: workspace.id)
        regularRowChrome.removeValue(forKey: workspace.id)?.detach()
        liftedRowChrome.removeValue(forKey: workspace.id)?.detach()
        regularAgentTileHosts.removeValue(forKey: workspace.id)
        regularAgentTiles.removeValue(forKey: workspace.id)
        railAgentTileHosts.removeValue(forKey: workspace.id)
        railAgentTiles.removeValue(forKey: workspace.id)
        railJumpNumberLabels.removeValue(forKey: workspace.id)
        metadata.removeValue(forKey: workspace.id); workspaceTitles.removeValue(forKey: workspace.id)
        regularPinActions.removeValue(forKey: workspace.id)
        if let rail = railRows.removeValue(forKey: workspace.id) { sidebarRailRows?.remove(child: rail) }
        for groupID in workspaceIDsByGroup.keys { workspaceIDsByGroup[groupID]?.removeAll { $0 == workspace.id } }
    }

    func refreshLiftedRows() {
        for group in snapshot.groups {
            refreshRailGroupRoster(group.id)
            refreshGroupAttention(group.id)
        }
        for (id, row) in attentionRows {
            if workspacePanePeekHosts[id]?.widget_ptr == row.widget_ptr { removeWorkspacePanePeek(id) }
            if let controller = liftedContextControllers[id] { gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr) }
            if let controller = liftedContextKeyControllers[id] { gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr) }
            liftedContextPopovers[id]?.unparent(); liftedRowChrome.removeValue(forKey: id)?.detach()
        }
        for (id, row) in pinnedRows {
            if workspacePanePeekHosts[id]?.widget_ptr == row.widget_ptr { removeWorkspacePanePeek(id) }
            if let controller = liftedContextControllers[id] { gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr) }
            if let controller = liftedContextKeyControllers[id] { gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr) }
            detachPinnedWorkspaceDrag(id)
            liftedContextPopovers[id]?.unparent(); liftedRowChrome.removeValue(forKey: id)?.detach()
        }
        attentionRows.removeAll(); pinnedRows.removeAll()
        liftedTitles.removeAll()
        liftedRowChrome.removeAll()
        liftedPinActions.removeAll(); liftedContextControllers.removeAll()
        liftedContextKeyControllers.removeAll(); liftedContextPopovers.removeAll()
        let projection = SidebarLiftedProjection.project(snapshot: snapshot, query: sidebarSearchEntry?.text ?? "")
        for item in projection.attention {
            if let row = makeLiftedRow(item, attention: true) { attentionSectionBody?.append(child: row) }
        }
        for item in projection.pinned {
            if let row = makeLiftedRow(item, attention: false) { pinnedSectionBody?.append(child: row) }
        }
        for group in snapshot.groups {
            for workspace in group.workspaces where !workspace.isSoftClosed && workspace.layout.paneCount > 1 {
                guard let host = attentionRows[workspace.id] ?? pinnedRows[workspace.id] ?? rows[workspace.id] else { continue }
                installWorkspacePanePeek(on: host, workspace: workspace)
            }
        }
        filter(sidebarSearchEntry?.text ?? "")
    }

    func makeWorkspaceOptionsButton(includePrimaryAction: Bool) -> MenuButtonRef {
        let menu = MenuButtonRef(); menu.set(alwaysShowArrow: false); menu.set(hasFrame: false)
        menu.set(iconName: includePrimaryAction ? "list-add-symbolic" : "pan-down-symbolic")
        menu.setTooltip(text: includePrimaryAction ? "New Workspace menu" : "New Workspace Options")
        setAccessibleLabel(menu, includePrimaryAction ? "New Workspace menu" : "New Workspace Options")
        setAccessibleDescription(menu, includePrimaryAction
            ? SidebarAccessibilityCopy.newWorkspaceMenuHint
            : SidebarAccessibilityCopy.newWorkspaceOptionsHint)
        workspaceOptionMenus.append((menu, includePrimaryAction))
        configureWorkspaceOptionsButton(menu, includePrimaryAction: includePrimaryAction)
        return menu
    }

    private func configureWorkspaceOptionsButton(_ menu: MenuButtonRef, includePrimaryAction: Bool) {
        let box = BoxRef(orientation: .vertical, spacing: 2); box.add(cssClass: "aw-popover")
        func row(_ label: String, run: @escaping () -> Void) {
            let button = ButtonRef(label: label); button.add(cssClass: "aw-menu-row"); button.setHalign(align: .fill)
            button.onClicked { _ in run(); menu.popdown() }; box.append(child: button)
        }
        if includePrimaryAction { row("New Workspace") { [weak self] in self?.createDefaultWorkspace() } }
        row("New Workspace Group…") { [weak self] in self?.presentGroupNameDialog() }
        if !snapshot.groups.isEmpty {
            let heading = LabelRef(str: "New Workspace in…"); heading.add(cssClass: "aw-menu-heading"); heading.xalign = 0
            box.append(child: heading)
            for group in snapshot.groups {
                row(group.name) { [weak self] in self?.createWorkspace(in: group.id) }
            }
        }
        let popover = PopoverRef(); popover.set(child: box); menu.set(popover: popover)
    }

    private func refreshWorkspaceOptionsMenus() {
        for entry in workspaceOptionMenus {
            configureWorkspaceOptionsButton(entry.menu, includePrimaryAction: entry.includesPrimary)
        }
    }

    func makeGroupSection(
        group: WorkspaceGroupSnapshot,
        projection: SidebarGroupSection
    ) -> (root: BoxRef, body: BoxRef) {
        let root = BoxRef(orientation: .vertical, spacing: 3)
        let header = BoxRef(orientation: .horizontal, spacing: 2)
        let disclosure = makeAccessibleButton(role: GTK_ACCESSIBLE_ROLE_TREE_ITEM)
        disclosure.add(cssClass: "aw-group"); disclosure.setHalign(align: .fill)
        setAccessibleLevel(disclosure, 1)
        disclosure.setHexpand(expand: true); disclosure.setTooltip(text: "Toggle \(group.name) workspace group")
        setAccessibleLabel(disclosure, "\(ChromeText.sanitized(group.name, limit: 120)) workspace group")
        setAccessibleDescription(disclosure, "\(projection.rows.count) workspaces")
        setAccessibleExpanded(disclosure, projection.isExpanded)
        let content = BoxRef(orientation: .horizontal, spacing: 8)
        let chevron = LabelRef(str: projection.isExpanded ? "⌄" : "›")
        let marker = LabelRef(str: "●"); marker.add(cssClass: "aw-marker")
        marker.add(cssClass: "aw-\((projection.color ?? .blue).rawValue)")
        let name = LabelRef(str: projection.name.uppercased()); name.xalign = 0; name.setHexpand(expand: true)
        name.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3)); name.setMaxWidthChars(nChars: 16)
        let count = LabelRef(str: "\(projection.rows.count)"); count.add(cssClass: "aw-count")
        let attention = LabelRef(str: ""); attention.add(cssClass: "aw-group-attention")
        content.append(child: chevron); content.append(child: marker); content.append(child: name)
        content.append(child: attention); content.append(child: count)
        disclosure.set(child: content); disclosure.onClicked { [weak self] _ in self?.toggleGroup(projection.id) }
        let groupChrome = GroupHeaderChrome(
            disclosure: disclosure,
            count: count,
            isEmpty: group.workspaces.isEmpty,
            isCollapsed: group.isCollapsed
        ) { [weak self] in self?.presentCloseGroupConfirmation(group.id) }
        groupHeaderChrome[group.id] = groupChrome
        installGroupDrag(on: groupChrome, groupID: group.id)
        header.append(child: groupChrome.root)

        let options = MenuButtonRef(); options.add(cssClass: "aw-group-options")
        options.set(iconName: "view-more-symbolic"); options.set(alwaysShowArrow: false); options.set(hasFrame: false)
        options.setTooltip(text: "Workspace group actions")
        setAccessibleLabel(options, "Actions for \(group.name) workspace group")
        let menuBox = BoxRef(orientation: .vertical, spacing: 2); menuBox.add(cssClass: "aw-popover")
        @discardableResult func action(_ label: String, sensitive: Bool = true, run: @escaping () -> Void) -> ButtonRef {
            let button = ButtonRef(label: label); button.add(cssClass: "aw-menu-row")
            button.setHalign(align: .fill); button.set(sensitive: sensitive)
            button.onClicked { _ in run(); options.popdown() }
            menuBox.append(child: button)
            return button
        }
        action("New Workspace in Group") { [weak self] in self?.createWorkspace(in: group.id) }
        action("New Workspace Group…") { [weak self] in self?.presentGroupNameDialog() }
        action("Rename Workspace Group…") { [weak self] in self?.presentGroupNameDialog(groupID: group.id) }
        let colorHeading = LabelRef(str: "Color…"); colorHeading.add(cssClass: "aw-menu-heading"); colorHeading.xalign = 0
        menuBox.append(child: colorHeading)
        groupDefaultColorActions[group.id] = action("○  Default\(group.color == nil ? "  ✓" : "")") { [weak self] in self?.setGroupColor(group.id, color: nil) }
        for color in WorkspaceGroupColor.allCases {
            let selected = group.color == color ? "  ✓" : ""
            groupColorActions[group.id, default: [:]][color] = action("●  \(color.rawValue.capitalized)\(selected)") { [weak self] in self?.setGroupColor(group.id, color: color) }
        }
        let index = snapshot.groups.firstIndex(where: { $0.id == group.id })
        groupMoveUpActions[group.id] = action("Move Group Up", sensitive: (index ?? 0) > 0) { [weak self] in self?.moveGroup(group.id, offset: -1) }
        groupMoveDownActions[group.id] = action("Move Group Down", sensitive: index.map { $0 < self.snapshot.groups.count - 1 } ?? false) { [weak self] in self?.moveGroup(group.id, offset: 1) }
        groupCloseActions[group.id] = action("Close Workspace Group") { [weak self] in self?.presentCloseGroupConfirmation(group.id) }
        let popover = PopoverRef(); popover.set(child: menuBox); options.set(popover: popover)
        header.append(child: options); root.append(child: header)

        let body = BoxRef(orientation: .vertical, spacing: 5); root.append(child: body)
        let create = ButtonRef(label: "+  new workspace"); create.add(cssClass: "aw-new-in-group")
        setAccessibleLabel(create, "New workspace in \(ChromeText.sanitized(group.name, limit: 120))")
        create.setHalign(align: .fill); create.onClicked { [weak self] _ in self?.createWorkspace(in: group.id) }
        body.append(child: create)
        groupCreateRows[group.id] = create
        groupDisclosures[group.id] = disclosure
        groupAttentionLabels[group.id] = attention
        registerGroup(projection, root: root, body: body, chevron: chevron, count: count, name: name, marker: marker)
        refreshGroupAttention(group.id)
        refreshGroupActionEnablement()
        return (root, body)
    }

    func appendWorkspaceRow(_ root: OverlayRef, to body: BoxRef, groupID: UUID) {
        body.append(child: root)
        if let create = groupCreateRows[groupID] {
            body.reorderChildAfter(child: WidgetRef(create), sibling: WidgetRef(root))
        }
    }

    func select(_ workspaceID: UUID) {
        guard let runtime = runtimes[workspaceID], let stack else { return }
        let previousSticky = snapshot.attentionStickyWorkspaceID
        let previousAttention = snapshot.attentionWorkspaceIDs
        try? snapshot.selectWorkspace(workspaceID)
        if previousAttention != snapshot.attentionWorkspaceIDs {
            refreshLiftedRows()
        }
        runtime.pageName.withCString { stack.setVisibleChild(name: $0) }
        for (id, row) in rows { row.setActive(isActive: id == workspaceID) }
        for (id, row) in railRows { row.setActive(isActive: id == workspaceID) }
        for (id, row) in attentionRows { row.setActive(isActive: id == workspaceID) }
        for (id, row) in pinnedRows { row.setActive(isActive: id == workspaceID) }
        for (id, row) in rows { setAccessibleSelected(row, id == workspaceID) }
        for (id, row) in railRows { setAccessibleSelected(row, id == workspaceID) }
        for (id, row) in attentionRows { setAccessibleSelected(row, id == workspaceID) }
        for (id, row) in pinnedRows { setAccessibleSelected(row, id == workspaceID) }
        title?.label = snapshot.workspace(id: workspaceID).map(SidebarWorkspaceTitle.resolve) ?? ""
        updateChrome(workspaceID); focus(runtime.focusedPaneID); persist()
        if let previousSticky, previousSticky != snapshot.attentionStickyWorkspaceID {
            announceAttentionReturnIfNeeded(previousSticky, wasAttention: true)
        }
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
        applyThemeClasses(to: rootWidget)
    }

    private func applyThemeClasses<T: Gtk.WidgetProtocol>(to widget: T) {
        for theme in AppTheme.allCases { widget.remove(cssClass: "theme-\(theme.rawValue.lowercased())") }
        widget.remove(cssClass: "high-contrast"); widget.remove(cssClass: "reduced-motion")
        let appearance = GTKChromeAppearance.resolve(preference: preferences.theme)
        widget.add(cssClass: "theme-\(appearance.theme.rawValue.lowercased())")
        if appearance.isHighContrast { widget.add(cssClass: "high-contrast") }
        if appearance.reducesMotion { widget.add(cssClass: "reduced-motion") }
        for density in SidebarDensity.allCases { widget.remove(cssClass: "density-\(density.rawValue)") }
        widget.add(cssClass: "density-\(preferences.sidebarDensity.rawValue)")
        applySidebarDensityGeometry()
    }

    private func applySidebarDensityGeometry() {
        let layout = preferences.sidebarDensity.layout
        groupsContainer?.set(spacing: layout.groupStackSpacing)

        let headerToBodySpacing = layout.sessionStackSpacing + layout.groupHeaderBottomPadding
        for root in groupRoots.values { root.set(spacing: headerToBodySpacing) }
        for body in groupBodies.values { body.set(spacing: layout.sessionStackSpacing) }

        attentionSectionContent?.set(spacing: headerToBodySpacing)
        attentionSectionBody?.set(spacing: layout.sessionStackSpacing)
        pinnedSectionContent?.set(spacing: headerToBodySpacing)
        pinnedSectionBody?.set(spacing: layout.sessionStackSpacing)
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

    func presentStartupRecoveryIfNeeded() {
        guard let presentation = startupRecoveryPresentation,
              activeSheetWindow == nil,
              let parent = window
        else { return }
        let window = WindowRef(); activeSheetWindow = window
        window.title = presentation.title; window.setDefaultSize(width: 520, height: 230)
        window.setTransientFor(parent: parent); window.set(modal: true)
        window.setDestroyWithParent(setting: true); window.set(resizable: false)
        window.add(cssClass: "aw-sheet"); applyThemeClasses(to: window)
        let box = BoxRef(orientation: .vertical, spacing: 14)
        box.add(cssClass: "aw-sheet"); applyThemeClasses(to: box)
        box.setMarginStart(margin: 20); box.setMarginEnd(margin: 20)
        box.setMarginTop(margin: 20); box.setMarginBottom(margin: 20)
        setAccessibleLabel(box, presentation.title)
        let heading = makeAccessibleLabel(presentation.title, role: GTK_ACCESSIBLE_ROLE_HEADING)
        heading.add(cssClass: "aw-menu-title"); heading.xalign = 0
        let message = LabelRef(str: presentation.message); message.add(cssClass: "aw-sheet-body")
        message.xalign = 0; message.set(wrap: true); message.setVexpand(expand: true)
        setAccessibleLabel(message, presentation.message)
        let actions = BoxRef(orientation: .horizontal, spacing: 8); actions.setHalign(align: .end)
        let done = ButtonRef(label: "Done"); done.add(cssClass: "aw-sheet-primary")
        done.onClicked { [weak self] _ in self?.dismissActiveSheet() }
        window.set(defaultWidget: done)
        installActiveSheetDismissal(on: window)
        actions.append(child: done)
        box.append(child: heading); box.append(child: message); box.append(child: actions)
        window.set(child: box); refreshCommandEnablement(); window.present(); _ = done.grabFocus()
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
        let implemented: Set<CommandID> = [.newWorkspace, .newWorkspaceInCurrentDirectory, .newWorkspaceGroup,
            .renameWorkspace, .acknowledgeWorkspace, .togglePinWorkspace,
            .closeWorkspace, .clearWorkspace, .reopenClosedWorkspace,
            .splitRight, .splitDown, .closePane,
            .growActivePane, .shrinkActivePane,
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
            .focusPane1, .focusPane2, .focusPane3,
            .focusPane4, .focusPane5, .focusPane6,
            .jumpWorkspace1, .jumpWorkspace2, .jumpWorkspace3, .jumpWorkspace4,
            .jumpWorkspace5, .jumpWorkspace6, .jumpWorkspace7, .jumpWorkspace8,
            .jumpWorkspace9,
            .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility]
        var commandRows: [(String, ButtonRef)] = []
        for definition in CommandCatalog.definitions where implemented.contains(definition.id) {
            let button = ButtonRef(label: definition.action)
            button.add(cssClass: "aw-menu-row"); button.setHalign(align: .fill)
            if let index = definition.id.workspaceJumpIndex {
                button.set(sensitive: workspaceJumpOrder().indices.contains(index))
            } else if let index = definition.id.paneFocusIndex {
                button.set(sensitive: index <= (snapshot.selectedWorkspace?.layout.paneCount ?? 0))
            } else if [.previousPane, .nextPane].contains(definition.id) {
                button.set(sensitive: snapshot.selectedWorkspace?.layout.paneCount ?? 0 > 1)
            } else if [.growActivePane, .shrinkActivePane].contains(definition.id) {
                button.set(sensitive: snapshot.selectedWorkspace?.layout.paneCount ?? 0 > 1)
            }
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
        persistence.schedule(snapshot)
    }

    @discardableResult
    func flushPersistence() -> Bool {
        let outcome = persistence.flush(snapshot)
        applyPersistenceOutcome(outcome)
        return outcome == .saved
    }

    func prepareForWindowClose() {
        for workspaceID in Array(workspacePanePeekPopovers.keys) {
            removeWorkspacePanePeek(workspaceID)
        }
        for popover in workspaceContextPopovers.values {
            popover.popdown()
            popover.unparent()
        }
        workspaceContextPopovers.removeAll()
        for popover in liftedContextPopovers.values {
            popover.popdown()
            popover.unparent()
        }
        liftedContextPopovers.removeAll()
    }

    private func applyPersistenceOutcome(_ outcome: SessionPersistenceWriteOutcome) {
        let wasPaused = isPersistencePaused
        isPersistencePaused = outcome == .failed
        if isPersistencePaused && !wasPaused {
            announce("Workspace changes are not being saved. Close or simplify workspaces, then retry.")
        }
    }

    private func announce(_ message: String) {
        guard let window else { return }
        announceAccessibilityStatus(from: window, ChromeText.sanitized(message, limit: 240))
    }

    private func announceWorkspaceReorder(_ workspaceID: UUID) {
        guard let group = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } }),
              let index = group.workspaces.firstIndex(where: { $0.id == workspaceID }),
              let workspace = snapshot.workspace(id: workspaceID)
        else { return }
        let count = group.workspaces.count
        announce(SidebarAnnouncement.movedWorkspace(
            title: SidebarWorkspaceTitle.resolve(workspace: workspace),
            position: index + 1, count: count,
            groupName: ChromeText.sanitized(group.name, limit: 120)
        ))
    }

    private func announceGroupReorder(_ groupID: UUID) {
        guard let index = snapshot.groups.firstIndex(where: { $0.id == groupID }) else { return }
        let group = snapshot.groups[index]
        announce(SidebarAnnouncement.movedGroup(
            name: ChromeText.sanitized(group.name, limit: 120),
            position: index + 1, count: snapshot.groups.count
        ))
    }

    private func announcePinnedReorder(_ workspaceID: UUID) {
        guard let index = snapshot.pinnedWorkspaceIDs.firstIndex(of: workspaceID),
              let workspace = snapshot.workspace(id: workspaceID) else { return }
        announce(SidebarAnnouncement.movedPinnedWorkspace(
            title: SidebarWorkspaceTitle.resolve(workspace: workspace),
            position: index + 1, count: snapshot.pinnedWorkspaceIDs.count
        ))
    }

    private func announceAttentionReturnIfNeeded(_ workspaceID: UUID, wasAttention: Bool) {
        guard wasAttention,
              !snapshot.attentionWorkspaceIDs.contains(workspaceID),
              !snapshot.pinnedWorkspaceIDs.contains(workspaceID),
              let workspace = snapshot.workspace(id: workspaceID),
              let group = snapshot.groups.first(where: { $0.workspaces.contains { $0.id == workspaceID } })
        else { return }
        announce("\(SidebarWorkspaceTitle.resolve(workspace: workspace)) left Needs Input, returned to \(ChromeText.sanitized(group.name, limit: 120))")
    }

    func installCommands(on application: Gtk.ApplicationRef) {
        let implemented: Set<CommandID> = [.newWorkspace, .newWorkspaceInCurrentDirectory, .newWorkspaceGroup,
            .renameWorkspace, .acknowledgeWorkspace, .togglePinWorkspace,
            .closeWorkspace, .clearWorkspace, .reopenClosedWorkspace,
            .splitRight, .splitDown, .closePane,
            .growActivePane, .shrinkActivePane,
            .previousWorkspace, .nextWorkspace, .previousPane, .nextPane,
            .focusPane1, .focusPane2, .focusPane3,
            .focusPane4, .focusPane5, .focusPane6,
            .jumpWorkspace1, .jumpWorkspace2, .jumpWorkspace3, .jumpWorkspace4,
            .jumpWorkspace5, .jumpWorkspace6, .jumpWorkspace7, .jumpWorkspace8,
            .jumpWorkspace9,
            .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility]
        let selectedWorkspaceCommands: Set<CommandID> = [
            .renameWorkspace, .closeWorkspace, .clearWorkspace,
            .splitRight, .splitDown, .closePane,
            .growActivePane, .shrinkActivePane,
            .previousPane, .nextPane,
            .focusPane1, .focusPane2, .focusPane3,
            .focusPane4, .focusPane5, .focusPane6,
        ]
        let sheetCommands: Set<CommandID> = [
            .newWorkspaceGroup, .renameWorkspace, .closeWorkspace, .clearWorkspace,
            .splitRight, .splitDown, .closePane,
            .growActivePane, .shrinkActivePane,
            .previousPane, .nextPane,
            .focusPane1, .focusPane2, .focusPane3,
            .focusPane4, .focusPane5, .focusPane6,
        ]
        let menu = GIO.Menu()
        for section in [CommandSection.file, .view, .workspace, .pane] {
            let submenu = GIO.Menu()
            for definition in CommandCatalog.definitions where definition.section == section {
                let action = GIO.SimpleAction(name: definition.id.rawValue, parameterType: nil as VariantTypeRef?)
                action.set(enabled: implemented.contains(definition.id)
                    && (definition.id != .reopenClosedWorkspace || !snapshot.recentlyClosedWorkspaces.isEmpty)
                    && (!selectedWorkspaceCommands.contains(definition.id) || snapshot.selectedWorkspaceID != nil)
                    && (![CommandID.growActivePane, .shrinkActivePane].contains(definition.id)
                        || snapshot.selectedWorkspace?.layout.paneCount ?? 0 > 1)
                    && (![CommandID.previousPane, .nextPane].contains(definition.id)
                        || snapshot.selectedWorkspace?.layout.paneCount ?? 0 > 1)
                    && (definition.id.paneFocusIndex.map {
                        $0 <= (snapshot.selectedWorkspace?.layout.paneCount ?? 0)
                    } ?? true)
                    && (!sheetCommands.contains(definition.id) || activeSheetWindow == nil)
                    && (definition.id.workspaceJumpIndex.map { workspaceJumpOrder().indices.contains($0) } ?? true))
                action.onActivate { [weak self] _, _ in self?.perform(definition.id) }
                application.add(action: action)
                commandActions[definition.id] = action
                submenu.append(label: definition.action, detailedAction: "app.\(definition.id.rawValue)")
                if let chord = definition.defaultChord { install(chord, for: definition.id, on: application) }
                actions.append(action)
            }
            menu.appendSubmenu(label: section.rawValue, submenu: submenu)
        }
        application.set(menubar: menu); self.menu = menu
    }

    private func refreshCommandEnablement() {
        pruneExpiredClosedWorkspaces()
        commandActions[.renameWorkspace]?.set(
            enabled: snapshot.selectedWorkspaceID != nil && activeSheetWindow == nil
        )
        commandActions[.newWorkspaceGroup]?.set(enabled: activeSheetWindow == nil)
        commandActions[.closeWorkspace]?.set(
            enabled: snapshot.selectedWorkspaceID != nil && activeSheetWindow == nil
        )
        commandActions[.clearWorkspace]?.set(
            enabled: snapshot.selectedWorkspaceID != nil && activeSheetWindow == nil
        )
        for command in [CommandID.splitRight, .splitDown, .closePane] {
            commandActions[command]?.set(
                enabled: snapshot.selectedWorkspaceID != nil && activeSheetWindow == nil
            )
        }
        let canResizePane = snapshot.selectedWorkspace?.layout.paneCount ?? 0 > 1
        commandActions[.growActivePane]?.set(
            enabled: canResizePane && activeSheetWindow == nil
        )
        commandActions[.shrinkActivePane]?.set(
            enabled: canResizePane && activeSheetWindow == nil
        )
        commandActions[.previousPane]?.set(enabled: canResizePane && activeSheetWindow == nil)
        commandActions[.nextPane]?.set(enabled: canResizePane && activeSheetWindow == nil)
        commandActions[.reopenClosedWorkspace]?.set(enabled: !snapshot.recentlyClosedWorkspaces.isEmpty)
        for command in CommandID.allCases {
            if let index = command.workspaceJumpIndex {
                commandActions[command]?.set(enabled: workspaceJumpOrder().indices.contains(index))
            }
            if let index = command.paneFocusIndex {
                commandActions[command]?.set(
                    enabled: index <= (snapshot.selectedWorkspace?.layout.paneCount ?? 0)
                        && activeSheetWindow == nil
                )
            }
        }
    }

    private func pruneExpiredClosedWorkspaces() {
        for workspace in snapshot.pruneRecentlyClosedWorkspaces() { removeWorkspaceUI(workspace) }
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
        if command == .newWorkspace { createDefaultWorkspace(); return }
        if command == .newWorkspaceInCurrentDirectory { createWorkspaceInCurrentDirectory(); return }
        if command == .newWorkspaceGroup { presentGroupNameDialog(); return }
        if command == .reopenClosedWorkspace { reopenMostRecentlyClosedWorkspace(); return }
        if command == .focusSidebar { focusSidebar(); return }
        if command == .toggleSidebarWidth { toggleSidebarWidth(); return }
        if command == .toggleSidebarVisibility { toggleSidebarVisibility(); return }
        if let index = command.workspaceJumpIndex { selectWorkspace(atFlatIndex: index); return }
        guard let selected = snapshot.selectedWorkspaceID, runtimes[selected] != nil else { return }
        if let index = command.paneFocusIndex { focusPane(at: index); return }
        switch command {
        case .renameWorkspace: presentWorkspaceNameDialog(selected)
        case .acknowledgeWorkspace: acknowledgeWorkspace(selected)
        case .togglePinWorkspace: togglePinned(selected)
        case .closeWorkspace: requestSoftCloseWorkspace(selected)
        case .clearWorkspace: presentClearWorkspaceConfirmation(selected)
        case .reopenClosedWorkspace: break
        case .focusSidebar, .toggleSidebarWidth, .toggleSidebarVisibility,
             .jumpWorkspace1, .jumpWorkspace2, .jumpWorkspace3, .jumpWorkspace4,
             .jumpWorkspace5, .jumpWorkspace6, .jumpWorkspace7, .jumpWorkspace8,
             .jumpWorkspace9: break
        case .previousWorkspace: selectRelative(-1)
        case .nextWorkspace: selectRelative(1)
        case .previousPane: focusRelative(-1)
        case .nextPane: focusRelative(1)
        case .splitRight: splitFocusedPane(.horizontal)
        case .splitDown: splitFocusedPane(.vertical)
        case .closePane: requestPrimaryClosePane()
        case .growActivePane: resizeFocusedSplit(by: 0.05)
        case .shrinkActivePane: resizeFocusedSplit(by: -0.05)
        default: break
        }
    }

    private func workspaceJumpOrder() -> [UUID] {
        SidebarLiftedProjection.project(snapshot: snapshot, query: "").orderedWorkspaceIDs
    }

    private func selectWorkspace(atFlatIndex index: Int) {
        let order = workspaceJumpOrder()
        guard order.indices.contains(index) else { return }
        select(order[index])
    }

    func createDefaultWorkspace() {
        let groupID = WorkspaceCreationTarget.defaultGroupID(in: snapshot)
            ?? createGroup(named: WorkspaceCreationTarget.defaultGroupName)
        createWorkspace(in: groupID, directory: FileManager.default.currentDirectoryPath)
    }

    func createWorkspaceInCurrentContext() {
        let groupID = WorkspaceCreationTarget.currentContextGroupID(in: snapshot)
            ?? createGroup(named: WorkspaceCreationTarget.defaultGroupName)
        createWorkspace(in: groupID, directory: FileManager.default.currentDirectoryPath)
    }

    func createWorkspaceInCurrentDirectory() {
        let directory = snapshot.selectedWorkspace
            .flatMap { $0.layout.pane(id: $0.focusedPaneID)?.workingDirectory }
            ?? FileManager.default.currentDirectoryPath
        let groupID = WorkspaceCreationTarget.currentContextGroupID(in: snapshot)
            ?? createGroup(named: WorkspaceCreationTarget.defaultGroupName)
        createWorkspace(in: groupID, directory: directory)
    }

    func createWorkspace(in groupID: UUID) {
        let directory = snapshot.selectedWorkspace
            .flatMap { $0.layout.pane(id: $0.focusedPaneID)?.workingDirectory }
            ?? FileManager.default.currentDirectoryPath
        createWorkspace(in: groupID, directory: directory)
    }

    private func createWorkspace(in groupID: UUID?, directory: String) {
        let now = ContinuousClock.now
        if let lastWorkspaceCreateAt, now - lastWorkspaceCreateAt < .milliseconds(400) { return }
        lastWorkspaceCreateAt = now
        guard let stack, let groupID,
              let group = snapshot.groups.first(where: { $0.id == groupID }),
              let body = groupBodies[group.id] else { return }
        let pane = PaneSnapshot(title: "Primary terminal", workingDirectory: directory)
        let workspace = WorkspaceSnapshot(
            name: "Untitled Workspace", isNameUserEdited: false,
            focusedPaneID: pane.id, layout: .pane(pane)
        )
        guard let surface = makeSurface(pane: pane, workspaceID: workspace.id,
            label: "Untitled Workspace Primary terminal", description: "Terminal pane 1 of 1 in the Untitled Workspace workspace") else { return }
        do { try snapshot.addWorkspace(workspace, toGroup: group.id) } catch {
            surfacesByPane.removeValue(forKey: pane.id)
            workspaceByPane.removeValue(forKey: pane.id)
            surfaceGenerationByPane.removeValue(forKey: pane.id)
            lastAgentStateChangeAt.removeValue(forKey: pane.id)
            agentEventWatchers.removeValue(forKey: pane.id)?.stop()
            surfaces.removeAll { $0 === surface }
            return
        }
        let pathBar = makePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
        surface.widget.setVexpand(expand: true); page.append(child: surface.widget); page.append(child: pathBar.root)
        let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
        appendWorkspaceRow(makeRow(workspace: workspace, groupID: group.id), to: body, groupID: group.id)
        body.set(visible: true)
        sidebarRailRows?.append(child: makeRailRow(workspace: workspace))
        groupCounts[group.id]?.label = "\(snapshot.groups.first(where: { $0.id == group.id })?.workspaces.filter { !$0.isSoftClosed }.count ?? 0)"
        refreshGroupActionEnablement()
        install(workspace: workspace, groupID: group.id, pageName: pageName,
            page: page, layoutRoot: surface.widget, pathBar: pathBar, focusedSurface: surface)
        refreshCommandEnablement()
        select(workspace.id)
    }

    func presentGroupNameDialog(groupID: UUID? = nil) {
        if let activeSheetWindow { activeSheetWindow.present(); return }
        let current = groupID.flatMap { id in snapshot.groups.first(where: { $0.id == id })?.name } ?? ""
        guard groupID == nil || !current.isEmpty, let parent = window else { return }
        let isCreating = groupID == nil
        let sheetTitle = isCreating ? "New Workspace Group" : "Rename Workspace Group"
        let window = WindowRef(); activeSheetWindow = window
        window.title = sheetTitle; window.setDefaultSize(width: 420, height: 220)
        window.setTransientFor(parent: parent); window.set(modal: true)
        window.setDestroyWithParent(setting: true); window.set(resizable: false)
        window.add(cssClass: "aw-sheet"); applyThemeClasses(to: window)
        let box = BoxRef(orientation: .vertical, spacing: 16)
        box.add(cssClass: "aw-sheet"); applyThemeClasses(to: box)
        box.setMarginStart(margin: 20); box.setMarginEnd(margin: 20)
        box.setMarginTop(margin: 20); box.setMarginBottom(margin: 20)
        setAccessibleLabel(box, sheetTitle)
        let headingText = isCreating ? sheetTitle : "Rename '\(ChromeText.sanitized(current, limit: 120))'"
        let heading = makeAccessibleLabel(headingText, role: GTK_ACCESSIBLE_ROLE_HEADING)
        heading.add(cssClass: "aw-menu-title"); heading.xalign = 0
        let nameLabel = LabelRef(str: "Name"); nameLabel.add(cssClass: "aw-sheet-label"); nameLabel.xalign = 0
        let entry = EntryRef(); entry.text = WorkspaceGroupNameDraft.clampedInput(current)
        entry.setPlaceholder(text: "Group name"); entry.add(cssClass: "aw-sheet-entry")
        setAccessibleLabel(entry, "Workspace group name")
        let feedback = LabelRef(str: ""); feedback.add(cssClass: "aw-sheet-feedback")
        feedback.xalign = 0; feedback.set(wrap: true); feedback.set(visible: false)
        let actions = BoxRef(orientation: .horizontal, spacing: 8); actions.setHalign(align: .end)
        let cancel = ButtonRef(label: "Cancel"); let confirm = ButtonRef(label: isCreating ? "Create" : "Save")
        cancel.add(cssClass: "aw-sheet-secondary"); confirm.add(cssClass: "aw-sheet-primary")
        let existingNames = snapshot.groups.compactMap { group in
            group.id == groupID ? nil : group.name
        }
        func draft() -> WorkspaceGroupNameDraft {
            WorkspaceGroupNameDraft(typedName: entry.text ?? "", existingGroupNames: existingNames)
        }
        func updateState() {
            let value = draft()
            let message = value.validationMessage ?? value.sanitizationFeedback ?? ""
            feedback.label = message; feedback.set(visible: !message.isEmpty)
            if value.validationMessage == nil { feedback.remove(cssClass: "aw-error") }
            else { feedback.add(cssClass: "aw-error") }
            confirm.set(sensitive: value.canSubmit)
            let fallback = isCreating
                ? WorkspaceGroupNameDraft.createEmptyHint : WorkspaceGroupNameDraft.renameEmptyHint
            setAccessibleDescription(confirm, value.canSubmit ? "" : (value.validationMessage ?? fallback))
        }
        let submit = { [weak self, entry] in
            guard let self else { return }
            let value = WorkspaceGroupNameDraft(
                typedName: entry.text ?? "", existingGroupNames: existingNames
            )
            guard value.canSubmit else { return }
            if !isCreating && value.sanitizedName == WorkspaceGroupNameDraft(
                typedName: current, existingGroupNames: []
            ).sanitizedName {
                self.dismissActiveSheet(); return
            }
            let didSave: Bool
            if let groupID { didSave = self.renameGroup(groupID, to: value.sanitizedName) }
            else { didSave = self.createGroup(named: value.sanitizedName) != nil }
            guard didSave else { return }
            if let message = value.spokenSanitizationFeedback { self.announce(message) }
            self.dismissActiveSheet()
        }
        cancel.onClicked { [weak self] _ in self?.dismissActiveSheet() }
        confirm.onClicked { _ in submit() }
        entry.onChanged { editable in
            let raw = editable.text ?? ""
            let bounded = WorkspaceGroupNameDraft.clampedInput(raw)
            if raw != bounded { entry.text = bounded; return }
            updateState()
        }
        entry.onActivate { _ in submit() }
        window.set(defaultWidget: confirm)
        installActiveSheetDismissal(on: window)
        actions.append(child: cancel); actions.append(child: confirm)
        box.append(child: heading); box.append(child: nameLabel); box.append(child: entry)
        box.append(child: feedback); box.append(child: actions)
        updateState(); refreshCommandEnablement()
        window.set(child: box); window.present(); _ = entry.grabFocus()
    }

    @discardableResult private func createGroup(named name: String) -> UUID? {
        guard let groupsContainer else { return nil }
        do {
            let id = try snapshot.addGroup(named: name)
            guard let group = snapshot.groups.first(where: { $0.id == id }) else { return nil }
            let projection = SidebarGroupSection(id: group.id, name: group.name,
                color: SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: snapshot.groups.count - 1),
                isExpanded: !group.isCollapsed, rows: [])
            let section = makeGroupSection(group: group, projection: projection)
            groupsContainer.append(child: section.root)
            sidebarRailRows?.append(child: makeRailGroupRow(group: group, color: projection.color))
            refreshWorkspaceOptionsMenus()
            refreshEmptyState()
            persist()
            return id
        } catch SessionMutationError.duplicateGroupName {
            let adjusted = ChromeText.sanitized(name, limit: 120).trimmingCharacters(in: .whitespacesAndNewlines)
            showInformation(title: "New Workspace Group", body: "\"\(adjusted)\" already exists.")
            return nil
        } catch SessionMutationError.suspiciousGroupName {
            showInformation(title: "New Workspace Group", body: "Mixing Latin with Cyrillic or Greek letters isn't allowed here — use one alphabet.")
            return nil
        } catch {
            showInformation(title: "New Workspace Group", body: name.isEmpty ? "Enter a group name." : "Enter a visible group name.")
            return nil
        }
    }

    @discardableResult private func renameGroup(_ groupID: UUID, to name: String) -> Bool {
        do {
            try snapshot.renameGroup(groupID, to: name)
            groupNames[groupID]?.label = ChromeText.sanitized(name, limit: 120).uppercased()
            refreshRailGroupRoster(groupID)
            refreshWorkspaceOptionsMenus()
            persist()
            return true
        } catch SessionMutationError.duplicateGroupName {
            let adjusted = ChromeText.sanitized(name, limit: 120).trimmingCharacters(in: .whitespacesAndNewlines)
            showInformation(title: "Rename Workspace Group", body: "\"\(adjusted)\" already exists.")
        } catch SessionMutationError.suspiciousGroupName {
            showInformation(title: "Rename Workspace Group", body: "Mixing Latin with Cyrillic or Greek letters isn't allowed here — use one alphabet.")
        } catch {
            showInformation(title: "Rename Workspace Group", body: name.isEmpty ? "Enter a group name." : "Enter a visible group name.")
        }
        return false
    }

    private func setGroupColor(_ groupID: UUID, color: WorkspaceGroupColor?) {
        guard (try? snapshot.setGroupColor(groupID, color: color)) != nil else { return }
        if let marker = groupMarkers[groupID] {
            for value in WorkspaceGroupColor.allCases { marker.remove(cssClass: "aw-\(value.rawValue)") }
            marker.add(cssClass: "aw-\((color ?? .blue).rawValue)")
        }
        groupDefaultColorActions[groupID]?.label = "○  Default\(color == nil ? "  ✓" : "")"
        for value in WorkspaceGroupColor.allCases {
            groupColorActions[groupID]?[value]?.label = "●  \(value.rawValue.capitalized)\(color == value ? "  ✓" : "")"
        }
        refreshGroupAttention(groupID)
        announce(color.map { "Workspace group color set to \($0.rawValue.capitalized)" }
            ?? "Workspace group color cleared")
        persist()
    }

    private func moveGroup(_ groupID: UUID, offset: Int) {
        guard (try? snapshot.moveGroup(groupID, offset: offset)) != nil, let groupsContainer else { return }
        var previous: BoxRef? = noMatchesRoot
        for group in snapshot.groups {
            guard let root = groupRoots[group.id] else { continue }
            groupsContainer.reorderChildAfter(child: root, sibling: previous)
            previous = root
        }
        for group in snapshot.groups { refreshGroupAttention(group.id) }
        refreshGroupActionEnablement()
        restoreSidebarFocus(toGroup: groupID)
        announceGroupReorder(groupID)
        persist()
    }

    private func refreshGroupActionEnablement() {
        for (index, group) in snapshot.groups.enumerated() {
            groupMoveUpActions[group.id]?.set(sensitive: !isSidebarFiltering && index > 0)
            groupMoveDownActions[group.id]?.set(sensitive: !isSidebarFiltering && index < snapshot.groups.count - 1)
            groupCloseActions[group.id]?.set(sensitive: !isSidebarFiltering)
            groupCreateRows[group.id]?.set(visible: !isSidebarFiltering && !group.isCollapsed)
            groupHeaderChrome[group.id]?.isFiltering = isSidebarFiltering
            groupHeaderChrome[group.id]?.isEmpty = group.workspaces.isEmpty
            groupHeaderChrome[group.id]?.isCollapsed = group.isCollapsed
        }
        refreshSidebarDragAvailability()
    }

    private func refreshGroupTints() {
        for (index, group) in snapshot.groups.enumerated() {
            guard let marker = groupMarkers[group.id] else { continue }
            for value in WorkspaceGroupColor.allCases { marker.remove(cssClass: "aw-\(value.rawValue)") }
            let color = SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: index)
            marker.add(cssClass: "aw-\(color.rawValue)")
        }
    }

    private func presentCloseGroupConfirmation(_ groupID: UUID) {
        guard let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        let now = Foundation.Date()
        let riskyCount = group.workspaces.count { workspaceHasCloseRisk($0, at: now) }
        guard riskyCount > 0 else { closeGroup(groupID); return }
        presentDestructiveConfirmation(
            title: DestructiveClosePresentation.closeGroupTitle(group.name),
            bodyText: DestructiveClosePresentation.closeGroupBody(riskyWorkspaceCount: riskyCount),
            keyboardHint: DestructiveClosePresentation.closeGroupHint,
            destructiveTitle: "Close Group"
        ) { [weak self] in self?.closeGroup(groupID) }
    }

    private func closeGroup(_ groupID: UUID) {
        guard let group = snapshot.groups.first(where: { $0.id == groupID }) else { return }
        let workspaces = group.workspaces
        guard let removed = try? snapshot.closeGroup(groupID) else { return }
        for workspace in workspaces {
            detachRegularWorkspaceDrag(workspace.id)
            detachPinnedWorkspaceDrag(workspace.id)
            let paneSurfaces = workspace.layout.paneIDs.compactMap { surfacesByPane[$0] }
            if let row = rows[workspace.id], let controller = workspaceContextControllers.removeValue(forKey: workspace.id) {
                gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
            }
            if let row = rows[workspace.id], let controller = workspaceContextKeyControllers.removeValue(forKey: workspace.id) {
                gtk_widget_remove_controller(row.widget_ptr, controller.event_controller_ptr)
            }
            workspaceContextPopovers.removeValue(forKey: workspace.id)?.unparent()
            if let liftedRow = attentionRows[workspace.id] ?? pinnedRows[workspace.id] {
                if let controller = liftedContextControllers.removeValue(forKey: workspace.id) {
                    gtk_widget_remove_controller(liftedRow.widget_ptr, controller.event_controller_ptr)
                }
                if let controller = liftedContextKeyControllers.removeValue(forKey: workspace.id) {
                    gtk_widget_remove_controller(liftedRow.widget_ptr, controller.event_controller_ptr)
                }
            }
            liftedContextPopovers.removeValue(forKey: workspace.id)?.unparent()
            removeWorkspacePanePeek(workspace.id)
            if let child = workspace.id.uuidString.withCString({ stack?.getChildBy(name: $0) }) { stack?.remove(child: child) }
            for paneID in workspace.layout.paneIDs {
                surfacesByPane.removeValue(forKey: paneID)
                workspaceByPane.removeValue(forKey: paneID)
                surfaceGenerationByPane.removeValue(forKey: paneID)
                lastAgentStateChangeAt.removeValue(forKey: paneID)
                agentEventWatchers.removeValue(forKey: paneID)?.stop()
            }
            surfaces.removeAll { surface in paneSurfaces.contains { $0 === surface } }
            runtimes.removeValue(forKey: workspace.id)
            rows.removeValue(forKey: workspace.id)
            regularRowChrome.removeValue(forKey: workspace.id)?.detach()
            liftedRowChrome.removeValue(forKey: workspace.id)?.detach()
            regularAgentTileHosts.removeValue(forKey: workspace.id)
            regularAgentTiles.removeValue(forKey: workspace.id)
            railAgentTileHosts.removeValue(forKey: workspace.id)
            railAgentTiles.removeValue(forKey: workspace.id)
            railJumpNumberLabels.removeValue(forKey: workspace.id)
            metadata.removeValue(forKey: workspace.id)
            workspaceTitles.removeValue(forKey: workspace.id)
            regularPinActions.removeValue(forKey: workspace.id)
            if let rail = railRows.removeValue(forKey: workspace.id) { sidebarRailRows?.remove(child: rail) }
        }
        detachGroupDrag(groupID)
        groupHeaderChrome.removeValue(forKey: groupID)?.detach()
        if let root = groupRoots.removeValue(forKey: groupID) { groupsContainer?.remove(child: root) }
        if let railGroup = railGroupRows.removeValue(forKey: groupID) { sidebarRailRows?.remove(child: railGroup) }
        railGroupAttentionLabels.removeValue(forKey: groupID)
        groupBodies.removeValue(forKey: groupID); groupChevrons.removeValue(forKey: groupID)
        groupDisclosures.removeValue(forKey: groupID)
        groupCounts.removeValue(forKey: groupID); groupNames.removeValue(forKey: groupID); groupMarkers.removeValue(forKey: groupID)
        groupAttentionLabels.removeValue(forKey: groupID)
        groupCreateRows.removeValue(forKey: groupID)
        groupMoveUpActions.removeValue(forKey: groupID); groupMoveDownActions.removeValue(forKey: groupID)
        groupCloseActions.removeValue(forKey: groupID)
        groupDefaultColorActions.removeValue(forKey: groupID); groupColorActions.removeValue(forKey: groupID)
        workspaceIDsByGroup.removeValue(forKey: groupID)
        if let selected = snapshot.selectedWorkspaceID { select(selected) }
        else { refreshEmptyState() }
        _ = removed
        refreshGroupTints()
        refreshGroupActionEnablement()
        refreshWorkspaceOptionsMenus()
        refreshLiftedRows()
        refreshEmptyState()
        announce("Closed \(ChromeText.sanitized(group.name, limit: 120)) group")
        persist()
    }

    private func splitFocusedPane(_ axis: SplitAxis) {
        guard activeSheetWindow == nil,
              let workspaceID = snapshot.selectedWorkspaceID,
              let workspace = snapshot.workspace(id: workspaceID),
              let focusedPane = workspace.layout.pane(id: workspace.focusedPaneID),
              focusedPane.ownership == .local
        else { return }

        let pane = PaneSnapshot(
            title: "Primary terminal",
            workingDirectory: focusedPane.workingDirectory,
            ownership: .local
        )
        guard makeSurface(
            pane: pane,
            workspaceID: workspaceID,
            label: "\(workspace.name) \(pane.title)",
            description: "New terminal pane in the \(workspace.name) workspace"
        ) != nil else { return }

        do {
            try snapshot.splitFocusedPane(in: workspaceID, axis: axis, newPane: pane)
        } catch {
            discardPaneRuntime(pane.id)
            return
        }
        guard remountWorkspaceLayout(workspaceID) else {
            discardPaneRuntime(pane.id)
            return
        }
        refreshWorkspaceAgentTile(workspaceID)
        refreshWorkspaceRowPresentation(workspaceID)
        refreshLiftedRows()
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        rebuildWorkspaceContextMenu(workspaceID)
        refreshCommandEnablement()
        persist()
        focus(pane.id)
        announce(axis == .horizontal ? "Split pane right" : "Split pane down")
    }

    private func requestPrimaryClosePane() {
        guard activeSheetWindow == nil,
              let workspaceID = snapshot.selectedWorkspaceID,
              let workspace = snapshot.workspace(id: workspaceID),
              let paneIndex = workspace.layout.paneIDs.firstIndex(of: workspace.focusedPaneID)
        else { return }
        guard workspace.layout.paneCount > 1 else {
            requestSoftCloseWorkspace(workspaceID)
            return
        }

        let risks = closeRiskInputs(for: workspace)
        let isRisk = risks.indices.contains(paneIndex)
            && WorkspaceCloseRiskPolicy.decision(risks[paneIndex]).isRisk
        guard isRisk else {
            closeFocusedPaneNow(workspaceID)
            return
        }
        let displayedTitle = SidebarWorkspaceTitle.resolve(workspace: workspace)
        presentDestructiveConfirmation(
            title: DestructiveClosePresentation.closePaneTitle(displayedTitle),
            bodyText: DestructiveClosePresentation.closePaneBody(displayedTitle),
            keyboardHint: DestructiveClosePresentation.closePaneHint,
            destructiveTitle: "Close Pane"
        ) { [weak self] in self?.closeFocusedPaneNow(workspaceID) }
    }

    private func closeFocusedPaneNow(_ workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID) else { return }
        let closingPaneID = workspace.focusedPaneID
        guard (try? snapshot.closeFocusedPane(in: workspaceID)) == .closePane(closingPaneID),
              remountWorkspaceLayout(workspaceID),
              let updated = snapshot.workspace(id: workspaceID),
              let nextSurface = surfacesByPane[updated.focusedPaneID],
              let runtime = runtimes[workspaceID]
        else { return }

        discardPaneRuntime(closingPaneID)
        runtime.focusedPaneID = updated.focusedPaneID
        runtime.focusedSurface = nextSurface
        refreshWorkspaceAgentTile(workspaceID)
        refreshWorkspaceRowPresentation(workspaceID)
        refreshLiftedRows()
        sidebarFooter?.update(AgentFooterSummary(snapshot: snapshot))
        rebuildWorkspaceContextMenu(workspaceID)
        refreshCommandEnablement()
        persist()
        focus(updated.focusedPaneID)
        announce("Pane closed")
    }

    private func resizeFocusedSplit(by delta: Double) {
        guard activeSheetWindow == nil,
              let workspaceID = snapshot.selectedWorkspaceID,
              (try? snapshot.resizeFocusedSplit(in: workspaceID, by: delta)) == true,
              remountWorkspaceLayout(workspaceID),
              let focusedPaneID = snapshot.workspace(id: workspaceID)?.focusedPaneID
        else { return }
        persist()
        focus(focusedPaneID)
    }

    private func selectRelative(_ offset: Int) {
        let previousSticky = snapshot.attentionStickyWorkspaceID
        let previousAttention = snapshot.attentionWorkspaceIDs
        guard (try? snapshot.selectRelativeWorkspace(offset: offset)) != nil, let id = snapshot.selectedWorkspaceID else { return }
        select(id)
        if previousAttention != snapshot.attentionWorkspaceIDs { refreshLiftedRows() }
        if let previousSticky, previousSticky != snapshot.attentionStickyWorkspaceID {
            announceAttentionReturnIfNeeded(previousSticky, wasAttention: true)
        }
    }

    private func focusRelative(_ offset: Int) {
        guard let workspaceID = snapshot.selectedWorkspaceID,
              (try? snapshot.focusRelativePane(offset: offset, in: workspaceID)) != nil,
              let id = snapshot.workspace(id: workspaceID)?.focusedPaneID else { return }
        focus(id)
        // focus(_:) sees the already-mutated pane identity, so its callback's
        // change detector correctly reports no second mutation. Persist and
        // refresh the pane-owned row/footer projection at this command boundary.
        refreshWorkspaceRowPresentation(workspaceID)
        persist()
        announceFocusedPane(in: workspaceID)
    }

    private func focusPane(at index: Int) {
        guard let workspaceID = snapshot.selectedWorkspaceID,
              (try? snapshot.focusPane(at: index, in: workspaceID)) == true,
              let paneID = snapshot.workspace(id: workspaceID)?.focusedPaneID
        else { return }
        focus(paneID)
        refreshWorkspaceRowPresentation(workspaceID)
        persist()
        announce("Focused pane \(index)")
    }

    private func announceFocusedPane(in workspaceID: UUID) {
        guard let workspace = snapshot.workspace(id: workspaceID),
              let index = workspace.layout.paneIDs.firstIndex(of: workspace.focusedPaneID)
        else { return }
        announce("Focused pane \(index + 1)")
    }
}

nonisolated(unsafe) private var retainedState: ApplicationState?
nonisolated(unsafe) private var retainedPrimaryWindow: ApplicationWindowRef?

private func initialSnapshot() -> SessionSnapshot {
    return SessionSnapshot(selectedWorkspaceID: nil, groups: [])
}

private func buildWindow(for application: Gtk.ApplicationRef) {
    switch PrimaryWindowActivationAction.resolve(hasPrimaryWindow: retainedPrimaryWindow != nil) {
    case .presentPrimaryWindow:
        retainedPrimaryWindow?.present()
        return
    case .buildPrimaryWindow:
        break
    }

    _ = BundledFonts.register()
    let fallback = initialSnapshot()
    let paths: SessionProfilePaths
    do { paths = try SessionProfilePaths(profile: "default") } catch { fatalError("Default profile path is invalid") }
    let store = SessionStore(paths: paths)
    let preferencesStore = AppPreferencesStore(
        url: paths.snapshotURL.deletingLastPathComponent().appendingPathComponent("preferences.json")
    )
    let loadOutcome = try? store.loadRecovering()
    let snapshot: SessionSnapshot
    switch loadOutcome {
    case let .restored(value), let .recoveredPrevious(value): snapshot = value
    case .missing, .resetAfterQuarantine, .none: snapshot = fallback
    }
    guard let state = ApplicationState(
        snapshot: snapshot,
        store: store,
        preferencesStore: preferencesStore,
        startupRecoveryPresentation: loadOutcome.flatMap(SessionRecoveryPresentation.resolve)
    ) else { fatalError("Ghostty runtime initialization failed") }
    retainedState = state; state.installCommands(on: application)

    let window = ApplicationWindowRef(application: application); window.title = "awesoMux"
    retainedPrimaryWindow = window
    window.setDefaultSize(width: 1440, height: 900)
    let root = BoxRef(orientation: .vertical, spacing: 0); root.add(cssClass: "aw-root")
    state.installStyles(on: WidgetRef(root))
    let titlebar = BoxRef(orientation: .horizontal, spacing: 0); titlebar.add(cssClass: "aw-titlebar")
    titlebar.setHexpand(expand: true)
    let brand = LabelRef(str: ">_  awesoMux"); brand.add(cssClass: "aw-brand")
    brand.setHalign(align: .fill); brand.setValign(align: .fill)
    brand.setSizeRequest(width: SidebarChromeProjection.width, height: 38)
    let titleHost = CenterBoxRef(); titleHost.setHexpand(expand: true)
    titleHost.setHalign(align: .fill)
    let title = LabelRef(str: ""); title.add(cssClass: "aw-window-title")
    title.setHexpand(expand: state.configuredSidebarPosition == .right)
    title.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3)); title.setMaxWidthChars(nChars: 64)
    title.setHalign(align: .center); titleHost.setCenterWidget(child: title)
    if state.configuredSidebarPosition == .left {
        titlebar.append(child: brand); titlebar.append(child: titleHost)
    } else {
        titlebar.append(child: titleHost); titlebar.append(child: brand)
    }
    root.append(child: titlebar)

    let main = BoxRef(orientation: .horizontal, spacing: 0); main.setVexpand(expand: true)
    let sidebar = BoxRef(orientation: .vertical, spacing: 0); sidebar.add(cssClass: "aw-sidebar")
    if state.configuredSidebarPosition == .right { sidebar.add(cssClass: "aw-right"); brand.add(cssClass: "aw-right") }
    sidebar.setSizeRequest(width: SidebarWidthPolicy.collapsedWidth, height: -1); sidebar.setHexpand(expand: false)
    let sidebarModes = BoxRef(orientation: .vertical, spacing: 0)
    sidebarModes.setHexpand(expand: true); sidebarModes.setVexpand(expand: true)
    let expandedSidebar = BoxRef(orientation: .vertical, spacing: 0)
    let header = BoxRef(orientation: .horizontal, spacing: 6)
    header.setMarginStart(margin: 10); header.setMarginEnd(margin: 10); header.setMarginTop(margin: 10); header.setMarginBottom(margin: 8)
    let search = SearchEntryRef(); search.add(cssClass: "aw-search"); search.setHexpand(expand: true)
    setAccessibleLabel(search, "Search sessions")
    search.getFirstChild()?.add(cssClass: "aw-search-text")
    search.setPlaceholder(text: "Search sessions"); search.setSizeRequest(width: 108, height: 30)
    search.setWidthChars(nChars: 8); search.setMaxWidthChars(nChars: 8)
    search.onSearchChanged { [weak state] entry in state?.filter(entry.text ?? "") }
    let createSplit = BoxRef(orientation: .horizontal, spacing: 0); createSplit.add(cssClass: "aw-create-split")
    let createPrimary = ButtonRef(); setDecorativeButtonText(createPrimary, "+")
    createPrimary.add(cssClass: "aw-create-primary")
    setAccessibleLabel(createPrimary, "New Workspace")
    setAccessibleDescription(createPrimary, SidebarAccessibilityCopy.newWorkspaceHint)
    createPrimary.setTooltip(text: "New Workspace")
    createPrimary.onClicked { [weak state] _ in state?.createWorkspaceInCurrentContext() }
    let createOptions = state.makeWorkspaceOptionsButton(includePrimaryAction: false)
    createOptions.add(cssClass: "aw-create-options")
    createSplit.append(child: createPrimary); createSplit.append(child: createOptions)
    header.append(child: search); header.append(child: createSplit); expandedSidebar.append(child: header)

    let groups = BoxRef(orientation: .vertical, spacing: 14)
    groups.setMarginStart(margin: 10); groups.setMarginEnd(margin: 10); groups.setMarginTop(margin: 6); groups.setMarginBottom(margin: 8)
    let scroller = ScrolledWindowRef(); scroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
    func liftedSection(title: String, symbol: String, needs: Bool) -> (Revealer, BoxRef, BoxRef) {
        let root = BoxRef(orientation: .vertical, spacing: 5)
        let header = LabelRef(str: "\(symbol)  \(title.uppercased())"); header.add(cssClass: "aw-lifted-header")
        if needs { header.add(cssClass: "aw-lifted-needs") }
        header.xalign = 0; root.append(child: header)
        let body = BoxRef(orientation: .vertical, spacing: 5); root.append(child: body)
        let revealer = Revealer(); revealer.set(child: root)
        revealer.setTransitionType(transition: .slideDown)
        revealer.set(revealChild: false); revealer.set(visible: false)
        setAccessibleHidden(root, true)
        groups.append(child: revealer)
        return (revealer, root, body)
    }
    let attentionSection = liftedSection(title: "Needs Input", symbol: "!", needs: true)
    let pinnedSection = liftedSection(title: "Pinned", symbol: "◆", needs: false)
    state.attachLiftedSections(attention: attentionSection, pinned: pinnedSection)
    let noMatches = BoxRef(orientation: .vertical, spacing: 10); noMatches.add(cssClass: "aw-no-matches")
    let noMatchesTitle = LabelRef(str: "●  NO MATCHES"); noMatchesTitle.add(cssClass: "aw-no-matches-title"); noMatchesTitle.xalign = 0
    let noMatchesDescription = LabelRef(str: ""); noMatchesDescription.add(cssClass: "aw-no-matches-copy")
    noMatchesDescription.xalign = 0; noMatchesDescription.set(wrap: true)
    let clearSearch = ButtonRef(label: "Clear search"); clearSearch.add(cssClass: "aw-clear-search"); clearSearch.setHalign(align: .start)
    setAccessibleLabel(clearSearch, "Clear search")
    clearSearch.onClicked { [weak state] _ in state?.clearSidebarSearch() }
    noMatches.append(child: noMatchesTitle); noMatches.append(child: noMatchesDescription); noMatches.append(child: clearSearch)
    noMatches.set(visible: false); groups.append(child: noMatches)
    state.attachGroupsContainer(groups)
    state.attachSearch(entry: search, noMatches: noMatches, description: noMatchesDescription)
    let searchKeys = EventControllerKey()
    searchKeys.onKeyPressed { [weak state] _, keyval, _, _ in
        state?.handleSidebarSearchKey(keyval) ?? false
    }
    _ = searchKeys.ref()
    state.retainSearchController(searchKeys)
    gtk_widget_add_controller(search.widget_ptr, searchKeys.event_controller_ptr)
    let navigationKeys = EventControllerKey()
    navigationKeys.onKeyPressed { [weak state] _, keyval, _, _ in
        state?.handleSidebarNavigationKey(keyval) ?? false
    }
    _ = navigationKeys.ref()
    state.retainSidebarNavigationController(navigationKeys)
    gtk_widget_add_controller(expandedSidebar.widget_ptr, navigationKeys.event_controller_ptr)
    scroller.setVexpand(expand: true); scroller.set(child: groups); expandedSidebar.append(child: scroller)
    let sidebarFooter = state.makeSidebarFooter()
    expandedSidebar.append(child: sidebarFooter.root)

    let rail = BoxRef(orientation: .vertical, spacing: 6); rail.add(cssClass: "aw-rail")
    rail.setMarginStart(margin: 10); rail.setMarginEnd(margin: 10)
    rail.setMarginTop(margin: 10); rail.setMarginBottom(margin: 0)
    let railSearch = ButtonRef(); railSearch.set(iconName: "system-search-symbolic")
    railSearch.add(cssClass: "aw-rail-control")
    railSearch.setTooltip(text: "Search workspaces and actions")
    setAccessibleLabel(railSearch, "Search")
    setAccessibleDescription(railSearch, SidebarAccessibilityCopy.collapsedSearchHint)
    railSearch.onClicked { [weak state] _ in state?.showCommandPalette() }
    let railAdd = state.makeWorkspaceOptionsButton(includePrimaryAction: true)
    railAdd.add(cssClass: "aw-rail-control")
    rail.append(child: railSearch); rail.append(child: railAdd)
    let railRows = BoxRef(orientation: .vertical, spacing: 5)
    let collapsedEmpty = ButtonRef(); collapsedEmpty.set(iconName: "list-add-symbolic")
    collapsedEmpty.add(cssClass: "aw-collapsed-empty")
    collapsedEmpty.setSizeRequest(width: 40, height: 40)
    collapsedEmpty.setTooltip(text: "New Workspace")
    setAccessibleLabel(collapsedEmpty, "New workspace")
    collapsedEmpty.onClicked { [weak state] _ in state?.createDefaultWorkspace() }
    collapsedEmpty.set(visible: false); railRows.append(child: collapsedEmpty)
    let railScroller = ScrolledWindowRef(); railScroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
    railScroller.setVexpand(expand: true); railScroller.set(child: railRows); rail.append(child: railScroller)
    sidebarFooter.collapsedRoot.add(cssClass: "aw-rail-footer")
    rail.append(child: sidebarFooter.collapsedRoot)
    sidebarModes.append(child: expandedSidebar); sidebarModes.append(child: rail)
    expandedSidebar.set(visible: true); rail.set(visible: false)
    sidebar.append(child: sidebarModes)

    let stack = StackRef(); stack.add(cssClass: "aw-content"); stack.setHexpand(expand: true); stack.setVexpand(expand: true)
    stack.set(hhomogeneous: true); stack.set(vhomogeneous: true)
    let emptyPage = BoxRef(orientation: .vertical, spacing: 16); emptyPage.add(cssClass: "aw-empty-workspace")
    emptyPage.setHalign(align: .center); emptyPage.setValign(align: .center)
    let emptyBrand = LabelRef(str: ">_  AWESOMUX"); emptyBrand.add(cssClass: "aw-empty-brand")
    let emptyHeading = LabelRef(str: "WELCOME TO AWESOMUX"); emptyHeading.add(cssClass: "aw-empty-heading"); emptyHeading.xalign = 0
    let emptyCopy = LabelRef(str: "Create a workspace with Ctrl+Super+N."); emptyCopy.add(cssClass: "aw-empty-copy")
    emptyCopy.xalign = 0; emptyCopy.set(wrap: true); emptyCopy.setMaxWidthChars(nChars: 52)
    setAccessibleDescription(emptyCopy, "Create a workspace with Control-Super-N")
    let emptyActions = BoxRef(orientation: .horizontal, spacing: 10)
    let emptyCreate = ButtonRef(); setDecorativeButtonText(emptyCreate, "+  New Workspace")
    emptyCreate.add(cssClass: "aw-empty-primary")
    emptyCreate.setTooltip(text: "Create a new workspace"); setAccessibleLabel(emptyCreate, "New Workspace")
    emptyCreate.onClicked { [weak state] _ in state?.createDefaultWorkspace() }
    let emptyReopen = ButtonRef(); setDecorativeButtonText(emptyReopen, "↶  Reopen Closed Workspace")
    emptyReopen.add(cssClass: "aw-empty-secondary")
    emptyReopen.setTooltip(text: "Reopen the most recently closed workspace (kept for 24 hours)")
    setAccessibleLabel(emptyReopen, "Reopen Closed Workspace")
    emptyReopen.onClicked { [weak state] _ in state?.reopenLastClosedWorkspace() }
    emptyActions.append(child: emptyCreate); emptyActions.append(child: emptyReopen)
    emptyPage.append(child: emptyBrand); emptyPage.append(child: emptyHeading)
    emptyPage.append(child: emptyCopy); emptyPage.append(child: emptyActions)
    "awesomux-empty-workspace".withCString { _ = stack.addNamed(child: emptyPage, name: $0) }
    state.attach(window: window, stack: stack, title: title, root: root, sidebarFooter: sidebarFooter)
    state.attachEmptyState(page: emptyPage, copy: emptyCopy, reopen: emptyReopen, collapsedAction: collapsedEmpty)

    for projection in SidebarChromeProjection(snapshot: snapshot).groups {
        guard let group = snapshot.groups.first(where: { $0.id == projection.id }) else { continue }
        let section = state.makeGroupSection(group: group, projection: projection)
        groups.append(child: section.root)
        railRows.append(child: state.makeRailGroupRow(group: group, color: projection.color))
        let body = section.body

        for workspace in group.workspaces where !workspace.isSoftClosed {
            guard let layout = state.buildLayout(workspace.layout, workspace: workspace),
                  let focused = state.surface(for: workspace.focusedPaneID) else { fatalError("Ghostty terminal surface initialization failed") }
            let pathBar = state.makePathBar(); let page = BoxRef(orientation: .vertical, spacing: 0)
            page.append(child: layout.0); page.append(child: pathBar.root)
            let pageName = workspace.id.uuidString; _ = pageName.withCString { stack.addNamed(child: page, name: $0) }
            state.appendWorkspaceRow(state.makeRow(workspace: workspace, groupID: group.id), to: body, groupID: group.id)
            railRows.append(child: state.makeRailRow(workspace: workspace))
            state.install(workspace: workspace, groupID: group.id, pageName: pageName,
                page: page, layoutRoot: layout.0, pathBar: pathBar, focusedSurface: focused)
        }
    }

    state.refreshLiftedRows()

    stack.setSizeRequest(width: 480, height: -1)
    let sidebarPaned = PanedRef(orientation: .horizontal)
    sidebarPaned.setWideHandle(wide: false)
    if state.configuredSidebarPosition == .left {
        sidebarPaned.setStart(child: sidebar)
        sidebarPaned.setEnd(child: stack)
    } else {
        sidebarPaned.setStart(child: stack)
        sidebarPaned.setEnd(child: sidebar)
    }
    sidebarPaned.setHexpand(expand: true)
    sidebarPaned.setVexpand(expand: true)
    let sidebarHost = OverlayRef(); sidebarHost.set(child: sidebarPaned)
    sidebarHost.setHexpand(expand: true); sidebarHost.setVexpand(expand: true)
    let edgeTab = ButtonRef(); edgeTab.add(cssClass: "aw-sidebar-edge-attention")
    edgeTab.setTooltip(text: "Show Sidebar — workspace needs input")
    setAccessibleLabel(edgeTab, "Show Sidebar")
    setAccessibleDescription(edgeTab, "A workspace needs input")
    edgeTab.setHalign(align: state.configuredSidebarPosition == .left ? .start : .end)
    edgeTab.setValign(align: .center)
    if state.configuredSidebarPosition == .right { edgeTab.add(cssClass: "aw-right") }
    edgeTab.onClicked { [weak state] _ in state?.showSidebarPersistently() }
    edgeTab.set(visible: false); sidebarHost.addOverlay(widget: edgeTab)
    let edgeMotion = EventControllerMotion()
    edgeMotion.onMotion { [weak state, sidebarHost] _, x, _ in
        state?.sidebarPointerMoved(x: x, width: Double(sidebarHost.getWidth()))
    }
    edgeMotion.onLeave { [weak state] _ in state?.sidebarPointerLeft() }
    _ = edgeMotion.ref()
    state.retainSidebarMotionController(edgeMotion)
    gtk_widget_add_controller(sidebarHost.widget_ptr, edgeMotion.event_controller_ptr)
    state.attachSidebar(
        paned: sidebarPaned,
        brand: brand,
        sidebar: sidebar,
        expanded: expandedSidebar,
        collapsed: rail,
        railRows: railRows,
        edgeTab: edgeTab,
        host: sidebarHost
    )
    let modifierKeys = EventControllerKey()
    modifierKeys.onKeyPressed { [weak state] _, keyval, _, modifiers in
        state?.handleGlobalKeyPressed(keyval, state: modifiers) ?? false
    }
    modifierKeys.onKeyReleased { [weak state] _, keyval, _, modifiers in
        state?.handleGlobalKeyReleased(keyval, state: modifiers)
    }
    gtk_event_controller_set_propagation_phase(
        modifierKeys.event_controller_ptr, GTK_PHASE_CAPTURE
    )
    _ = modifierKeys.ref()
    state.retainGlobalModifierController(modifierKeys)
    gtk_widget_add_controller(window.widget_ptr, modifierKeys.event_controller_ptr)
    window.onCloseRequest { [weak state] _ in
        retainedPrimaryWindow = nil
        state?.prepareForWindowClose()
        return false
    }
    main.append(child: sidebarHost); root.append(child: main)
    window.set(child: root); window.present()
    state.filter("")
    if let selected = snapshot.selectedWorkspaceID { state.select(selected) }
    performOnGTKMain { [weak state] in state?.presentStartupRecoveryIfNeeded() }
}

let applicationID = ProcessInfo.processInfo.environment["AWESOMUX_SINGLE_WINDOW_PROBE"] == "1"
    ? "com.interactivebuffoonery.awesomux.activationprobe"
    : "com.interactivebuffoonery.awesomux"
let status = applicationID.withCString { identifier in
    Application.run(id: identifier, arguments: CommandLine.arguments, activationHandler: buildWindow)
}
_ = retainedState?.flushPersistence()
guard let status else { fatalError("Could not create GTK application") }
exit(Int32(status))
