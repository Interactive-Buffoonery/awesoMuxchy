import Foundation

public enum CommandPaletteMode: Equatable, Sendable {
    case unified
    case actionsOnly
}

public enum CommandPaletteTarget: Equatable, Hashable, Sendable {
    case workspace(UUID)
    case command(CommandID)
}

public struct CommandPaletteItem: Equatable, Identifiable, Sendable {
    public let target: CommandPaletteTarget
    public let title: String
    public let subtitle: String?
    public let score: Int

    public var id: String {
        switch target {
        case let .workspace(id): "workspace.\(id.uuidString)"
        case let .command(id): "command.\(id.rawValue)"
        }
    }
}

public struct CommandPaletteSection: Equatable, Identifiable, Sendable {
    public let title: String
    public let items: [CommandPaletteItem]

    public var id: String { title }
}

public struct CommandPaletteOutput: Equatable, Sendable {
    public let mode: CommandPaletteMode
    public let query: String
    public let sections: [CommandPaletteSection]
    public let defaultSelectionIndex: Int?

    public var items: [CommandPaletteItem] { sections.flatMap(\.items) }
}

public enum CommandPaletteSelectionPolicy {
    public static func destination(current: Int?, count: Int, delta: Int) -> Int? {
        guard count > 0, delta != 0 else { return nil }
        guard let current else { return delta < 0 ? count - 1 : 0 }
        return min(max(current + delta, 0), count - 1)
    }
}

/// A GTK-neutral projection of the pinned unified command-palette contract.
/// Workspaces precede actions, filtering is fuzzy and stable, and a leading
/// `>` enters the reference actions-only namespace.
public enum CommandPaletteProjection {
    public static let workspaceLimit = 50

    public static func project(
        snapshot: SessionSnapshot,
        commands: [CommandDefinition],
        enabledCommandIDs: Set<CommandID>,
        rawQuery: String,
        homeDirectory: String = NSHomeDirectory()
    ) -> CommandPaletteOutput {
        let resolved = resolve(rawQuery)
        var sections: [CommandPaletteSection] = []

        if resolved.mode == .unified {
            let workspaces = workspaceItems(
                snapshot: snapshot,
                query: resolved.query,
                homeDirectory: homeDirectory
            )
            if !workspaces.isEmpty {
                sections.append(CommandPaletteSection(title: "Workspaces", items: workspaces))
            }
        }

        let enabled = commands.filter { enabledCommandIDs.contains($0.id) }
        let actionItems: [CommandPaletteItem]
        if resolved.mode == .unified && resolved.query.isEmpty {
            let suggested: [CommandID] = [
                .newWorkspace,
                .newWorkspaceInCurrentDirectory,
                .reopenClosedWorkspace,
            ]
            actionItems = suggested.compactMap { id in
                enabled.first(where: { $0.id == id }).map { commandItem($0) }
            }
            if !actionItems.isEmpty {
                sections.append(CommandPaletteSection(title: "Suggested", items: actionItems))
            }
        } else {
            actionItems = rankedCommandItems(
                commands: enabled,
                query: resolved.query,
                includeAllWhenEmpty: resolved.mode == .actionsOnly
            )
            if !actionItems.isEmpty {
                sections.append(CommandPaletteSection(title: "Actions", items: actionItems))
            }
        }

        let isBareUnified = resolved.mode == .unified
            && rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return CommandPaletteOutput(
            mode: resolved.mode,
            query: resolved.query,
            sections: sections,
            defaultSelectionIndex: isBareUnified || sections.isEmpty ? nil : 0
        )
    }

    public static func resolve(_ rawQuery: String) -> (mode: CommandPaletteMode, query: String) {
        if rawQuery.hasPrefix(">") {
            return (
                .actionsOnly,
                String(rawQuery.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        return (.unified, rawQuery.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func workspaceItems(
        snapshot: SessionSnapshot,
        query: String,
        homeDirectory: String
    ) -> [CommandPaletteItem] {
        var candidates: [(item: CommandPaletteItem, order: Int)] = []
        var order = 0
        for group in snapshot.groups {
            let groupName = ChromeText.sanitized(group.name, limit: 80)
            for workspace in group.workspaces where !workspace.isSoftClosed {
                defer { order += 1 }
                let title = SidebarWorkspaceTitle.resolve(workspace: workspace)
                let directory = workspace.layout.pane(id: workspace.focusedPaneID)?.workingDirectory ?? ""
                let location = FocusedPaneContext.displayPath(
                    directory, homeDirectory: homeDirectory
                )
                let subtitle = location.isEmpty ? groupName : "\(groupName) · \(location)"
                let score: Int
                if query.isEmpty {
                    score = 0
                } else {
                    let searchValues = [title, directory, location, groupName]
                        + workspace.layout.panes.flatMap { pane in
                            [pane.title, pane.workingDirectory, pane.agent ?? ""]
                        }
                    let scores = searchValues.compactMap {
                        SidebarFuzzyMatcher.match(query: query, in: $0)?.score
                    }
                    guard let best = scores.max() else { continue }
                    score = best
                }
                candidates.append((
                    CommandPaletteItem(
                        target: .workspace(workspace.id),
                        title: title,
                        subtitle: subtitle.isEmpty ? nil : subtitle,
                        score: score
                    ),
                    order
                ))
            }
        }
        if !query.isEmpty {
            candidates.sort {
                $0.item.score == $1.item.score
                    ? $0.order < $1.order
                    : $0.item.score > $1.item.score
            }
        }
        return candidates.prefix(workspaceLimit).map(\.item)
    }

    private static func rankedCommandItems(
        commands: [CommandDefinition],
        query: String,
        includeAllWhenEmpty: Bool
    ) -> [CommandPaletteItem] {
        var candidates: [(item: CommandPaletteItem, order: Int)] = []
        for (order, command) in commands.enumerated() {
            if query.isEmpty {
                guard includeAllWhenEmpty else { continue }
                candidates.append((commandItem(command), order))
                continue
            }
            guard let score = SidebarFuzzyMatcher.match(query: query, in: command.action)?.score
            else { continue }
            candidates.append((commandItem(command, score: score), order))
        }
        if !query.isEmpty {
            candidates.sort {
                $0.item.score == $1.item.score
                    ? $0.order < $1.order
                    : $0.item.score > $1.item.score
            }
        }
        return candidates.map(\.item)
    }

    private static func commandItem(
        _ command: CommandDefinition,
        score: Int = 0
    ) -> CommandPaletteItem {
        CommandPaletteItem(
            target: .command(command.id),
            title: ChromeText.sanitized(command.action, limit: 120),
            subtitle: command.section.rawValue,
            score: score
        )
    }
}
