import Foundation

public enum SessionMutationError: Error, Equatable {
    case groupNotFound(UUID)
    case workspaceNotFound(UUID)
    case paneNotFound(UUID)
    case noSelectedWorkspace
    case invalidGroupName
    case duplicateGroupName
    case suspiciousGroupName
    case invalidWorkspaceName
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
    static var recentlyClosedWorkspaceTTL: TimeInterval { 24 * 60 * 60 }
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
        refreshAttentionStickyForSelection()
    }

    mutating func focusPane(_ paneID: UUID, in workspaceID: UUID) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            guard workspace.layout.paneIDs.contains(paneID) else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.focusedPaneID = paneID
        }
        if selectedWorkspaceID == workspaceID {
            refreshAttentionStickyForSelection()
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
        refreshAttentionStickyForSelection()
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
        refreshAttentionStickyForSelection()
    }

    mutating func addGroup(_ group: WorkspaceGroupSnapshot) {
        groups.append(group)
    }

    @discardableResult
    mutating func addGroup(named rawName: String, color: WorkspaceGroupColor? = nil) throws -> UUID {
        let name = try availableGroupName(rawName)
        let group = WorkspaceGroupSnapshot(name: name, color: color, workspaces: [])
        groups.append(group)
        return group.id
    }

    mutating func renameGroup(_ groupID: UUID, to rawName: String) throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        let name = try availableGroupName(rawName, excluding: groupID)
        groups[index].name = name
    }

    mutating func setGroupColor(_ groupID: UUID, color: WorkspaceGroupColor?) throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        groups[index].color = color
    }

    mutating func moveGroup(_ groupID: UUID, offset: Int) throws {
        guard let source = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        let target = min(max(source + offset, 0), groups.count - 1)
        guard target != source else { return }
        let group = groups.remove(at: source)
        groups.insert(group, at: target)
    }

    mutating func moveWorkspace(
        _ workspaceID: UUID,
        toGroup destinationGroupID: UUID,
        at targetIndex: Int
    ) throws {
        guard let destination = groups.firstIndex(where: { $0.id == destinationGroupID }) else {
            throw SessionMutationError.groupNotFound(destinationGroupID)
        }
        guard let sourceGroup = groups.firstIndex(where: { group in
            group.workspaces.contains(where: { $0.id == workspaceID })
        }), let sourceIndex = groups[sourceGroup].workspaces.firstIndex(where: { $0.id == workspaceID }) else {
            throw SessionMutationError.workspaceNotFound(workspaceID)
        }
        let destinationCount = sourceGroup == destination
            ? groups[destination].workspaces.count - 1
            : groups[destination].workspaces.count
        let insertion = min(max(targetIndex, 0), destinationCount)
        guard sourceGroup != destination || insertion != sourceIndex else { return }
        let workspace = groups[sourceGroup].workspaces.remove(at: sourceIndex)
        groups[destination].workspaces.insert(workspace, at: insertion)
    }

    mutating func renameWorkspace(_ workspaceID: UUID, to rawName: String) throws {
        let name = WorkspaceRenameDraft.sanitized(rawName)
        guard !name.isEmpty else { throw SessionMutationError.invalidWorkspaceName }
        try updateWorkspace(id: workspaceID) {
            $0.name = name
            $0.isNameUserEdited = true
        }
    }

    mutating func updatePanePresentation(
        paneID: UUID,
        workspaceID: UUID,
        title rawTitle: String? = nil,
        workingDirectory rawWorkingDirectory: String? = nil
    ) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            guard let updated = workspace.layout.replacingPane(id: paneID, with: { pane in
                var pane = pane
                if let rawTitle {
                    pane.title = ChromeText.sanitized(rawTitle, limit: 512)
                }
                if let rawWorkingDirectory {
                    let directory = ChromeText.sanitized(rawWorkingDirectory, limit: 4_096)
                    guard !directory.isEmpty else { return .pane(pane) }
                    pane.workingDirectory = directory
                }
                return .pane(pane)
            }) else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.layout = updated
        }
    }

    mutating func togglePinnedWorkspace(_ workspaceID: UUID) throws {
        guard workspaces.contains(where: { $0.id == workspaceID && !$0.isSoftClosed }) else {
            throw SessionMutationError.workspaceNotFound(workspaceID)
        }
        if let index = pinnedWorkspaceIDs.firstIndex(of: workspaceID) {
            pinnedWorkspaceIDs.remove(at: index)
        } else {
            pinnedWorkspaceIDs.append(workspaceID)
            if attentionStickyWorkspaceID == workspaceID {
                attentionStickyWorkspaceID = nil
            }
            attentionWorkspaceIDs.removeAll { $0 == workspaceID }
        }
        reconcileAttentionWorkspaceIDs()
    }

    mutating func movePinnedWorkspace(_ workspaceID: UUID, offset: Int) throws {
        guard let source = pinnedWorkspaceIDs.firstIndex(of: workspaceID) else {
            throw SessionMutationError.workspaceNotFound(workspaceID)
        }
        let target = min(max(source + offset, 0), pinnedWorkspaceIDs.count - 1)
        guard target != source else { return }
        pinnedWorkspaceIDs.remove(at: source)
        pinnedWorkspaceIDs.insert(workspaceID, at: target)
    }

    mutating func toggleWorkspaceNotificationsMuted(_ workspaceID: UUID) throws {
        try updateWorkspace(id: workspaceID) { $0.notificationsMuted.toggle() }
    }

    mutating func acknowledgeWorkspace(_ workspaceID: UUID) throws {
        guard let paneIDs = workspace(id: workspaceID)?.layout.paneIDs else {
            throw SessionMutationError.workspaceNotFound(workspaceID)
        }
        try updateWorkspace(id: workspaceID) { workspace in
            workspace.acknowledgedAttentionPaneIDs = workspace.layout.panes
                .filter { $0.agentState == .needsAttention }.map(\.id)
        }
        unansweredTurnPaneIDs.subtract(paneIDs)
        if attentionStickyWorkspaceID == workspaceID {
            attentionStickyWorkspaceID = nil
        }
        attentionWorkspaceIDs.removeAll { $0 == workspaceID }
    }

    @discardableResult
    mutating func acknowledgePane(
        _ paneID: UUID,
        in workspaceID: UUID,
        passively: Bool = false
    ) throws -> Bool {
        guard workspace(id: workspaceID)?.layout.pane(id: paneID) != nil else {
            throw SessionMutationError.paneNotFound(paneID)
        }
        if unansweredTurnPaneIDs.remove(paneID) != nil {
            reconcileAttentionWorkspaceIDs()
            return true
        }
        var didAcknowledge = false
        try updateWorkspace(id: workspaceID) { workspace in
            guard let pane = workspace.layout.pane(id: paneID), pane.agentState == .needsAttention else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            guard !passively || pane.attentionReason?.awaitsExplicitAnswer != true else { return }
            if !workspace.acknowledgedAttentionPaneIDs.contains(paneID) {
                workspace.acknowledgedAttentionPaneIDs.append(paneID)
                didAcknowledge = true
            }
        }
        reconcileAttentionWorkspaceIDs()
        return didAcknowledge
    }

    mutating func updatePaneAgentState(
        paneID: UUID,
        workspaceID: UUID,
        agent: String? = nil,
        state: AgentState,
        attentionReason: AttentionReason? = nil
    ) throws {
        let resolvedAttentionReason: AttentionReason? = state == .needsAttention
            ? (attentionReason ?? .unknown)
            : nil
        try updateWorkspace(id: workspaceID) { workspace in
            guard let previous = workspace.layout.pane(id: paneID),
                  let updated = workspace.layout.replacingPane(id: paneID, with: { pane in
                      var pane = pane
                      if let agent { pane.agent = ChromeText.sanitized(agent, limit: 80) }
                      pane.agentState = state
                      pane.attentionReason = resolvedAttentionReason
                      return .pane(pane)
                  })
            else { throw SessionMutationError.paneNotFound(paneID) }
            workspace.layout = updated
            if state == .needsAttention,
               previous.agentState != .needsAttention || previous.attentionReason != resolvedAttentionReason
            {
                workspace.acknowledgedAttentionPaneIDs.removeAll { $0 == paneID }
            }
        }
        reconcileAttentionWorkspaceIDs()
        if selectedWorkspaceID == workspaceID {
            refreshAttentionStickyForSelection()
        }
    }

    mutating func updatePaneAgentRuntime(
        paneID: UUID,
        workspaceID: UUID,
        update: AgentRuntimeUpdate
    ) throws {
        try updatePaneAgentState(
            paneID: paneID, workspaceID: workspaceID, agent: update.agent,
            state: update.state, attentionReason: update.attentionReason
        )
        if update.reportsUnansweredTurn {
            unansweredTurnPaneIDs.insert(paneID)
        } else if update.phase == .promptSubmit || update.phase == .sessionEnd {
            unansweredTurnPaneIDs.remove(paneID)
        }
        reconcileAttentionWorkspaceIDs()
    }

    mutating func refreshAttentionStickyForSelection() {
        let candidate = selectedWorkspaceID.flatMap { selected -> UUID? in
            guard !pinnedWorkspaceIDs.contains(selected),
                  let workspace = workspace(id: selected),
                  !workspace.isSoftClosed
            else { return nil }
            let acknowledged = Set(workspace.acknowledgedAttentionPaneIDs)
            return workspace.layout.panes.contains {
                $0.agentState == .needsAttention && !acknowledged.contains($0.id)
            } ? selected : nil
        }
        attentionStickyWorkspaceID = candidate
        reconcileAttentionWorkspaceIDs()
    }

    mutating func softCloseWorkspace(_ workspaceID: UUID, now: Date = Date()) throws {
        try updateWorkspace(id: workspaceID) { workspace in
            guard !workspace.isSoftClosed else { throw SessionMutationError.workspaceNotFound(workspaceID) }
            workspace.isSoftClosed = true
        }
        pinnedWorkspaceIDs.removeAll { $0 == workspaceID }
        attentionWorkspaceIDs.removeAll { $0 == workspaceID }
        if attentionStickyWorkspaceID == workspaceID { attentionStickyWorkspaceID = nil }
        pruneRecentlyClosedWorkspaces(now: now)
        recentlyClosedWorkspaces.removeAll { $0.workspaceID == workspaceID }
        recentlyClosedWorkspaces.insert(.init(workspaceID: workspaceID, closedAt: now), at: 0)
        if recentlyClosedWorkspaces.count > 20 { recentlyClosedWorkspaces.removeLast(recentlyClosedWorkspaces.count - 20) }
        if selectedWorkspaceID == workspaceID {
            selectedWorkspaceID = workspaces.first(where: { !$0.isSoftClosed })?.id
        }
    }

    @discardableResult
    mutating func reopenMostRecentlyClosedWorkspace(now: Date = Date()) throws -> UUID {
        pruneRecentlyClosedWorkspaces(now: now)
        guard let workspaceID = recentlyClosedWorkspaces.first?.workspaceID else {
            throw SessionMutationError.noSelectedWorkspace
        }
        try updateWorkspace(id: workspaceID) { workspace in
            guard workspace.isSoftClosed else { throw SessionMutationError.workspaceNotFound(workspaceID) }
            workspace.isSoftClosed = false
        }
        recentlyClosedWorkspaces.removeFirst()
        selectedWorkspaceID = workspaceID
        refreshAttentionStickyForSelection()
        return workspaceID
    }

    @discardableResult
    mutating func clearWorkspace(_ workspaceID: UUID) throws -> WorkspaceSnapshot {
        for groupIndex in groups.indices {
            guard let workspaceIndex = groups[groupIndex].workspaces.firstIndex(where: { $0.id == workspaceID }) else { continue }
            let removed = groups[groupIndex].workspaces.remove(at: workspaceIndex)
            pinnedWorkspaceIDs.removeAll { $0 == workspaceID }
            attentionWorkspaceIDs.removeAll { $0 == workspaceID }
            if attentionStickyWorkspaceID == workspaceID { attentionStickyWorkspaceID = nil }
            recentlyClosedWorkspaces.removeAll { $0.workspaceID == workspaceID }
            if selectedWorkspaceID == workspaceID {
                selectedWorkspaceID = workspaces.first(where: { !$0.isSoftClosed })?.id
            }
            return removed
        }
        throw SessionMutationError.workspaceNotFound(workspaceID)
    }

    mutating func reconcileAttentionWorkspaceIDs() {
        unansweredTurnPaneIDs.formIntersection(Set(workspaces.flatMap { $0.layout.paneIDs }))
        for groupIndex in groups.indices {
            for workspaceIndex in groups[groupIndex].workspaces.indices {
                let activeAttention = Set(groups[groupIndex].workspaces[workspaceIndex].layout.panes
                    .filter { $0.agentState == .needsAttention }.map(\.id))
                groups[groupIndex].workspaces[workspaceIndex].acknowledgedAttentionPaneIDs.removeAll {
                    !activeAttention.contains($0)
                }
            }
        }
        let sticky = attentionStickyWorkspaceID
        let eligible = workspaces.filter { workspace in
            let acknowledged = Set(workspace.acknowledgedAttentionPaneIDs)
            return !workspace.isSoftClosed && (workspace.id == sticky || workspace.layout.panes.contains {
                $0.agentState == .needsAttention && !acknowledged.contains($0.id)
            } || !unansweredTurnPaneIDs.isDisjoint(with: workspace.layout.paneIDs))
        }.map(\.id)
        let eligibleSet = Set(eligible)
        attentionWorkspaceIDs.removeAll {
            !eligibleSet.contains($0) || pinnedWorkspaceIDs.contains($0)
        }
        let existing = Set(attentionWorkspaceIDs)
        attentionWorkspaceIDs.append(contentsOf: eligible.filter {
            !existing.contains($0) && !pinnedWorkspaceIDs.contains($0)
        })
    }

    @discardableResult
    mutating func closeGroup(_ groupID: UUID) throws -> [UUID] {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        let removedWorkspaceIDs = groups[index].workspaces.map(\.id)
        groups.remove(at: index)
        let removedSet = Set(removedWorkspaceIDs)
        pinnedWorkspaceIDs.removeAll(where: removedSet.contains)
        attentionWorkspaceIDs.removeAll(where: removedSet.contains)
        recentlyClosedWorkspaces.removeAll { removedSet.contains($0.workspaceID) }
        if attentionStickyWorkspaceID.map(removedSet.contains) == true {
            attentionStickyWorkspaceID = nil
        }
        if let selectedWorkspaceID, removedWorkspaceIDs.contains(selectedWorkspaceID) {
            self.selectedWorkspaceID = groups.lazy
                .flatMap(\.workspaces)
                .first(where: { !$0.isSoftClosed })?.id
        }
        return removedWorkspaceIDs
    }

    mutating func toggleGroupDisclosure(_ groupID: UUID) throws {
        guard let index = groups.firstIndex(where: { $0.id == groupID }) else {
            throw SessionMutationError.groupNotFound(groupID)
        }
        groups[index].isCollapsed.toggle()
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
        var closedPaneID: UUID?
        let visibleCount = workspaces.filter { !$0.isSoftClosed }.count
        try updateWorkspace(id: workspaceID) { workspace in
            let paneIDs = workspace.layout.paneIDs
            decision = ClosePolicy.primaryClose(
                workspace: workspace,
                visibleWorkspaceCount: visibleCount
            )
            guard case let .closePane(paneID) = decision else { return }
            closedPaneID = paneID
            guard let updated = workspace.layout.removingPane(id: paneID) else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.layout = updated
            let remainingPaneIDs = paneIDs.filter { $0 != paneID }
            guard let closedIndex = paneIDs.firstIndex(of: paneID),
                  !remainingPaneIDs.isEmpty else {
                throw SessionMutationError.paneNotFound(paneID)
            }
            workspace.focusedPaneID = remainingPaneIDs[min(closedIndex, remainingPaneIDs.count - 1)]
            workspace.acknowledgedAttentionPaneIDs.removeAll { $0 == paneID }
        }
        if let closedPaneID { unansweredTurnPaneIDs.remove(closedPaneID) }
        reconcileAttentionWorkspaceIDs()
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

    @discardableResult
    mutating func pruneRecentlyClosedWorkspaces(now: Date = Date()) -> [WorkspaceSnapshot] {
        let cutoff = now.addingTimeInterval(-Self.recentlyClosedWorkspaceTTL)
        let expiredIDs = Set(recentlyClosedWorkspaces.filter { $0.closedAt < cutoff }.map(\.workspaceID))
        recentlyClosedWorkspaces.removeAll { expiredIDs.contains($0.workspaceID) }
        guard !expiredIDs.isEmpty else { return [] }
        var removed: [WorkspaceSnapshot] = []
        for groupIndex in groups.indices {
            let expired = groups[groupIndex].workspaces.filter { expiredIDs.contains($0.id) && $0.isSoftClosed }
            groups[groupIndex].workspaces.removeAll { expiredIDs.contains($0.id) && $0.isSoftClosed }
            removed.append(contentsOf: expired)
        }
        return removed
    }

    private func availableGroupName(_ rawName: String, excluding groupID: UUID? = nil) throws -> String {
        let draft = WorkspaceGroupNameDraft(
            typedName: rawName,
            existingGroupNames: groups.lazy.filter { $0.id != groupID }.map(\.name)
        )
        guard !draft.sanitizedName.isEmpty else { throw SessionMutationError.invalidGroupName }
        guard !draft.isMixedScript else { throw SessionMutationError.suspiciousGroupName }
        guard !draft.isDuplicate else { throw SessionMutationError.duplicateGroupName }
        return draft.sanitizedName
    }
}

private extension Int {
    func modulo(_ divisor: Int) -> Int {
        let remainder = self % divisor
        return remainder >= 0 ? remainder : remainder + divisor
    }
}
