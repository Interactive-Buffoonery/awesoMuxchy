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
                    let searchValues = [group.name, workspace.name]
                        + workspace.layout.panes.flatMap { pane in
                            [pane.title, pane.workingDirectory, pane.ownership.searchToken,
                             pane.agent ?? "", pane.agentState.searchToken]
                        }
                    return SidebarWorkspaceRow(
                        id: workspace.id,
                        title: ChromeText.sanitized(workspace.name, limit: 120),
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
            let rows = group.rows.filter { $0.searchHaystack.contains(needle) }
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
            .flatMap { $0.layout.panes }
            .contains { $0.agentState == .needsAttention }
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
