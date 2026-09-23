import AwesoMuxCore
import CGraphene
import CGtk
import Gdk
import GLib
import Gtk
import Pango
import struct Graphene.RectRef

final class CommandPaletteController: @unchecked Sendable {
    let popover = PopoverRef()
    let root = BoxRef(orientation: .vertical, spacing: 0)

    private let search = SearchEntryRef()
    private let mode = LabelRef(str: "›")
    private let results = BoxRef(orientation: .vertical, spacing: 0)
    private let scroller = ScrolledWindowRef()
    private let resultCount = LabelRef(str: "0 results")
    private let snapshot: SessionSnapshot
    private let definitions: [CommandDefinition]
    private let enabledCommandIDs: Set<CommandID>
    private let onPerform: (CommandPaletteItem) -> Void
    private let onDismiss: () -> Void
    private let keys = EventControllerKey()
    private var projection: CommandPaletteOutput
    private var selectedIndex: Int?
    private var resultButtons: [ButtonRef] = []
    private var didFinish = false
    private var previousFocus: UnsafeMutablePointer<GtkWidget>?
    private var restoreFocusOnClose = false

    deinit {
        if let previousFocus { g_object_unref(previousFocus) }
    }

    init(
        anchor: WidgetRef,
        snapshot: SessionSnapshot,
        definitions: [CommandDefinition],
        enabledCommandIDs: Set<CommandID>,
        onPerform: @escaping (CommandPaletteItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.definitions = definitions
        self.enabledCommandIDs = enabledCommandIDs
        self.onPerform = onPerform
        self.onDismiss = onDismiss
        projection = CommandPaletteProjection.project(
            snapshot: snapshot,
            commands: definitions,
            enabledCommandIDs: enabledCommandIDs,
            rawQuery: ""
        )
        selectedIndex = projection.defaultSelectionIndex

        root.add(cssClass: "aw-palette")
        setAccessibleLabel(root, "Command Palette")
        setAccessibleDescription(
            root, "Type to search workspaces and actions. Press Escape to dismiss."
        )
        root.append(child: makeSearchHeader())
        scroller.setVexpand(expand: true)
        scroller.set(child: results)
        root.append(child: scroller)
        root.append(child: makeFooter())

        search.onSearchChanged { [weak self] entry in
            self?.rebuild(rawQuery: entry.text ?? "")
        }
        keys.propagationPhase = .capture
        keys.onKeyPressed { [weak self] _, keyval, _, _ in
            self?.handleKey(keyval) ?? false
        }
        _ = keys.ref()
        gtk_widget_add_controller(popover.widget_ptr, keys.event_controller_ptr)
        popover.onClosed { [weak self] _ in
            self?.finish()
        }
        rebuild(rawQuery: "")
        popover.add(cssClass: "aw-palette-popover")
        setAccessibleLabel(popover, "Command Palette")
        setAccessibleDescription(
            popover, "Type to search workspaces and actions. Press Escape to dismiss."
        )
        popover.set(autohide: true)
        popover.set(hasArrow: false)
        popover.set(canFocus: true)
        popover.set(position: .bottom)
        popover.set(child: root)
        gtk_widget_set_parent(popover.widget_ptr, anchor.widget_ptr)
    }

    func present() {
        if previousFocus == nil,
           let gtkRoot = gtk_widget_get_root(popover.widget_ptr),
           let focused = gtk_root_get_focus(gtkRoot) {
            _ = g_object_ref(focused)
            previousFocus = focused
        }
        if let parent = popover.getParent() {
            let geometry = CommandPaletteGeometry.fit(
                parentWidth: parent.getWidth(), parentHeight: parent.getHeight()
            )
            root.setSizeRequest(width: geometry.width, height: geometry.height)
            var rectangle = GdkRectangle(
                x: Int32(geometry.anchorX), y: Int32(geometry.anchorY),
                width: 1, height: 1
            )
            withUnsafePointer(to: &rectangle) {
                popover.setPointingTo(rect: Gdk.RectangleRef($0))
            }
        }
        popover.popup()
        timeout(add: 10) { [weak self] in
            _ = self?.search.grabFocus()
            return false
        }
    }

    func close(restoreFocus: Bool = false) {
        restoreFocusOnClose = restoreFocus
        popover.popdown()
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        // Clear the owner's reference now so a rapid reopen creates a new
        // controller. Only this old controller's GTK teardown is deferred.
        onDismiss()
        // A capture-phase key callback may still be traversing this controller.
        // Release its GTK owner after that event dispatch has unwound.
        timeout(add: 0) { [self] in
            gtk_widget_remove_controller(popover.widget_ptr, keys.event_controller_ptr)
            popover.unparent()
            if let previousFocus {
                if restoreFocusOnClose, gtk_widget_get_root(previousFocus) != nil {
                    _ = gtk_widget_grab_focus(previousFocus)
                }
                g_object_unref(previousFocus)
                self.previousFocus = nil
            }
            return false
        }
    }

    private func makeSearchHeader() -> BoxRef {
        let header = BoxRef(orientation: .horizontal, spacing: 10)
        header.add(cssClass: "aw-palette-search-header")
        mode.add(cssClass: "aw-palette-mode")
        setAccessibleHidden(mode, true)
        search.add(cssClass: "aw-palette-search")
        search.setHexpand(expand: true)
        search.setPlaceholder(text: "Search workspaces and actions...")
        setAccessibleLabel(search, "Command palette search")
        setAccessibleDescription(
            search,
            "Type to search. Use Up and Down Arrow to choose a result, Return to open it, or Escape to dismiss."
        )
        let escape = LabelRef(str: "esc")
        escape.add(cssClass: "aw-palette-key")
        setAccessibleLabel(escape, "Escape")
        header.append(child: mode)
        header.append(child: search)
        header.append(child: escape)
        return header
    }

    private func makeFooter() -> BoxRef {
        let footer = BoxRef(orientation: .horizontal, spacing: 14)
        footer.add(cssClass: "aw-palette-footer")
        let hints = LabelRef(str: "↑↓  navigate     ↵  open")
        setAccessibleLabel(hints, "Up and Down arrow keys to navigate. Return key to open")
        resultCount.add(cssClass: "aw-palette-count")
        resultCount.setHexpand(expand: true)
        resultCount.xalign = 1
        setAccessibleHidden(resultCount, true)
        footer.append(child: hints)
        footer.append(child: resultCount)
        return footer
    }

    private func rebuild(rawQuery: String) {
        projection = CommandPaletteProjection.project(
            snapshot: snapshot,
            commands: definitions,
            enabledCommandIDs: enabledCommandIDs,
            rawQuery: rawQuery
        )
        selectedIndex = projection.defaultSelectionIndex
        var child = results.getFirstChild()
        while let current = child {
            child = current.getNextSibling()
            results.remove(child: current)
        }
        resultButtons.removeAll(keepingCapacity: true)
        let flattened = projection.items
        var flatIndex = 0
        for section in projection.sections {
            let heading = makeAccessibleLabel(
                "\(section.title.uppercased())  ·  \(section.items.count)",
                role: GTK_ACCESSIBLE_ROLE_HEADING
            )
            heading.add(cssClass: "aw-palette-section")
            heading.xalign = 0
            results.append(child: heading)
            for item in section.items {
                let index = flatIndex
                flatIndex += 1
                let button = resultButton(item, index: index, count: flattened.count)
                results.append(child: button)
                resultButtons.append(button)
            }
        }
        if flattened.isEmpty { results.append(child: emptyState()) }
        updateMode()
        resultCount.label = "\(flattened.count) results"
        updateSelection(announce: !rawQuery.isEmpty)
        if !rawQuery.isEmpty && flattened.isEmpty {
            announceAccessibilityStatus(from: search, "No results")
        }
    }

    private func resultButton(
        _ item: CommandPaletteItem, index: Int, count: Int
    ) -> ButtonRef {
        let button = ButtonRef()
        button.add(cssClass: "aw-palette-row")
        button.setHalign(align: .fill)
        // Search owns keyboard focus and Return activation. Rows remain pointer
        // actions, but cannot acquire a second focus that disagrees with selection.
        gtk_widget_set_focusable(button.widget_ptr, 0)
        gtk_widget_set_focus_on_click(button.widget_ptr, 0)
        let row = BoxRef(orientation: .horizontal, spacing: 10)
        let glyphText: String
        switch item.target {
        case .workspace: glyphText = "▸"
        case .command: glyphText = "⌘"
        }
        let glyph = LabelRef(str: glyphText)
        glyph.add(cssClass: "aw-palette-glyph")
        setAccessibleHidden(glyph, true)
        let copy = BoxRef(orientation: .vertical, spacing: 2)
        copy.setHexpand(expand: true)
        let title = LabelRef(str: item.title)
        title.add(cssClass: "aw-palette-title")
        title.xalign = 0
        title.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
        copy.append(child: title)
        if let subtitle = item.subtitle {
            let detail = LabelRef(str: subtitle)
            detail.add(cssClass: "aw-palette-subtitle")
            detail.xalign = 0
            detail.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
            copy.append(child: detail)
        }
        row.append(child: glyph)
        row.append(child: copy)
        button.set(child: row)
        setAccessibleHidden(row, true)
        let prefix: String
        switch item.target {
        case .workspace: prefix = "Workspace"
        case .command: prefix = "Action"
        }
        setAccessibleLabel(button, "\(prefix): \(item.title)")
        let detail = [item.subtitle, "Result \(index + 1) of \(count)"]
            .compactMap { $0 }.joined(separator: ". ")
        setAccessibleDescription(button, detail)
        setAccessibleSetPosition(button, position: index + 1, count: count)
        button.onClicked { [weak self] _ in self?.perform(item) }
        return button
    }

    private func emptyState() -> BoxRef {
        let empty = BoxRef(orientation: .vertical, spacing: 10)
        empty.add(cssClass: "aw-palette-empty")
        let message = LabelRef(str: projection.query.isEmpty
            ? "Type to search workspaces and actions" : "No results")
        message.add(cssClass: "aw-palette-empty-title")
        let hint = LabelRef(str: ">  actions only")
        hint.add(cssClass: "aw-palette-subtitle")
        setAccessibleLabel(hint, "Type the greater-than sign to filter to actions only")
        empty.append(child: message)
        empty.append(child: hint)
        return empty
    }

    private func updateMode() {
        mode.label = projection.mode == .actionsOnly ? "actions" : "›"
        if projection.mode == .actionsOnly {
            mode.add(cssClass: "aw-palette-mode-actions")
            setAccessibleHidden(mode, false)
            setAccessibleLabel(mode, "Actions only mode")
        } else {
            mode.remove(cssClass: "aw-palette-mode-actions")
            setAccessibleHidden(mode, true)
        }
    }

    private func updateSelection(announce: Bool = false) {
        for (index, button) in resultButtons.enumerated() {
            let selected = index == selectedIndex
            if selected { button.add(cssClass: "aw-palette-selected") }
            else { button.remove(cssClass: "aw-palette-selected") }
            setAccessibleSelected(button, selected)
        }
        scrollSelectionIntoView()
        if announce, let selectedIndex, projection.items.indices.contains(selectedIndex) {
            let item = projection.items[selectedIndex]
            let kind: String
            switch item.target {
            case .workspace: kind = "Workspace"
            case .command: kind = "Action"
            }
            announceAccessibilityStatus(
                from: search,
                "\(kind): \(item.title). Result \(selectedIndex + 1) of \(projection.items.count)"
            )
        }
    }

    private func scrollSelectionIntoView() {
        guard let selectedIndex, resultButtons.indices.contains(selectedIndex) else { return }
        var storage = graphene_rect_t()
        let bounds: RectRef = withUnsafeMutablePointer(to: &storage) { RectRef($0) }
        guard resultButtons[selectedIndex].computeBounds(target: results, outBounds: bounds)
        else { return }
        guard let adjustment = gtk_scrolled_window_get_vadjustment(scroller.scrolled_window_ptr)
        else { return }
        let current = gtk_adjustment_get_value(adjustment)
        let pageSize = gtk_adjustment_get_page_size(adjustment)
        guard pageSize > 0 else { return }
        let rowTop = Double(bounds.y)
        let rowBottom = rowTop + Double(bounds.height)
        if rowTop < current {
            gtk_adjustment_set_value(adjustment, rowTop)
        } else if rowBottom > current + pageSize {
            gtk_adjustment_set_value(adjustment, rowBottom - pageSize)
        }
    }

    private func handleKey(_ keyval: UInt) -> Bool {
        switch keyval {
        case UInt(GDK_KEY_Escape):
            close(restoreFocus: true)
            return true
        case UInt(GDK_KEY_Tab), UInt(GDK_KEY_ISO_Left_Tab):
            _ = search.grabFocus()
            return true
        case UInt(GDK_KEY_Down), UInt(GDK_KEY_Up):
            let delta = keyval == UInt(GDK_KEY_Down) ? 1 : -1
            selectedIndex = CommandPaletteSelectionPolicy.destination(
                current: selectedIndex, count: projection.items.count, delta: delta
            )
            updateSelection(announce: true)
            return true
        case UInt(GDK_KEY_Return), UInt(GDK_KEY_KP_Enter):
            guard let selectedIndex, projection.items.indices.contains(selectedIndex) else {
                return true
            }
            perform(projection.items[selectedIndex])
            return true
        default:
            return false
        }
    }

    private func perform(_ item: CommandPaletteItem) {
        close()
        onPerform(item)
    }
}
