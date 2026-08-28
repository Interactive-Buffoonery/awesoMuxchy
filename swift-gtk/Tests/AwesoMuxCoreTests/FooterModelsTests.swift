import Foundation
import Testing
@testable import AwesoMuxCore

@Test func agentFooterSummarizesOnlyDeclaredAgentsAndPrioritizesAttention() {
    let thinking = PaneSnapshot(title: "Plan", workingDirectory: "/tmp", agent: "Codex", agentState: .thinking)
    let attention = PaneSnapshot(title: "Fix", workingDirectory: "/tmp", agent: "Claude", agentState: .needsAttention)
    let shell = PaneSnapshot(title: "Shell", workingDirectory: "/tmp")
    let layout = PaneLayout.split(axis: .horizontal, fraction: 0.5,
        first: .pane(thinking), second: .split(axis: .vertical, fraction: 0.5, first: .pane(shell), second: .pane(attention)))
    let workspace = WorkspaceSnapshot(name: "Development", focusedPaneID: thinking.id, layout: layout)
    let summary = AgentFooterSummary(snapshot: SessionSnapshot(selectedWorkspaceID: workspace.id,
        groups: [WorkspaceGroupSnapshot(name: "Local", workspaces: [workspace])]))

    #expect(summary.totalCount == 2)
    #expect(summary.thinkingCount == 1)
    #expect(summary.needsAttentionCount == 1)
    #expect(summary.rows.first?.paneID == attention.id)
}

@Test func porcelainStatusCountsEntriesAndAheadBehind() {
    let data = Data("""
    # branch.oid 012345
    # branch.head main
    # branch.ab +12 -3
    1 .M N... 100644 100644 100644 abc abc Sources/App.swift
    ? New File.swift
    """.utf8)
    let status = GitWorkingCopyStatus(porcelainV2: data)
    #expect(status.dirtyCount == 2)
    #expect(status.ahead == 12)
    #expect(status.behind == 3)
    #expect(status.reportedBranch == "main")
}

@Test func pullRequestRequiresOpenHTTPSPayload() {
    let open = Data(#"{"number":42,"url":"https://github.com/acme/repo/pull/42","state":"OPEN","isDraft":false,"reviewDecision":"REVIEW_REQUIRED"}"#.utf8)
    let unsafe = Data(#"{"number":42,"url":"file:///tmp/trap","state":"OPEN","isDraft":false,"reviewDecision":""}"#.utf8)
    let closed = Data(#"{"number":42,"url":"https://github.com/acme/repo/pull/42","state":"CLOSED","isDraft":false,"reviewDecision":""}"#.utf8)
    #expect(PullRequestStatus(ghJSON: open)?.state == .inReview)
    #expect(PullRequestStatus(ghJSON: unsafe) == nil)
    #expect(PullRequestStatus(ghJSON: closed) == nil)
}

@Test func ciOnlyRepresentsRunningOrFailingAndPinsValidGithubSlug() {
    let failing = Data(#"[{"databaseId":987,"status":"completed","conclusion":"failure","url":"https://github.com/acme/repo/actions/runs/987","workflowName":"Swift CI"}]"#.utf8)
    let passing = Data(#"[{"databaseId":987,"status":"completed","conclusion":"success","url":"https://github.com/acme/repo/actions/runs/987","workflowName":"Swift CI"}]"#.utf8)
    let value = CIStatus(ghJSON: failing)
    #expect(value?.state == .failing)
    #expect(value?.repoSlug == "acme/repo")
    #expect(CIStatus(ghJSON: passing) == nil)
}

@Test func branchesRejectOptionLookingNamesAndCommandsQuoteShellMetacharacters() {
    let tooLong = String(repeating: "x", count: 121)
    let branches = TerminalFooterResolver.parseBranches(Data("main\n-feature\nfix/one\nfix/one\n\(tooLong)\n".utf8))
    #expect(branches == ["main", "fix/one"])
    #expect(TerminalFooterResolver.shellQuoted("Sarah's fix") == "'Sarah'\\''s fix'")
}

@Test func editorDiscoveryUsesExecutablePathEntriesOnly() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let code = root.appendingPathComponent("code")
    _ = FileManager.default.createFile(atPath: code.path, contents: Data())
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: code.path)
    #expect(TerminalFooterResolver.installedEditors(path: root.path) == [InstalledEditor(name: "Visual Studio Code", executable: code.path)])
    #expect(TerminalFooterResolver.installedEditors(path: ".") == [])
}

@Test func quickSettingsRoundTripWithOwnerOnlyPermissions() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let store = AppPreferencesStore(url: root.appendingPathComponent("preferences.json"))
    let expected = AppPreferences(theme: .light, notificationsMuted: true)
    try store.save(expected)
    #expect(store.load() == expected)
    let attributes = try FileManager.default.attributesOfItem(atPath: store.url.path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func boundedRunnerCapturesSuccessfulCommandOutput() {
    let data = BoundedCommandRunner().run(executable: "/usr/bin/git", arguments: ["--version"], directory: "/tmp")
    #expect(data.map { String(decoding: $0, as: UTF8.self).hasPrefix("git version ") } == true)
}

@Test func footerResolverFindsRepositoryFromNestedWorkingDirectory() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let nested = root.appendingPathComponent("Sources/App", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
    let runner = BoundedCommandRunner()
    #expect(runner.run(executable: "/usr/bin/git", arguments: ["init", "-b", "footer-fixture"], directory: root.path) != nil)
    let identity = FocusedPaneIdentity(workspaceID: UUID(), paneID: UUID(), generation: 1)
    let context = FocusedPaneContext.resolve(identity: identity, workingDirectory: nested.path)
    let details = TerminalFooterResolver(runner: runner).resolve(context)
    #expect(details.repoRoot == root.path)
    #expect(details.branch == "footer-fixture")
    #expect(details.pathPresentation.project == root.lastPathComponent)
    #expect(details.pathPresentation.path == "Sources/App")
}

@Test func footerPathPresentationUsesRepoRootCopyAndRejectsUnrelatedRoots() {
    let identity = FocusedPaneIdentity(workspaceID: UUID(), paneID: UUID(), generation: 1)
    let rootContext = FocusedPaneContext.resolve(identity: identity, workingDirectory: "/work/awesomux")
    let root = FooterPathPresentation(context: rootContext, repoRoot: "/work/awesomux")
    #expect(root.project == "awesomux")
    #expect(root.path == "repo root")

    let unrelated = FooterPathPresentation(context: rootContext, repoRoot: "/other/repo")
    #expect(unrelated.project == rootContext.project)
    #expect(unrelated.path == rootContext.path)
}
