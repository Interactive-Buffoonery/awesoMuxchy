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
    public static let width = 188
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
