import AwesoMuxCore
import CGtk
import Foundation
import Gtk
import Pango

private func menuPopover(_ content: BoxRef) -> PopoverRef {
    let popover = PopoverRef()
    content.add(cssClass: "aw-popover")
    content.setMarginStart(margin: 6)
    content.setMarginEnd(margin: 6)
    content.setMarginTop(margin: 6)
    content.setMarginBottom(margin: 6)
    popover.set(child: content)
    return popover
}

private func menuButton(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> ButtonRef {
    let button = ButtonRef()
    button.add(cssClass: "aw-menu-row")
    button.setHalign(align: .fill)
    let content = BoxRef(orientation: .horizontal, spacing: 8)
    if let icon { content.append(child: ImageRef(iconName: icon)) }
    let label = LabelRef(str: title)
    label.xalign = 0
    label.setHexpand(expand: true)
    label.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
    label.setMaxWidthChars(nChars: 42)
    content.append(child: label)
    button.set(child: content)
    setAccessibleLabel(button, title)
    button.onClicked { _ in action() }
    return button
}

final class FocusedPanePathBar: @unchecked Sendable {
    struct Actions {
        let copy: (String) -> Void
        let reveal: (String) -> Void
        let openEditor: (InstalledEditor, String) -> Void
        let insertCommand: (String) -> Void
        let canInsertCommand: () -> Bool
        let openURL: (URL) -> Void
    }

    let root = BoxRef(orientation: .horizontal, spacing: 8)
    private let pathMenu = MenuButtonRef()
    private let pathModifierClick = GestureClick()
    private let project = LabelRef(str: "")
    private let path = LabelRef(str: "")
    private let branchMenu = MenuButtonRef()
    private let branchName = LabelRef(str: "")
    private let branchHint = LabelRef(str: "")
    private let dirty = LabelRef(str: "")
    private let pullRequestMenu = MenuButtonRef()
    private let pullRequestLabel = LabelRef(str: "")
    private let ciMenu = MenuButtonRef()
    private let ciLabel = LabelRef(str: "")
    private let remote = LabelRef(str: "Remote")
    private let actions: Actions
    private var context: FocusedPaneContext?
    private var openTargetPath: String?

    init(actions: Actions) {
        self.actions = actions
        root.add(cssClass: "aw-pathbar")
        root.setMarginStart(margin: 12)
        root.setMarginEnd(margin: 12)

        pathMenu.add(cssClass: "aw-path-menu")
        pathMenu.set(hasFrame: false)
        pathMenu.set(alwaysShowArrow: false)
        pathMenu.set(canShrink: true)
        pathMenu.valign = .center
        let pathContent = BoxRef(orientation: .horizontal, spacing: 6)
        let folder = ImageRef(iconName: "folder-symbolic")
        folder.set(pixelSize: 11)
        folder.add(cssClass: "aw-path-project")
        pathContent.append(child: folder)
        project.add(cssClass: "aw-path-project")
        project.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
        project.setMaxWidthChars(nChars: 28)
        pathContent.append(child: project)
        let hierarchy = LabelRef(str: "›")
        hierarchy.add(cssClass: "aw-path-hierarchy")
        pathContent.append(child: hierarchy)
        path.add(cssClass: "aw-path-location")
        path.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        path.setMaxWidthChars(nChars: 48)
        pathContent.append(child: path)
        let divider = SeparatorRef(orientation: .vertical)
        divider.add(cssClass: "aw-path-divider")
        divider.setSizeRequest(width: 1, height: 12)
        pathContent.append(child: divider)
        let chevron = LabelRef(str: "⌃")
        chevron.add(cssClass: "aw-path-chevron")
        pathContent.append(child: chevron)
        pathMenu.set(child: pathContent)
        pathModifierClick.set(button: 1)
        pathModifierClick.propagationPhase = .capture
        pathModifierClick.onPressed { [weak self] gesture, _, _, _ in
            let action = FooterOpenTargetAction.resolve(
                controlHeld: gesture.getCurrentEventState().contains(.controlMask)
            )
            guard action == .revealInFiles, let self, let openTargetPath else { return }
            _ = gesture.set(state: .claimed)
            pathMenu.popdown()
            actions.reveal(openTargetPath)
        }
        gtk_widget_add_controller(pathMenu.widget_ptr, pathModifierClick.event_controller_ptr)
        root.append(child: pathMenu)

        let spacer = BoxRef(orientation: .horizontal, spacing: 0)
        spacer.setHexpand(expand: true)
        root.append(child: spacer)

        configureBranchChip()
        dirty.add(cssClass: "aw-chip-dirty")
        dirty.valign = .center
        dirty.set(visible: false)
        root.append(child: dirty)
        configurePullRequestChip()
        configureChip(ciMenu, label: ciLabel, css: "aw-chip-ci")
        remote.add(cssClass: "aw-chip-remote")
        remote.valign = .center
        remote.set(visible: false)
        root.append(child: remote)
    }

    private func configureBranchChip() {
        let content = BoxRef(orientation: .horizontal, spacing: 6)
        let icon = LabelRef(str: "⎇")
        icon.add(cssClass: "aw-chip-icon")
        content.append(child: icon)
        branchName.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        branchName.setMaxWidthChars(nChars: 30)
        content.append(child: branchName)
        branchHint.add(cssClass: "aw-chip-hint")
        content.append(child: branchHint)
        configureChip(branchMenu, child: content, css: "aw-chip-branch")
    }

    private func configurePullRequestChip() {
        let content = BoxRef(orientation: .horizontal, spacing: 6)
        let icon = LabelRef(str: "↟")
        icon.add(cssClass: "aw-chip-icon")
        content.append(child: icon)
        pullRequestLabel.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        pullRequestLabel.setMaxWidthChars(nChars: 24)
        content.append(child: pullRequestLabel)
        configureChip(pullRequestMenu, child: content, css: "aw-chip-pr")
    }

    private func configureChip(_ button: MenuButtonRef, label: LabelRef, css: String) {
        configureChip(button, child: label, css: css)
    }

    private func configureChip(_ button: MenuButtonRef, child: some WidgetProtocol, css: String) {
        button.add(cssClass: "aw-chip")
        button.add(cssClass: css)
        button.set(hasFrame: false)
        button.set(alwaysShowArrow: false)
        button.set(canShrink: true)
        button.valign = .center
        button.set(child: child)
        button.set(visible: false)
        root.append(child: button)
    }

    func updatePreview(_ value: FocusedPaneContext, isRemote: Bool) {
        context = value
        openTargetPath = isRemote ? nil : value.copyPath
        project.label = value.project
        path.label = value.path
        pathMenu.setTooltip(text: isRemote ? "Workspace options are unavailable for remote panes." : "Open workspace options. Control-click to show in Files.")
        setAccessibleLabel(pathMenu, "\(value.project), \(value.path)")
        setAccessibleDescription(pathMenu, isRemote ? "Workspace options are unavailable for remote panes" : "Opens workspace options. Control-click to show in Files")
        remote.set(visible: isRemote)
        branchMenu.set(visible: false)
        dirty.set(visible: false)
        pullRequestMenu.set(visible: false)
        ciMenu.set(visible: false)
        guard !isRemote else {
            pathMenu.set(sensitive: false)
            return
        }
        pathMenu.set(sensitive: true)
        pathMenu.set(popover: pathPopover(path: value.copyPath, editors: []))
    }

    func updateDetails(_ details: TerminalFooterDetails) {
        guard context?.identity == details.context.identity else { return }
        let presentation = details.pathPresentation
        openTargetPath = details.repoRoot ?? details.context.copyPath
        project.label = presentation.project
        path.label = presentation.path
        pathMenu.set(popover: pathPopover(path: details.repoRoot ?? details.context.copyPath, editors: details.editors))
        if let branch = details.branch {
            let arrows = [details.git?.ahead ?? 0 > 0 ? "↑\(capped(details.git?.ahead ?? 0))" : nil,
                          details.git?.behind ?? 0 > 0 ? "↓\(capped(details.git?.behind ?? 0))" : nil]
                .compactMap { $0 }.joined(separator: " ")
            branchName.label = branch
            branchHint.label = arrows
            branchHint.set(visible: !arrows.isEmpty)
            branchMenu.setTooltip(text: "Branch \(branch). Open branch options.")
            setAccessibleLabel(branchMenu, "Branch \(branch)")
            setAccessibleDescription(branchMenu, "Open branch options")
            branchMenu.set(popover: branchPopover(current: branch, branches: details.branches))
            branchMenu.set(visible: true)
        } else {
            branchMenu.set(visible: false)
        }
        if let count = details.git?.dirtyCount, count > 0 {
            dirty.label = "+\(capped(count))"
            dirty.setTooltip(text: "\(count) changed working-copy entries")
            setAccessibleLabel(dirty, "\(count) changed working-copy entries")
            dirty.set(visible: true)
        } else {
            dirty.set(visible: false)
        }
        if let pr = details.pullRequest {
            pullRequestLabel.label = pr.chipLabel
            pullRequestMenu.remove(cssClass: "aw-chip-pr-open")
            pullRequestMenu.remove(cssClass: "aw-chip-pr-draft")
            pullRequestMenu.remove(cssClass: "aw-chip-pr-review")
            pullRequestMenu.add(cssClass: pr.state == .draft ? "aw-chip-pr-draft" : pr.state == .inReview ? "aw-chip-pr-review" : "aw-chip-pr-open")
            pullRequestMenu.setTooltip(text: "Pull request #\(pr.number), \(pr.stateDescription)")
            setAccessibleLabel(pullRequestMenu, "Pull request #\(pr.number)")
            setAccessibleDescription(pullRequestMenu, pr.stateDescription.capitalized)
            pullRequestMenu.set(popover: pullRequestPopover(pr))
            pullRequestMenu.set(visible: true)
        } else {
            pullRequestMenu.set(visible: false)
        }
        if let ci = details.ci {
            ciLabel.label = ci.state == .failing ? "CI ✕" : "CI …"
            ciMenu.remove(cssClass: "aw-chip-ci-failing")
            if ci.state == .failing { ciMenu.add(cssClass: "aw-chip-ci-failing") }
            ciMenu.setTooltip(text: [ci.workflowName, ci.state == .failing ? "failing" : "running"].compactMap { $0 }.joined(separator: ": "))
            setAccessibleLabel(ciMenu, ci.state == .failing ? "CI failing" : "CI running")
            setAccessibleDescription(ciMenu, ci.workflowName ?? "Continuous integration")
            ciMenu.set(popover: ciPopover(ci))
            ciMenu.set(visible: true)
        } else {
            ciMenu.set(visible: false)
        }
    }

    private func pathPopover(path: String, editors: [InstalledEditor]) -> PopoverRef {
        let box = BoxRef(orientation: .vertical, spacing: 2)
        let heading = LabelRef(str: "OPEN WITH")
        heading.add(cssClass: "aw-menu-heading")
        heading.xalign = 0
        box.append(child: heading)
        if editors.isEmpty {
            let unavailable = LabelRef(str: "No supported editors found")
            unavailable.add(cssClass: "aw-menu-disabled")
            unavailable.xalign = 0
            box.append(child: unavailable)
        } else {
            for editor in editors {
                box.append(child: menuButton(editor.name, icon: "document-open-symbolic") { [weak self] in
                    self?.actions.openEditor(editor, path); self?.pathMenu.popdown()
                })
            }
        }
        box.append(child: menuButton("Show in Files", icon: "folder-open-symbolic") { [weak self] in
            self?.actions.reveal(path); self?.pathMenu.popdown()
        })
        box.append(child: menuButton("Copy Path", icon: "edit-copy-symbolic") { [weak self] in
            self?.actions.copy(path); self?.pathMenu.popdown()
        })
        return menuPopover(box)
    }

    private func branchPopover(current: String, branches: [String]) -> PopoverRef {
        let box = BoxRef(orientation: .vertical, spacing: 2)
        let currentRow = BoxRef(orientation: .horizontal, spacing: 8)
        currentRow.add(cssClass: "aw-menu-row")
        currentRow.append(child: ImageRef(iconName: "emblem-ok-symbolic"))
        let currentLabel = LabelRef(str: current)
        currentLabel.xalign = 0
        currentLabel.setHexpand(expand: true)
        currentLabel.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
        currentRow.append(child: currentLabel)
        let currentHint = LabelRef(str: FocusedPaneFooterWording.currentBranch)
        currentHint.add(cssClass: "aw-menu-heading")
        currentRow.append(child: currentHint)
        setAccessibleLabel(currentRow, "\(current), current branch")
        box.append(child: currentRow)
        let otherBranches = branches.filter { $0 != current }
        for branch in otherBranches.prefix(12) {
            let canInsert = actions.canInsertCommand()
            let button = menuButton(branch) { [weak self] in
                guard let self else { return }
                if actions.canInsertCommand() {
                    actions.insertCommand("git checkout \(TerminalFooterResolver.shellQuoted(branch))")
                } else {
                    actions.copy(branch)
                }
                branchMenu.popdown()
            }
            button.setTooltip(text: canInsert
                ? "Insert `git checkout \(branch)` at the prompt"
                : "Copy branch name")
            setAccessibleDescription(button, canInsert
                ? "Inserts the checkout command at the prompt"
                : "Copies the branch name")
            box.append(child: button)
        }
        if otherBranches.count > 12 {
            let more = LabelRef(str: "+ \(otherBranches.count - 12) more branches")
            more.add(cssClass: "aw-menu-disabled")
            more.xalign = 0
            box.append(child: more)
        }
        box.append(child: menuButton("Copy Branch", icon: "edit-copy-symbolic") { [weak self] in
            self?.actions.copy(current); self?.branchMenu.popdown()
        })
        return menuPopover(box)
    }

    private func pullRequestPopover(_ pr: PullRequestStatus) -> PopoverRef {
        let box = BoxRef(orientation: .vertical, spacing: 2)
        box.append(child: menuButton(FocusedPaneFooterWording.openInBrowser, icon: "web-browser-symbolic") { [weak self] in self?.actions.openURL(pr.url); self?.pullRequestMenu.popdown() })
        box.append(child: menuButton(FocusedPaneFooterWording.copyURL, icon: "edit-copy-symbolic") { [weak self] in self?.actions.copy(pr.url.absoluteString); self?.pullRequestMenu.popdown() })
        if actions.canInsertCommand() {
            box.append(child: menuButton(FocusedPaneFooterWording.insertCheckoutCommand) { [weak self] in
                guard let self else { return }
                if actions.canInsertCommand() {
                    actions.insertCommand("gh pr checkout \(pr.number)")
                } else {
                    actions.copy(pr.url.absoluteString)
                }
                pullRequestMenu.popdown()
            })
        }
        return menuPopover(box)
    }

    private func ciPopover(_ ci: CIStatus) -> PopoverRef {
        let box = BoxRef(orientation: .vertical, spacing: 2)
        box.append(child: menuButton(FocusedPaneFooterWording.openInBrowser, icon: "web-browser-symbolic") { [weak self] in self?.actions.openURL(ci.url); self?.ciMenu.popdown() })
        box.append(child: menuButton(FocusedPaneFooterWording.copyURL, icon: "edit-copy-symbolic") { [weak self] in self?.actions.copy(ci.url.absoluteString); self?.ciMenu.popdown() })
        if let slug = ci.repoSlug, actions.canInsertCommand() {
            let command = ci.state == .running
                ? "gh run watch \(ci.runDatabaseID) --repo \(TerminalFooterResolver.shellQuoted(slug))"
                : "gh run view \(ci.runDatabaseID) --repo \(TerminalFooterResolver.shellQuoted(slug)) --log-failed"
            box.append(child: menuButton(ci.state == .running
                ? FocusedPaneFooterWording.insertWatchCommand
                : FocusedPaneFooterWording.insertFailureLogCommand) { [weak self] in
                guard let self else { return }
                if actions.canInsertCommand() {
                    actions.insertCommand(command)
                } else {
                    actions.copy(ci.url.absoluteString)
                }
                ciMenu.popdown()
            })
        }
        return menuPopover(box)
    }

    private func capped(_ value: Int) -> String { value > 999 ? "999+" : String(value) }
}

final class SidebarStatusFooter {
    struct Actions {
        let selectPane: (UUID, UUID) -> Void
        let updatePreferences: (AppPreferences) -> Void
        let reportBug: () -> Void
        let suggestFeature: () -> Void
    }

    let root = BoxRef(orientation: .vertical, spacing: 0)
    let collapsedRoot = BoxRef(orientation: .vertical, spacing: 8)
    private let activityPanel = BoxRef(orientation: .vertical, spacing: 4)
    private let activityRows = BoxRef(orientation: .vertical, spacing: 2)
    private let thinking = ButtonRef()
    private let thinkingLabel = LabelRef(str: "")
    private let output = ButtonRef()
    private let outputLabel = LabelRef(str: "")
    private let attention = ButtonRef()
    private let attentionLabel = LabelRef(str: "")
    private let total = ButtonRef()
    private let totalLabel = LabelRef(str: "0 agents  ⌃")
    private let quickSettings = MenuButtonRef()
    private let collapsedThinking = ButtonRef()
    private let collapsedThinkingLabel = LabelRef(str: "")
    private let collapsedOutput = ButtonRef()
    private let collapsedOutputLabel = LabelRef(str: "")
    private let collapsedAttention = ButtonRef()
    private let collapsedAttentionLabel = LabelRef(str: "")
    private let actions: Actions
    private var preferences: AppPreferences
    private var panelState = AgentActivityPanelState()
    private var latestSummary = AgentFooterSummary(snapshot: SessionSnapshot())
    private var collapsedSelectionPaneIDs: [AgentState: UUID] = [:]

    init(preferences: AppPreferences, actions: Actions) {
        self.preferences = preferences
        self.actions = actions
        activityPanel.add(cssClass: "aw-agent-panel")
        activityPanel.setMarginStart(margin: 8)
        activityPanel.setMarginEnd(margin: 8)
        activityPanel.setMarginTop(margin: 6)
        activityPanel.setMarginBottom(margin: 6)
        let panelHeader = BoxRef(orientation: .horizontal, spacing: 4)
        let heading = LabelRef(str: "AGENTS")
        heading.add(cssClass: "aw-menu-heading")
        heading.xalign = 0
        heading.setHexpand(expand: true)
        let close = ButtonRef()
        setDecorativeButtonText(close, "×")
        close.add(cssClass: "aw-icon-button")
        close.setTooltip(text: "Hide agent activity")
        setAccessibleLabel(close, "Hide agent activity")
        close.onClicked { [weak self] _ in self?.setExpanded(false) }
        panelHeader.append(child: heading)
        panelHeader.append(child: close)
        activityPanel.append(child: panelHeader)
        let scroller = ScrolledWindowRef()
        scroller.setPolicy(hscrollbarPolicy: .never, vscrollbarPolicy: .automatic)
        scroller.maxContentHeight = 240
        scroller.propagateNaturalHeight = true
        scroller.set(child: activityRows)
        activityPanel.append(child: scroller)
        activityPanel.set(visible: false)
        root.append(child: activityPanel)

        let bar = BoxRef(orientation: .horizontal, spacing: 4)
        bar.add(cssClass: "aw-sidebar-footer")
        bar.setMarginStart(margin: 10)
        bar.setMarginEnd(margin: 10)
        quickSettings.add(cssClass: "aw-icon-menu")
        quickSettings.set(hasFrame: false)
        quickSettings.set(alwaysShowArrow: false)
        quickSettings.set(iconName: "emblem-system-symbolic")
        quickSettings.setTooltip(text: "Quick Settings")
        setAccessibleLabel(quickSettings, "Quick Settings")
        quickSettings.set(popover: quickSettingsPopover())
        bar.append(child: quickSettings)

        let help = MenuButtonRef()
        help.add(cssClass: "aw-icon-menu")
        help.set(hasFrame: false)
        help.set(alwaysShowArrow: false)
        help.set(iconName: "help-about-symbolic")
        help.setTooltip(text: "Help & Feedback")
        setAccessibleLabel(help, "Help and feedback")
        setAccessibleDescription(help, "Opens menu")
        let helpBox = BoxRef(orientation: .vertical, spacing: 2)
        helpBox.append(child: menuButton("Report a bug…") { [actions] in actions.reportBug() })
        helpBox.append(child: menuButton("Suggest a feature…") { [actions] in actions.suggestFeature() })
        help.set(popover: menuPopover(helpBox))
        bar.append(child: help)

        for (button, label, css, state) in [
            (thinking, thinkingLabel, "aw-agent-thinking", AgentState.thinking),
            (output, outputLabel, "aw-agent-output", AgentState.output),
            (attention, attentionLabel, "aw-agent-attention", AgentState.needsAttention),
        ] {
            button.add(cssClass: "aw-agent-state")
            button.add(cssClass: css)
            button.set(child: label)
            button.set(visible: false)
            button.onClicked { [weak self] _ in self?.showActivity(state: state) }
            bar.append(child: button)
        }
        let spacer = BoxRef(orientation: .horizontal, spacing: 0)
        spacer.setHexpand(expand: true)
        bar.append(child: spacer)
        total.add(cssClass: "aw-agent-total")
        total.set(child: totalLabel)
        total.setTooltip(text: "Show agent activity")
        setAccessibleLabel(total, "Show agent activity")
        total.onClicked { [weak self] _ in
            guard let self else { return }
            setExpanded(!panelState.isExpanded)
        }
        bar.append(child: total)
        root.append(child: bar)

        collapsedRoot.add(cssClass: "aw-sidebar-footer")
        collapsedRoot.setMarginStart(margin: 4)
        collapsedRoot.setMarginEnd(margin: 4)
        collapsedRoot.setMarginTop(margin: 10)
        collapsedRoot.setMarginBottom(margin: 10)
        collapsedRoot.setHalign(align: .fill)
        let collapsedSettings = MenuButtonRef()
        collapsedSettings.add(cssClass: "aw-icon-menu")
        collapsedSettings.set(hasFrame: false)
        collapsedSettings.set(alwaysShowArrow: false)
        collapsedSettings.set(iconName: "emblem-system-symbolic")
        collapsedSettings.setTooltip(text: "Quick Settings")
        setAccessibleLabel(collapsedSettings, "Quick Settings")
        collapsedSettings.set(popover: quickSettingsPopover())
        collapsedSettings.setHalign(align: .center)
        collapsedRoot.append(child: collapsedSettings)

        let collapsedHelp = MenuButtonRef()
        collapsedHelp.add(cssClass: "aw-icon-menu")
        collapsedHelp.set(hasFrame: false)
        collapsedHelp.set(alwaysShowArrow: false)
        collapsedHelp.set(iconName: "help-about-symbolic")
        collapsedHelp.setTooltip(text: "Help & Feedback")
        setAccessibleLabel(collapsedHelp, "Help and feedback")
        setAccessibleDescription(collapsedHelp, "Opens menu")
        let collapsedHelpBox = BoxRef(orientation: .vertical, spacing: 2)
        collapsedHelpBox.append(child: menuButton("Report a bug…") { [actions] in actions.reportBug() })
        collapsedHelpBox.append(child: menuButton("Suggest a feature…") { [actions] in actions.suggestFeature() })
        collapsedHelp.set(popover: menuPopover(collapsedHelpBox))
        collapsedHelp.setHalign(align: .center)
        collapsedRoot.append(child: collapsedHelp)

        for (button, label, css, state) in [
            (collapsedThinking, collapsedThinkingLabel, "aw-agent-thinking", AgentState.thinking),
            (collapsedOutput, collapsedOutputLabel, "aw-agent-output", AgentState.output),
            (collapsedAttention, collapsedAttentionLabel, "aw-agent-attention", AgentState.needsAttention),
        ] {
            button.add(cssClass: "aw-agent-state")
            button.add(cssClass: "aw-collapsed-agent-state")
            button.add(cssClass: css)
            button.set(child: label)
            button.setHalign(align: .center)
            button.setSizeRequest(width: 32, height: 32)
            button.set(visible: false)
            button.onClicked { [weak self] _ in self?.selectNextCollapsedAgent(matching: state) }
            collapsedRoot.append(child: button)
        }
    }

    func update(_ summary: AgentFooterSummary) {
        latestSummary = summary
        stateButton(thinking, label: thinkingLabel, count: summary.thinkingCount, symbol: "●", state: .thinking)
        stateButton(output, label: outputLabel, count: summary.outputCount, symbol: "●", state: .output)
        stateButton(attention, label: attentionLabel, count: summary.needsAttentionCount, symbol: "●", state: .needsAttention)
        totalLabel.label = "\(summary.totalCount) \(summary.totalCount == 1 ? "agent" : "agents")  \(panelState.isExpanded ? "⌄" : "⌃")"
        collapsedStateButton(collapsedThinking, label: collapsedThinkingLabel,
            count: summary.thinkingCount, symbol: "●", state: .thinking)
        collapsedStateButton(collapsedOutput, label: collapsedOutputLabel,
            count: summary.outputCount, symbol: "●", state: .output)
        collapsedStateButton(collapsedAttention, label: collapsedAttentionLabel,
            count: summary.needsAttentionCount, symbol: "●", state: .needsAttention)
        setAccessibleLabel(total, AgentFooterWording.agentsTotal(count: summary.totalCount))
        updateTotalAccessibilityDescription()

        rebuildActivityRows()
    }

    private func rebuildActivityRows() {
        let groups = panelState.filter.map { state in latestSummary.groups.filter { $0.state == state } }
            ?? latestSummary.groups

        var child = activityRows.getFirstChild()
        while let current = child {
            child = current.getNextSibling()
            activityRows.remove(child: current)
        }
        if groups.isEmpty {
            let empty = LabelRef(str: panelState.filter == nil ? "No agents running" : "No agents in this state")
            empty.add(cssClass: "aw-menu-disabled")
            empty.setMarginTop(margin: 8)
            empty.setMarginBottom(margin: 8)
            activityRows.append(child: empty)
        } else {
            for group in groups {
                let heading = LabelRef(str: "●  \(group.state.activityLabel.uppercased()) · \(group.rows.count)")
                heading.add(cssClass: "aw-agent-group-heading")
                heading.add(cssClass: agentStateCSS(group.state))
                heading.xalign = 0
                heading.setMarginTop(margin: 6)
                setAccessibleLabel(heading, "\(group.state.activityLabel), \(group.rows.count)")
                activityRows.append(child: heading)
                for row in group.rows {
                    let button = ButtonRef()
                    button.add(cssClass: "aw-agent-activity-row")
                    if row.isSelected { button.add(cssClass: "aw-selected") }
                    button.setHalign(align: .fill)
                    button.setSizeRequest(width: -1, height: 32)
                    let content = BoxRef(orientation: .vertical, spacing: 2)
                    let title = LabelRef(str: "\(row.agent) — \(row.displayTitle)")
                    title.add(cssClass: "aw-agent-activity-title")
                    title.xalign = 0
                    title.setEllipsize(mode: PangoEllipsizeMode(rawValue: 3))
                    let location = LabelRef(str: row.location)
                    location.add(cssClass: "aw-agent-activity-location")
                    location.xalign = 0
                    location.setEllipsize(mode: PangoEllipsizeMode(rawValue: 2))
                    content.append(child: title); content.append(child: location)
                    button.set(child: content)
                    button.onClicked { [weak self] _ in
                        self?.setExpanded(false)
                        self?.actions.selectPane(row.workspaceID, row.paneID)
                    }
                    setAccessibleLabel(button,
                        "\(row.agent), \(group.state.activityLabel), \(row.displayTitle), \(row.location)")
                    setAccessibleDescription(button, "Jumps to this agent's pane")
                    setAccessibleSelected(button, row.isSelected)
                    activityRows.append(child: button)
                }
            }
        }
    }

    private func agentStateCSS(_ state: AgentState) -> String {
        switch state {
        case .thinking: "aw-agent-thinking"
        case .output: "aw-agent-output"
        case .needsAttention, .error: "aw-agent-attention"
        default: "aw-agent-neutral"
        }
    }

    private func selectNextCollapsedAgent(matching state: AgentState) {
        guard let row = latestSummary.nextRow(
            matching: state, after: collapsedSelectionPaneIDs[state]
        ) else { return }
        collapsedSelectionPaneIDs[state] = row.paneID
        actions.selectPane(row.workspaceID, row.paneID)
    }

    private func collapsedStateButton(
        _ button: ButtonRef, label: LabelRef, count: Int, symbol: String, state: AgentState
    ) {
        label.label = "\(symbol)\n\(count > 99 ? "99+" : String(count))"
        button.setTooltip(text: "\(state.activityLabel) — Jump to Next Agent")
        setAccessibleLabel(button, AgentFooterWording.agentsInState(count: count, state: state))
        setAccessibleDescription(button, "Jumps to the next matching agent")
        button.set(visible: count > 0)
    }

    private func stateButton(
        _ button: ButtonRef, label: LabelRef, count: Int, symbol: String, state: AgentState
    ) {
        label.label = "\(symbol) \(count)"
        button.setTooltip(text: "\(state.activityLabel) — Show in Activity Panel")
        setAccessibleLabel(button, AgentFooterWording.agentsInState(count: count, state: state))
        setAccessibleDescription(button, "Shows the agent activity panel")
        button.set(visible: count > 0)
    }

    private func showActivity(state: AgentState) {
        setExpanded(true, filter: state)
    }

    private func setExpanded(
        _ expanded: Bool,
        filter: AgentState? = nil,
        restoreDisclosureFocus: Bool = true
    ) {
        let changed = expanded ? panelState.open(filter: filter) : panelState.close()
        rebuildActivityRows()
        guard changed else { return }
        applyPanelVisibility(restoreDisclosureFocus: restoreDisclosureFocus)
    }

    func sidebarModeChanged(to mode: SidebarWidthMode) {
        guard panelState.sidebarModeChanged(to: mode) else { return }
        rebuildActivityRows()
        applyPanelVisibility(restoreDisclosureFocus: false)
    }

    private func applyPanelVisibility(restoreDisclosureFocus: Bool) {
        let expanded = panelState.isExpanded
        activityPanel.set(visible: expanded)
        totalLabel.label = totalLabel.label.replacingOccurrences(of: expanded ? "⌃" : "⌄", with: expanded ? "⌄" : "⌃")
        total.setTooltip(text: expanded ? "Hide agent activity" : "Show agent activity")
        updateTotalAccessibilityDescription()
        setAccessibleExpanded(total, expanded)
        announceAccessibilityStatus(from: total,
            expanded ? "Agent activity panel opened" : "Agent activity panel closed")
        if !expanded && restoreDisclosureFocus { _ = total.grabFocus() }
    }

    private func updateTotalAccessibilityDescription() {
        setAccessibleDescription(total, panelState.isExpanded
            ? "Expanded. Hides the agent activity panel"
            : "Collapsed. Shows the agent activity panel")
    }

    private func quickSettingsPopover() -> PopoverRef {
        let box = BoxRef(orientation: .vertical, spacing: 5)
        let title = LabelRef(str: "Quick settings")
        title.add(cssClass: "aw-menu-title")
        title.xalign = 0
        box.append(child: title)
        let themeHeading = LabelRef(str: "Theme")
        themeHeading.add(cssClass: "aw-menu-heading")
        themeHeading.xalign = 0
        box.append(child: themeHeading)
        let themes = BoxRef(orientation: .horizontal, spacing: 3)
        for theme in AppTheme.allCases {
            let button = ButtonRef(label: theme.rawValue)
            button.add(cssClass: "aw-theme-choice")
            if theme == preferences.theme { button.add(cssClass: "aw-selected") }
            button.onClicked { [weak self] _ in
                guard let self else { return }
                self.preferences.theme = theme
                self.actions.updatePreferences(self.preferences)
                self.quickSettings.set(popover: self.quickSettingsPopover())
            }
            themes.append(child: button)
        }
        box.append(child: themes)
        let densityHeading = LabelRef(str: "Sidebar density")
        densityHeading.add(cssClass: "aw-menu-heading")
        densityHeading.xalign = 0
        box.append(child: densityHeading)
        let densities = BoxRef(orientation: .horizontal, spacing: 3)
        for density in SidebarDensity.allCases {
            let label = density == .standard ? "Standard" : "Compact"
            let button = ButtonRef(label: label)
            button.add(cssClass: "aw-theme-choice")
            if density == preferences.sidebarDensity { button.add(cssClass: "aw-selected") }
            button.onClicked { [weak self] _ in
                guard let self else { return }
                self.preferences.sidebarDensity = density
                self.actions.updatePreferences(self.preferences)
                self.quickSettings.set(popover: self.quickSettingsPopover())
            }
            densities.append(child: button)
        }
        box.append(child: densities)
        let notificationHeading = LabelRef(str: "Notifications")
        notificationHeading.add(cssClass: "aw-menu-heading")
        notificationHeading.xalign = 0
        box.append(child: notificationHeading)
        let mute = CheckButtonRef(label: "Mute notifications")
        mute.active = preferences.notificationsMuted
        mute.onToggled { [weak self] button in
            guard let self else { return }
            self.preferences.notificationsMuted = button.getActive()
            self.actions.updatePreferences(self.preferences)
        }
        box.append(child: mute)
        return menuPopover(box)
    }
}
