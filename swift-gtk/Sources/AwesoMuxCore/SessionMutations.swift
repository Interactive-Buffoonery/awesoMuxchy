import Foundation

public enum SessionMutationError: Error, Equatable {
    case groupNotFound(UUID)
    case workspaceNotFound(UUID)
    case paneNotFound(UUID)
    case noSelectedWorkspace
}

public extension PaneLayout {
    func replacingPane(
        id: UUID,
        with replacement: (PaneSnapshot) -> PaneLayout
    ) -> PaneLayout? {
        switch self {
        case let .pane(pane):
            return pane.id == id ? replacement(pane) : nil
        case let .split(axis, fraction, first, second):
            if let updatedFirst = first.replacingPane(id: id, with: replacement) {
                return .split(
                    axis: axis,
                    fraction: fraction,
                    first: updatedFirst,
                    second: second
                )
            }
            if let updatedSecond = second.replacingPane(id: id, with: replacement) {
                return .split(
                    axis: axis,
                    fraction: fraction,
                    first: first,
                    second: updatedSecond
                )
            }
            return nil
        }
    }

    func removingPane(id: UUID) -> PaneLayout? {
        switch self {
        case let .pane(pane):
            return pane.id == id ? nil : self
        case let .split(axis, fraction, first, second):
            if first.paneIDs.contains(id) {
                guard let remainingFirst = first.removingPane(id: id) else { return second }
                return .split(
                    axis: axis,
                    fraction: fraction,
                    first: remainingFirst,
                    second: second
                )
            }
            if second.paneIDs.contains(id) {
                guard let remainingSecond = second.removingPane(id: id) else { return first }
                return .split(
                    axis: axis,
                    fraction: fraction,
                    first: first,
                    second: remainingSecond
                )
            }
            return self
        }
    }
}

public extension SessionSnapshot {
    var selectedWorkspace: WorkspaceSnapshot? {
        guard let selectedWorkspaceID else { return nil }
        return workspaces.first { $0.id == selectedWorkspaceID }
    }

    func workspace(id: UUID) -> WorkspaceSnapshot? {
        workspaces.first { $0.id == id }
    }

    mutating func selectWorkspace(_ workspaceID: UUID) throws {
        guard workspaces.contains(where: { $0.id == workspaceID && !$0.isSoftClosed }) else {
            throw SessionMutationError.workspaceNotFound(workspaceID)
        }
        selectedWorkspaceID = workspaceID
    }

    mutating func focusPane(_ paneID: UUID, in workspaceID: UUID) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            guard workspace.layout.paneIDs.contains(paneID) else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.focusedPaneID = paneID
        }
    }

    mutating func selectRelativeWorkspace(offset: Int) throws {
        let visible = workspaces.filter { !$0.isSoftClosed }
        guard !visible.isEmpty else { throw SessionMutationError.noSelectedWorkspace }
        let current = selectedWorkspaceID.flatMap { selected in
            visible.firstIndex { $0.id == selected }
        } ?? 0
        let target = (current + offset).modulo(visible.count)
        selectedWorkspaceID = visible[target].id
    }

    mutating func focusRelativePane(offset: Int, in workspaceID: UUID) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            let paneIDs = workspace.layout.paneIDs
            guard let current = paneIDs.firstIndex(of: workspace.focusedPaneID) else {
                throw SessionMutationError.paneNotFound(workspace.focusedPaneID)
            }
            workspace.focusedPaneID = paneIDs[(current + offset).modulo(paneIDs.count)]
        }
    }

    mutating func addWorkspace(
        _ workspace: WorkspaceSnapshot,
        toGroup groupID: UUID
    ) throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        groups[index].workspaces.append(workspace)
        selectedWorkspaceID = workspace.id
    }

    mutating func addGroup(_ group: WorkspaceGroupSnapshot) {
        groups.append(group)
    }

    mutating func moveWorkspace(_ workspaceID: UUID, offset: Int) throws {
        for groupIndex in groups.indices {
            guard let index = groups[groupIndex].workspaces.firstIndex(
                where: { $0.id == workspaceID }
            ) else { continue }
            let target = min(max(index + offset, 0), groups[groupIndex].workspaces.count - 1)
            guard target != index else { return }
            let workspace = groups[groupIndex].workspaces.remove(at: index)
            groups[groupIndex].workspaces.insert(workspace, at: target)
            return
        }
        throw SessionMutationError.workspaceNotFound(workspaceID)
    }

    mutating func splitFocusedPane(
        in workspaceID: UUID,
        axis: SplitAxis,
        newPane: PaneSnapshot
    ) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            let focusedID = workspace.focusedPaneID
            guard let updated = workspace.layout.replacingPane(
                id: focusedID,
                with: { existing in
                    .split(
                        axis: axis,
                        fraction: 0.5,
                        first: .pane(existing),
                        second: .pane(newPane)
                    )
                }
            ) else {
                throw SessionMutationError.paneNotFound(focusedID)
            }
            workspace.layout = updated
            workspace.focusedPaneID = newPane.id
        }
    }

    mutating func closeFocusedPane(in workspaceID: UUID) throws -> CloseDecision {
        var decision: CloseDecision?
        let visibleCount = workspaces.filter { !$0.isSoftClosed }.count
        try updateWorkspace(id: workspaceID) { workspace in
            decision = ClosePolicy.primaryClose(
                workspace: workspace,
                visibleWorkspaceCount: visibleCount
            )
            guard case let .closePane(paneID) = decision else { return }
            guard let updated = workspace.layout.removingPane(id: paneID) else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.layout = updated
            guard let nextFocus = updated.paneIDs.first else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.focusedPaneID = nextFocus
        }
        return decision ?? .closeWindow
    }

    private mutating func updateWorkspace(
        id workspaceID: UUID,
        mutation: (inout WorkspaceSnapshot) throws -> Void
    ) throws {
        for groupIndex in groups.indices {
            guard let workspaceIndex = groups[groupIndex].workspaces.firstIndex(
                where: { $0.id == workspaceID }
            ) else { continue }
            try mutation(&groups[groupIndex].workspaces[workspaceIndex])
            return
        }
        throw SessionMutationError.workspaceNotFound(workspaceID)
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
