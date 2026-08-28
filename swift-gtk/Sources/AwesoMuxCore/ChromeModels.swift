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
}

public struct SidebarGroupSection: Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let color: WorkspaceGroupColor?
    public let isExpanded: Bool
    public let rows: [SidebarWorkspaceRow]
}

public struct SidebarChromeProjection: Equatable, Sendable {
    public static let width = SidebarWidthPolicy.defaultWidth
    public static let headerMinimumHeight = 48
    public static let footerMinimumHeight = 38

    public let groups: [SidebarGroupSection]

    public init(snapshot: SessionSnapshot, homeDirectory: String = NSHomeDirectory()) {
        groups = snapshot.groups.map { group in
            SidebarGroupSection(
                id: group.id,
                name: ChromeText.sanitized(group.name, limit: 80),
                color: group.color,
                isExpanded: !group.isCollapsed,
                rows: group.workspaces.compactMap { workspace in
                    guard !workspace.isSoftClosed else { return nil }
                    let pane = workspace.layout.pane(id: workspace.focusedPaneID)
                    return SidebarWorkspaceRow(
                        id: workspace.id,
                        title: ChromeText.sanitized(workspace.name, limit: 120),
                        location: FocusedPaneContext.displayPath(
                            pane?.workingDirectory ?? "",
                            homeDirectory: homeDirectory
                        ),
                        paneCount: workspace.layout.paneCount,
                        isSelected: workspace.id == snapshot.selectedWorkspaceID
                    )
                }
            )
        }
    }
}

public enum SidebarWidthMode: Equatable, Sendable {
    case expanded
    case collapsed
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
