import Foundation

public enum ChromeText {
    public static func sanitized(_ value: String, limit: Int) -> String {
        let scalars = value.unicodeScalars.filter { scalar in
            let code = scalar.value
            return code >= 0x20 && code != 0x7F && !(0x202A...0x202E).contains(code)
                && !(0x2066...0x2069).contains(code)
        }
        let clean = String(String.UnicodeScalarView(scalars))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > limit else { return clean }
        let retained = max(1, limit - 1)
        return String(clean.prefix(retained)) + "…"
    }
}

public struct SidebarWorkspaceRow: Equatable, Sendable {
    public let id: UUID
    public let title: String
    public let location: String
    public let paneCount: Int
    public let isSelected: Bool
    public let searchHaystack: String
    public let titleMatches: [Range<Int>]
    public let locationMatches: [Range<Int>]
    public let searchScore: Int?

    public init(
        id: UUID, title: String, location: String, paneCount: Int,
        isSelected: Bool, searchHaystack: String,
        titleMatches: [Range<Int>] = [], locationMatches: [Range<Int>] = [],
        searchScore: Int? = nil
    ) {
        self.id = id; self.title = title; self.location = location
        self.paneCount = paneCount; self.isSelected = isSelected
        self.searchHaystack = searchHaystack
        self.titleMatches = titleMatches; self.locationMatches = locationMatches
        self.searchScore = searchScore
    }

    func matching(_ query: String) -> SidebarWorkspaceRow? {
        let titleMatch = SidebarFuzzyMatcher.match(query: query, in: title)
        let locationMatch = SidebarFuzzyMatcher.match(query: query, in: location)
        let titleContainsQuery = SidebarSearchProjection.normalized(title).contains(query)
        let locationContainsQuery = SidebarSearchProjection.normalized(location).contains(query)
        let matchesHiddenToken = searchHaystack.contains(query)
            && !titleContainsQuery && !locationContainsQuery
        guard titleMatch != nil || locationMatch != nil || matchesHiddenToken else { return nil }
        let visibleScore = max(titleMatch?.score ?? Int.min, locationMatch?.score ?? Int.min)
        return SidebarWorkspaceRow(
            id: id, title: title, location: location, paneCount: paneCount,
            isSelected: isSelected, searchHaystack: searchHaystack,
            titleMatches: matchesHiddenToken ? [] : titleMatch?.ranges ?? [],
            locationMatches: matchesHiddenToken ? [] : locationMatch?.ranges ?? [],
            searchScore: matchesHiddenToken || visibleScore == Int.min ? 0 : visibleScore
        )
    }
}

public enum SidebarWorkspaceTitle {
    public static func resolve(workspace: WorkspaceSnapshot) -> String {
        let paneTitle = ChromeText.sanitized(
            workspace.layout.pane(id: workspace.focusedPaneID)?.title ?? "",
            limit: 120
        )
        return workspace.isNameUserEdited || paneTitle.isEmpty
            ? ChromeText.sanitized(workspace.name, limit: 120)
            : paneTitle
    }
}

public struct SidebarPanePeekItem: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let paneNumber: Int
    public let title: String
    public let location: String
    public let isActive: Bool
    public let agent: String?
    public let state: AgentState
    public let isRemote: Bool

    public static func project(
        workspace: WorkspaceSnapshot,
        homeDirectory: String = NSHomeDirectory()
    ) -> [SidebarPanePeekItem] {
        workspace.layout.panes.enumerated().map { index, pane in
            SidebarPanePeekItem(
                id: pane.id,
                paneNumber: index + 1,
                title: ChromeText.sanitized(pane.title, limit: 120).nonEmpty ?? "Terminal",
                location: FocusedPaneContext.displayPath(
                    pane.workingDirectory, homeDirectory: homeDirectory
                ),
                isActive: pane.id == workspace.focusedPaneID,
                agent: pane.agent.map { ChromeText.sanitized($0, limit: 80) },
                state: pane.agentState,
                isRemote: pane.ownership == .remoteZmx
            )
        }
    }

    public var accessibilityLabel: String {
        var parts = ["Jump to pane \(paneNumber)", title]
        if let agent, !agent.isEmpty { parts.append(agent) } else { parts.append("Shell") }
        parts.append(state.accessibilityLabel)
        if isRemote { parts.append("remote") }
        if isActive { parts.append("active pane") }
        return parts.joined(separator: ", ")
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}

private extension AgentState {
    var accessibilityLabel: String {
        switch self {
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
}

public enum SidebarAgentKind: String, Equatable, Sendable {
    case claude, codex, openCode, pi, grok, shell

    static func resolve(_ agent: String?) -> SidebarAgentKind {
        let normalized = agent.map { ChromeText.sanitized($0, limit: 80).lowercased() } ?? ""
        if normalized.contains("claude") { return .claude }
        if normalized.contains("codex") { return .codex }
        if normalized.contains("opencode") || normalized.contains("open code") { return .openCode }
        if normalized == "pi" || normalized.hasPrefix("pi ") { return .pi }
        if normalized.contains("grok") { return .grok }
        return .shell
    }
}

public struct SidebarAgentTilePresentation: Equatable, Sendable {
    public let kind: SidebarAgentKind
    public let name: String
    public let state: AgentState

    public var showsBadge: Bool { state != .idle }
    public var stateToken: String { state == .needsAttention ? "needs" : state.rawValue }

    public var badgeSymbol: String {
        switch state {
        case .needsAttention: "!"
        case .error: "×"
        case .done: "✓"
        case .output: "•"
        case .waiting: "Ⅱ"
        case .running: "▶"
        case .thinking: "◔"
        case .idle: ""
        }
    }

    public var accessibilityLabel: String { "\(name), \(state.accessibilityLabel)" }

    public static func project(agent: String?, state: AgentState) -> SidebarAgentTilePresentation {
        let sanitized = agent.map { ChromeText.sanitized($0, limit: 80) }
        let name = sanitized.flatMap { $0.isEmpty ? nil : $0 } ?? "Shell"
        return SidebarAgentTilePresentation(kind: .resolve(sanitized), name: name, state: state)
    }

    public static func project(pane: PaneSnapshot) -> SidebarAgentTilePresentation {
        project(agent: pane.agent, state: pane.agentState)
    }

    public static func project(workspace: WorkspaceSnapshot) -> SidebarAgentTilePresentation {
        let priority: [AgentState] = [
            .needsAttention, .error, .output, .thinking, .waiting, .running, .done, .idle,
        ]
        let panes = workspace.layout.panes
        let winning = priority.lazy.compactMap { state in panes.first { $0.agentState == state } }.first
            ?? panes.first
        return winning.map { project(pane: $0) } ?? project(agent: nil, state: .idle)
    }
}

public enum SidebarJumpNumberDisplay: Equatable, Sendable {
    case hidden
    case overlay
    case belowTile

    public static func resolve(
        collapsed: Bool, alwaysShow: Bool, primaryModifierHeld: Bool
    ) -> SidebarJumpNumberDisplay {
        guard collapsed else { return .hidden }
        if alwaysShow { return .belowTile }
        return primaryModifierHeld ? .overlay : .hidden
    }
}

public enum SidebarGroupClosePolicy {
    public static func showsCloseButton(
        pointerOrFocusInside: Bool,
        isCollapsedRail: Bool,
        isFiltering: Bool,
        hasResolvedGroup: Bool,
        isGroupEmpty: Bool,
        isGroupCollapsed: Bool,
        isDragActive: Bool
    ) -> Bool {
        let restsVisible = isGroupEmpty && !isGroupCollapsed && !isDragActive
        return (pointerOrFocusInside || restsVisible)
            && !isCollapsedRail
            && !isFiltering
            && hasResolvedGroup
    }
}

public enum SidebarInsertionEdge: Equatable, Sendable {
    case before
    case after
}

public enum SidebarInsertionResolver {
    public static func preRemovalIndex(targetIndex: Int, edge: SidebarInsertionEdge) -> Int {
        max(0, targetIndex + (edge == .after ? 1 : 0))
    }

    public static func postRemovalTargetIndex(sourceIndex: Int, preRemovalIndex: Int) -> Int {
        sourceIndex < preRemovalIndex ? preRemovalIndex - 1 : preRemovalIndex
    }

    public static func reorderTarget(
        sourceIndex: Int, targetIndex: Int, edge: SidebarInsertionEdge, count: Int
    ) -> Int? {
        guard count > 0, (0..<count).contains(sourceIndex), (0..<count).contains(targetIndex) else {
            return nil
        }
        let preRemoval = min(count, preRemovalIndex(targetIndex: targetIndex, edge: edge))
        let destination = postRemovalTargetIndex(
            sourceIndex: sourceIndex, preRemovalIndex: preRemoval
        )
        return destination == sourceIndex ? nil : destination
    }
}

public enum SidebarAnnouncement {
    public static func movedWorkspace(
        title: String, position: Int, count: Int, groupName: String
    ) -> String {
        "Moved \(title) to position \(position) of \(count) in \(groupName)"
    }

    public static func movedGroup(name: String, position: Int, count: Int) -> String {
        "Moved \(name) group to position \(position) of \(count)"
    }

    public static func movedPinnedWorkspace(title: String, position: Int, count: Int) -> String {
        "Moved \(title) to position \(position) of \(count) in Pinned"
    }

    public static func unansweredTurnPromoted(title: String) -> String {
        "\(title) is still waiting for a reply, moved to Needs Input"
    }

    public static func attentionPromoted(agent: String, title: String) -> String {
        "\(agent) in \(title) needs input."
    }

    public static func agentCompleted(agent: String, title: String) -> String {
        "\(agent) in \(title) completed."
    }

    public static func agentReportedError(agent: String, title: String) -> String {
        "\(agent) in \(title) reported an error."
    }
}

public enum SidebarAccessibilityCopy {
    public static let newWorkspaceHint = "Creates a new workspace in the current group."
    public static let newWorkspaceOptionsHint =
        "Opens a menu to create a new workspace group or a workspace in a specific group."
    public static let newWorkspaceMenuHint =
        "Opens a menu with New Workspace, New Workspace in a chosen group, and New Workspace Group"
    public static let collapsedSearchHint =
        "Opens the command palette to search workspaces and actions."

    public static func position(_ position: Int, of count: Int) -> String? {
        guard position > 0, count > 0, position <= count else { return nil }
        return "Position \(position) of \(count)"
    }

    public static func workspaceCount(_ count: Int) -> String {
        "\(count) workspace\(count == 1 ? "" : "s")"
    }
}

public enum WorkspaceRenameDraft {
    public static let emptyHint = "Enter a workspace name to enable Save"

    public static func sanitized(_ value: String) -> String {
        ChromeText.sanitized(value, limit: 120)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func canSubmit(_ value: String) -> Bool {
        !sanitized(value).isEmpty
    }

    public static func heading(for currentTitle: String) -> String {
        "Rename '\(ChromeText.sanitized(currentTitle, limit: 120))'"
    }
}

public struct WorkspaceGroupNameDraft: Equatable, Sendable {
    public static let inputScalarLimit = 4_096
    public static let createEmptyHint = "Enter a workspace group name to enable Create"
    public static let renameEmptyHint = "Enter a workspace group name to enable Save"

    public let typedName: String
    public let sanitizedName: String
    public let isDuplicate: Bool
    public let isMixedScript: Bool

    public init(typedName: String, existingGroupNames: some Sequence<String>) {
        let bounded = Self.clampedInput(typedName)
        let sanitized = ChromeText.sanitized(bounded, limit: 120)
        self.typedName = bounded
        sanitizedName = sanitized
        isMixedScript = Self.hasSuspiciousScriptMixing(bounded)
        isDuplicate = !sanitized.isEmpty && existingGroupNames.contains { existing in
            ChromeText.sanitized(existing, limit: 120).compare(
                sanitized, options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    public static func clampedInput(_ input: String) -> String {
        String(input.unicodeScalars.prefix(inputScalarLimit))
    }

    public var canSubmit: Bool { validationMessage == nil }

    public var validationMessage: String? {
        if sanitizedName.isEmpty {
            return typedName.isEmpty ? "Enter a group name." : "Enter a visible group name."
        }
        if isMixedScript {
            return "Mixing Latin with Cyrillic or Greek letters isn't allowed here — use one alphabet."
        }
        if isDuplicate { return "\"\(sanitizedName)\" already exists." }
        return nil
    }

    public var sanitizationFeedback: String? {
        guard canSubmit, !typedName.utf8.elementsEqual(sanitizedName.utf8) else { return nil }
        return "Some characters or spacing will be adjusted. This name will be saved as “\u{2068}\(sanitizedName)\u{2069}”."
    }

    public var spokenSanitizationFeedback: String? {
        sanitizationFeedback?
            .replacingOccurrences(of: "\u{2068}", with: "")
            .replacingOccurrences(of: "\u{2069}", with: "")
    }

    private static func hasSuspiciousScriptMixing(_ value: String) -> Bool {
        var latin = false, greek = false, cyrillic = false
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x0041...0x024F: latin = true
            case 0x0370...0x03FF: greek = true
            case 0x0400...0x052F: cyrillic = true
            default: continue
            }
        }
        return (latin && (greek || cyrillic)) || (greek && cyrillic)
    }
}

public struct SidebarGroupSection: Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let color: WorkspaceGroupColor?
    public let isExpanded: Bool
    public let rows: [SidebarWorkspaceRow]

    public init(id: UUID, name: String, color: WorkspaceGroupColor?, isExpanded: Bool, rows: [SidebarWorkspaceRow]) {
        self.id = id; self.name = name; self.color = color; self.isExpanded = isExpanded; self.rows = rows
    }
}

public enum CollapsedGroupAttentionState: String, Equatable, Sendable {
    case needsAttention
    case error
    case thinking
}

public struct CollapsedGroupAttention: Equatable, Sendable {
    public let needsAttention: Int
    public let errors: Int
    public let thinking: Int

    public var primaryState: CollapsedGroupAttentionState? {
        if needsAttention > 0 { return .needsAttention }
        if errors > 0 { return .error }
        if thinking > 0 { return .thinking }
        return nil
    }

    public var accessibilityPhrase: String {
        var parts: [String] = []
        if needsAttention > 0 { parts.append("\(needsAttention) need input") }
        if errors > 0 { parts.append("\(errors) error\(errors == 1 ? "" : "s")") }
        if thinking > 0 { parts.append("\(thinking) thinking") }
        return parts.joined(separator: ", ")
    }

    public static func resolve(group: WorkspaceGroupSnapshot) -> CollapsedGroupAttention {
        var needsAttention = 0, errors = 0, thinking = 0
        for pane in group.workspaces.lazy.filter({ !$0.isSoftClosed }).flatMap({ $0.layout.panes }) {
            switch pane.agentState {
            case .needsAttention: needsAttention += 1
            case .error: errors += 1
            case .thinking: thinking += 1
            default: break
            }
        }
        return CollapsedGroupAttention(needsAttention: needsAttention, errors: errors, thinking: thinking)
    }
}

public struct WorkspaceCreationContext: Equatable, Sendable {
    public let groupID: UUID
    public let workingDirectory: String

    public init(groupID: UUID, workingDirectory: String) {
        self.groupID = groupID
        self.workingDirectory = workingDirectory
    }
}

public enum WorkspaceCreationTarget {
    public static let defaultGroupName = "awesoMux"

    public static func selectedOwningGroupID(in snapshot: SessionSnapshot) -> UUID? {
        guard let selected = snapshot.selectedWorkspaceID else { return nil }
        return snapshot.groups.first { group in
            group.workspaces.contains { $0.id == selected }
        }?.id
    }

    public static func defaultGroupID(
        in snapshot: SessionSnapshot,
        defaultGroupName: String = WorkspaceCreationTarget.defaultGroupName
    ) -> UUID? {
        snapshot.groups.first { group in
            ChromeText.sanitized(group.name, limit: 120).compare(
                ChromeText.sanitized(defaultGroupName, limit: 120),
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }?.id
    }

    public static func currentContextGroupID(
        in snapshot: SessionSnapshot,
        defaultGroupName: String = WorkspaceCreationTarget.defaultGroupName
    ) -> UUID? {
        selectedOwningGroupID(in: snapshot)
            ?? defaultGroupID(in: snapshot, defaultGroupName: defaultGroupName)
    }

    public static func currentDirectory(in snapshot: SessionSnapshot) -> String? {
        guard let workspace = snapshot.selectedWorkspace,
              let pane = workspace.layout.pane(id: workspace.focusedPaneID)
        else { return nil }
        let directory = pane.workingDirectory.trimmingCharacters(in: .newlines)
        return directory.isEmpty ? nil : directory
    }

    public static func workspaceHere(
        _ workspaceID: UUID,
        in snapshot: SessionSnapshot
    ) -> WorkspaceCreationContext? {
        guard let group = snapshot.groups.first(where: { group in
            group.workspaces.contains { $0.id == workspaceID && !$0.isSoftClosed }
        }),
        let workspace = group.workspaces.first(where: { $0.id == workspaceID }),
        let pane = workspace.layout.pane(id: workspace.focusedPaneID)
        else { return nil }
        let directory = pane.workingDirectory.trimmingCharacters(in: .newlines)
        guard !directory.isEmpty else { return nil }
        return WorkspaceCreationContext(groupID: group.id, workingDirectory: directory)
    }
}

public struct SidebarChromeProjection: Equatable, Sendable {
    public static let width = SidebarWidthPolicy.defaultWidth
    public static let headerMinimumHeight = 48
    public static let footerMinimumHeight = 38

    public let groups: [SidebarGroupSection]

    public init(snapshot: SessionSnapshot, homeDirectory: String = NSHomeDirectory()) {
        groups = snapshot.groups.enumerated().map { index, group in
            SidebarGroupSection(
                id: group.id,
                name: ChromeText.sanitized(group.name, limit: 80),
                color: SidebarTintProjection.resolvedColor(for: group, unfilteredIndex: index),
                isExpanded: !group.isCollapsed,
                rows: group.workspaces.compactMap { workspace in
                    guard !workspace.isSoftClosed else { return nil }
                    let pane = workspace.layout.pane(id: workspace.focusedPaneID)
                    let searchValues = [workspace.name]
                        + workspace.layout.panes.flatMap { pane in
                            [pane.title, pane.workingDirectory, pane.ownership.searchToken,
                             pane.agent ?? "", pane.agentState.searchToken]
                        }
                    return SidebarWorkspaceRow(
                        id: workspace.id,
                        title: SidebarWorkspaceTitle.resolve(workspace: workspace),
                        location: FocusedPaneContext.displayPath(
                            pane?.workingDirectory ?? "",
                            homeDirectory: homeDirectory
                        ),
                        paneCount: workspace.layout.paneCount,
                        isSelected: workspace.id == snapshot.selectedWorkspaceID,
                        searchHaystack: SidebarSearchProjection.normalized(
                            searchValues.joined(separator: " ")
                        )
                    )
                }
            )
        }
    }
}

public struct SidebarGroupAccessibilityPresentation: Equatable, Sendable {
    public let workspaceCount: Int
    public let hasSelectedDescendant: Bool
    public let executionText: String?

    public init(group: WorkspaceGroupSnapshot, selectedWorkspaceID: UUID?) {
        let workspaces = group.workspaces.filter { !$0.isSoftClosed }
        workspaceCount = workspaces.count
        hasSelectedDescendant = selectedWorkspaceID.map { selected in
            workspaces.contains { $0.id == selected }
        } ?? false
        let panes = workspaces.flatMap(\.layout.panes)
        if panes.isEmpty {
            executionText = "Local creation default"
        } else if panes.allSatisfy({ $0.ownership == .local }) {
            executionText = "Local panes"
        } else {
            // The current Linux snapshot declares remote ownership but does
            // not yet carry the destination identity required by the pinned
            // reference copy ("Remote panes on <destination>"). Do not invent
            // a weaker visible or spoken substitute.
            executionText = nil
        }
    }
}

public enum SidebarTintProjection {
    private static let automaticPalette: [WorkspaceGroupColor] = [.teal, .green, .blue, .pink, .yellow, .red, .gray]

    public static func resolvedColor(
        for group: WorkspaceGroupSnapshot,
        unfilteredIndex: Int
    ) -> WorkspaceGroupColor {
        if let color = group.color { return color }
        if group.name.range(of: "awesomux", options: .caseInsensitive) != nil { return .mauve }
        let index = max(unfilteredIndex, 0) % automaticPalette.count
        return automaticPalette[index]
    }
}

public struct SidebarSearchOutput: Equatable, Sendable {
    public let groups: [SidebarGroupSection]
    public let orderedWorkspaceIDs: [UUID]
    public let topMatchID: UUID?
    public let isFiltering: Bool

    public var hasMatches: Bool { !orderedWorkspaceIDs.isEmpty }
}

public struct EmptyWorkspacePresentation: Equatable, Sendable {
    public let showsCollapsedSidebarAction: Bool
    public let showsReopenAction: Bool
    public let visibleCopy: String
    public let accessibleCopy: String

    public static func resolve(snapshot: SessionSnapshot, isFiltering: Bool) -> EmptyWorkspacePresentation {
        let canReopen = !snapshot.recentlyClosedWorkspaces.isEmpty
        return EmptyWorkspacePresentation(
            showsCollapsedSidebarAction: snapshot.groups.isEmpty && !isFiltering,
            showsReopenAction: canReopen,
            visibleCopy: canReopen
                ? "Create a workspace with Ctrl+Super+N, or reopen the last one you closed."
                : "Create a workspace with Ctrl+Super+N.",
            accessibleCopy: canReopen
                ? "Create a workspace with Control-Super-N, or reopen the last one you closed."
                : "Create a workspace with Control-Super-N."
        )
    }
}

public struct WorkspaceMoveAvailability: Equatable, Sendable {
    public let canMoveUp: Bool
    public let canMoveDown: Bool
    public let previousGroup: (id: UUID, name: String)?
    public let nextGroup: (id: UUID, name: String)?

    public static func resolve(snapshot: SessionSnapshot, workspaceID: UUID) -> WorkspaceMoveAvailability? {
        guard let groupIndex = snapshot.groups.firstIndex(where: { group in
            group.workspaces.contains(where: { $0.id == workspaceID })
        }), let workspaceIndex = snapshot.groups[groupIndex].workspaces.firstIndex(where: { $0.id == workspaceID })
        else { return nil }
        let previous = groupIndex > 0 ? snapshot.groups[groupIndex - 1] : nil
        let next = groupIndex < snapshot.groups.count - 1 ? snapshot.groups[groupIndex + 1] : nil
        return WorkspaceMoveAvailability(
            canMoveUp: workspaceIndex > 0,
            canMoveDown: workspaceIndex < snapshot.groups[groupIndex].workspaces.count - 1,
            previousGroup: previous.map { ($0.id, ChromeText.sanitized($0.name, limit: 80)) },
            nextGroup: next.map { ($0.id, ChromeText.sanitized($0.name, limit: 80)) }
        )
    }

    public static func == (lhs: WorkspaceMoveAvailability, rhs: WorkspaceMoveAvailability) -> Bool {
        lhs.canMoveUp == rhs.canMoveUp && lhs.canMoveDown == rhs.canMoveDown
            && lhs.previousGroup?.id == rhs.previousGroup?.id && lhs.previousGroup?.name == rhs.previousGroup?.name
            && lhs.nextGroup?.id == rhs.nextGroup?.id && lhs.nextGroup?.name == rhs.nextGroup?.name
    }
}

public struct LiftedSidebarWorkspaceRow: Equatable, Sendable {
    public let row: SidebarWorkspaceRow
    public let originGroupID: UUID
    public let originGroupName: String
    public let originGroupColor: WorkspaceGroupColor?
    public let originGroupUnfilteredIndex: Int
}

public struct SidebarLiftedOutput: Equatable, Sendable {
    public let attention: [LiftedSidebarWorkspaceRow]
    public let pinned: [LiftedSidebarWorkspaceRow]
    public let groups: [SidebarGroupSection]
    public let orderedWorkspaceIDs: [UUID]
    public let topMatchID: UUID?
    public let isFiltering: Bool
}

public enum SidebarLiftedProjection {
    public static func project(
        snapshot: SessionSnapshot,
        query: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> SidebarLiftedOutput {
        let searched = SidebarSearchProjection.project(
            snapshot: snapshot, query: query, homeDirectory: homeDirectory
        )
        let groupIndexByID = Dictionary(uniqueKeysWithValues: snapshot.groups.enumerated().map { ($1.id, $0) })
        var liftedByID: [UUID: LiftedSidebarWorkspaceRow] = [:]
        for group in searched.groups {
            let index = groupIndexByID[group.id] ?? 0
            for row in group.rows {
                liftedByID[row.id] = LiftedSidebarWorkspaceRow(
                    row: row,
                    originGroupID: group.id,
                    originGroupName: group.name,
                    originGroupColor: group.color,
                    originGroupUnfilteredIndex: index
                )
            }
        }

        let pinned = snapshot.pinnedWorkspaceIDs.compactMap { liftedByID[$0] }
        let pinnedSet = Set(pinned.map { $0.row.id })
        // Membership and arrival order both come from the snapshot's single
        // reconciled list. Re-deriving membership from raw pane state here
        // would resurrect a passively or explicitly acknowledged row whose
        // attention producer has not yet emitted its clearing transition.
        let attentionOrder = snapshot.attentionWorkspaceIDs.filter {
            liftedByID[$0] != nil && !pinnedSet.contains($0)
        }
        let attention = attentionOrder.compactMap { liftedByID[$0] }
        let liftedSet = pinnedSet.union(attention.map { $0.row.id })

        let groups = searched.groups.compactMap { group -> SidebarGroupSection? in
            let rows = group.rows.filter { !liftedSet.contains($0.id) }
            guard !searched.isFiltering || !rows.isEmpty else { return nil }
            return SidebarGroupSection(
                id: group.id, name: group.name, color: group.color,
                isExpanded: group.isExpanded, rows: rows
            )
        }
        let ordered = attention.map { $0.row.id }
            + pinned.map { $0.row.id }
            + groups.flatMap { $0.rows.map(\.id) }
        return SidebarLiftedOutput(
            attention: attention,
            pinned: pinned,
            groups: groups,
            orderedWorkspaceIDs: ordered,
            topMatchID: searched.isFiltering ? ordered.first : nil,
            isFiltering: searched.isFiltering
        )
    }
}

public enum SidebarSearchProjection {
    public static func project(
        snapshot: SessionSnapshot,
        query: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> SidebarSearchOutput {
        let source = SidebarChromeProjection(snapshot: snapshot, homeDirectory: homeDirectory)
        let needle = normalized(query)
        guard !needle.isEmpty else {
            let ordered = source.groups.flatMap { $0.rows.map(\.id) }
            return SidebarSearchOutput(
                groups: source.groups,
                orderedWorkspaceIDs: ordered,
                topMatchID: nil,
                isFiltering: false
            )
        }

        let groups = source.groups.compactMap { group -> SidebarGroupSection? in
            let groupMatches = normalized(group.name).contains(needle)
            let rows = groupMatches ? group.rows : group.rows.enumerated().compactMap {
                index, row -> (Int, SidebarWorkspaceRow)? in
                row.matching(needle).map { (index, $0) }
            }.sorted { lhs, rhs in
                let lhsScore = lhs.1.searchScore ?? Int.min
                let rhsScore = rhs.1.searchScore ?? Int.min
                return lhsScore == rhsScore ? lhs.0 < rhs.0 : lhsScore > rhsScore
            }.map(\.1)
            guard !rows.isEmpty else { return nil }
            return SidebarGroupSection(
                id: group.id,
                name: group.name,
                color: group.color,
                isExpanded: true,
                rows: rows
            )
        }
        let ordered = groups.flatMap { $0.rows.map(\.id) }
        return SidebarSearchOutput(
            groups: groups,
            orderedWorkspaceIDs: ordered,
            topMatchID: ordered.first,
            isFiltering: true
        )
    }

    static func normalized(_ value: String) -> String {
        ChromeText.sanitized(value, limit: 8_192)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

}

private extension SessionOwnership {
    var searchToken: String {
        switch self {
        case .local: "local"
        case .remoteZmx: "remote ssh zmx"
        }
    }
}

private extension AgentState {
    var searchToken: String {
        switch self {
        case .idle: "idle"
        case .running: "running"
        case .waiting: "waiting needs input"
        case .thinking: "thinking"
        case .output: "output ready"
        case .needsAttention: "needs input needs attention"
        case .done: "done completed"
        case .error: "error failed"
        }
    }
}

public enum SidebarWidthMode: Equatable, Sendable {
    case expanded
    case collapsed
}

public enum SidebarProximityState: Equatable, Sendable {
    case dormant
    case cue
    case revealed
}

public enum SidebarEdgeTabStyle: Equatable, Sendable {
    case cue
    case attention
}

public enum SidebarPresentationPolicy {
    public static let revealDistance = 40

    public static func proximity(
        pointerX: Double,
        containerWidth: Double,
        position: SidebarPosition
    ) -> SidebarProximityState {
        guard pointerX.isFinite, containerWidth.isFinite, containerWidth > 0 else { return .dormant }
        let clampedX = min(max(pointerX, 0), containerWidth)
        let distance = position == .left ? clampedX : containerWidth - clampedX
        return distance <= Double(revealDistance) ? .revealed : .cue
    }

    public static func sidebarWidth(
        dividerCoordinate: Int,
        paneExtent: Int,
        position: SidebarPosition
    ) -> Int {
        guard paneExtent > 0 else { return 0 }
        let divider = min(max(dividerCoordinate, 0), paneExtent)
        return position == .left ? divider : paneExtent - divider
    }

    public static func dividerCoordinate(
        sidebarWidth: Int,
        paneExtent: Int,
        position: SidebarPosition
    ) -> Int {
        guard paneExtent > 0 else { return 0 }
        let width = min(max(sidebarWidth, 0), paneExtent)
        return position == .left ? width : paneExtent - width
    }

    public static func edgeTabStyle(
        isPersistentlyHidden: Bool,
        proximity: SidebarProximityState,
        hasAttention: Bool
    ) -> SidebarEdgeTabStyle? {
        guard isPersistentlyHidden else { return nil }
        switch proximity {
        case .revealed: return nil
        case .cue: return .cue
        case .dormant: return hasAttention ? .attention : nil
        }
    }

    public static func hasAttention(_ snapshot: SessionSnapshot) -> Bool {
        snapshot.groups.lazy
            .flatMap(\.workspaces)
            .filter { !$0.isSoftClosed }
            .contains { workspace in
                let acknowledged = Set(workspace.acknowledgedAttentionPaneIDs)
                return workspace.layout.panes.contains {
                    $0.agentState == .needsAttention && !acknowledged.contains($0.id)
                }
            }
    }
}

public enum SidebarWidthPolicy {
    public static let expandedWidth = 296
    public static let collapsedWidth = 60
    public static let defaultWidth = expandedWidth
    public static let fallbackLastNonCollapsedWidth = expandedWidth
    public static let railThreshold = 250
    private static let maximumRepresentableWidth = Int(Int32.max)

    public static func committedWidth(for width: Double) -> Int {
        guard width.isFinite else { return defaultWidth }
        let bounded = min(max(width.rounded(.down), Double(collapsedWidth)), Double(maximumRepresentableWidth))
        let floored = Int(bounded)
        return floored < railThreshold ? collapsedWidth : floored
    }

    public static func constrainedLiveWidth(for proposed: Double, maximumWidth: Double) -> Int {
        guard proposed.isFinite else { return collapsedWidth }
        let boundedMaximum = maximumWidth.isFinite
            ? min(max(maximumWidth.rounded(.down), Double(collapsedWidth)), Double(maximumRepresentableWidth))
            : Double(collapsedWidth)
        let ceiling = Int(boundedMaximum)
        let boundedProposed = min(max(proposed.rounded(.down), Double(collapsedWidth)), Double(maximumRepresentableWidth))
        let clamped = min(Int(boundedProposed), ceiling)
        return clamped < railThreshold ? collapsedWidth : clamped
    }

    public static func mode(for width: Double) -> SidebarWidthMode {
        committedWidth(for: width) < railThreshold ? .collapsed : .expanded
    }

    public static func shouldRestoreExpanded(
        currentWidth: Double,
        maximumWidth: Double,
        userChoseRail: Bool
    ) -> Bool {
        currentWidth < Double(railThreshold)
            && maximumWidth >= Double(railThreshold)
            && !userChoseRail
    }

    public static func normalizedLastNonCollapsedWidth(_ width: Double?) -> Int {
        guard let width else { return fallbackLastNonCollapsedWidth }
        let committed = committedWidth(for: width)
        return mode(for: Double(committed)) == .collapsed ? fallbackLastNonCollapsedWidth : committed
    }

    public static func toggleWidth(currentWidth: Double, lastNonCollapsedWidth: Double?) -> Int {
        mode(for: currentWidth) == .collapsed
            ? normalizedLastNonCollapsedWidth(lastNonCollapsedWidth)
            : collapsedWidth
    }

    public static func updatedLastNonCollapsedWidth(
        currentWidth: Double,
        previousLastNonCollapsedWidth: Double?
    ) -> Int {
        let committed = committedWidth(for: currentWidth)
        return mode(for: Double(committed)) == .collapsed
            ? normalizedLastNonCollapsedWidth(previousLastNonCollapsedWidth)
            : committed
    }
}

public struct FocusedPaneIdentity: Equatable, Sendable {
    public let workspaceID: UUID
    public let paneID: UUID
    public let generation: UInt64

    public init(workspaceID: UUID, paneID: UUID, generation: UInt64) {
        self.workspaceID = workspaceID
        self.paneID = paneID
        self.generation = generation
    }
}

public struct FocusedPaneContext: Equatable, Sendable {
    public let identity: FocusedPaneIdentity
    public let project: String
    public let path: String
    public let copyPath: String

    public init(
        identity: FocusedPaneIdentity,
        project: String,
        path: String,
        copyPath: String
    ) {
        self.identity = identity
        self.project = project
        self.path = path
        self.copyPath = copyPath
    }

    public static func resolve(
        identity: FocusedPaneIdentity,
        workingDirectory: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> FocusedPaneContext {
        let raw = workingDirectory.trimmingCharacters(in: .newlines)
        let effective = raw.isEmpty ? homeDirectory : raw
        let standardized = (effective as NSString).standardizingPath
        let leaf = standardized == "/" ? "/" : (standardized as NSString).lastPathComponent
        return FocusedPaneContext(
            identity: identity,
            project: ChromeText.sanitized(leaf, limit: 80),
            path: displayPath(standardized, homeDirectory: homeDirectory),
            copyPath: standardized
        )
    }

    public static func displayPath(_ value: String, homeDirectory: String) -> String {
        let raw = value.trimmingCharacters(in: .newlines)
        guard !raw.isEmpty else { return "~" }
        let standardized = (raw as NSString).standardizingPath
        let collapsed: String
        if standardized == homeDirectory {
            collapsed = "~"
        } else if standardized.hasPrefix(homeDirectory + "/") {
            collapsed = "~" + standardized.dropFirst(homeDirectory.count)
        } else {
            collapsed = standardized
        }
        return ChromeText.sanitized(collapsed, limit: 180)
    }
}

public struct FocusedPaneContextCoordinator: Sendable {
    public private(set) var currentIdentity: FocusedPaneIdentity?
    public private(set) var context: FocusedPaneContext?
    private var generation: UInt64 = 0

    public init() {}

    public mutating func begin(workspaceID: UUID, paneID: UUID) -> FocusedPaneIdentity {
        generation &+= 1
        let identity = FocusedPaneIdentity(
            workspaceID: workspaceID,
            paneID: paneID,
            generation: generation
        )
        currentIdentity = identity
        context = nil
        return identity
    }

    @discardableResult
    public mutating func publish(_ candidate: FocusedPaneContext) -> Bool {
        guard candidate.identity == currentIdentity else { return false }
        context = candidate
        return true
    }
}
