public enum CommandID: String, CaseIterable, Codable, Sendable {
    case newWorkspace
    case newWorkspaceInCurrentDirectory
    case newWorkspaceGroup
    case closePane
    case closeWorkspace
    case reopenClosedWorkspace
    case splitRight
    case splitDown
    case previousWorkspace
    case nextWorkspace
    case previousPane
    case nextPane
    case commandPalette
    case keyboardShortcuts
    case toggleSidebarWidth
    case toggleSidebarVisibility
}

public enum ShortcutModifier: String, Codable, CaseIterable, Hashable, Sendable {
    case control
    case alt
    case shift
    case superKey
}

public struct KeyChord: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var modifiers: Set<ShortcutModifier>

    public init(key: String, modifiers: Set<ShortcutModifier>) {
        self.key = key
        self.modifiers = modifiers
    }
}

public enum CommandSection: String, Codable, Sendable {
    case file = "File"
    case view = "View"
    case workspace = "Workspace"
    case pane = "Pane"
}

public struct CommandDefinition: Codable, Equatable, Identifiable, Sendable {
    public var id: CommandID
    public var action: String
    public var section: CommandSection
    public var defaultChord: KeyChord?

    public init(
        id: CommandID,
        action: String,
        section: CommandSection,
        defaultChord: KeyChord?
    ) {
        self.id = id
        self.action = action
        self.section = section
        self.defaultChord = defaultChord
    }
}

public enum CommandCatalog {
    private static func chord(
        _ key: String,
        _ modifiers: ShortcutModifier...
    ) -> KeyChord {
        KeyChord(key: key, modifiers: Set(modifiers))
    }

    /// Linux maps the macOS Command layer to Control and Option to Alt.
    /// macOS Control chords use Super in addition to Control so they remain
    /// distinct without creating a second terminal-owned command surface.
    public static let definitions: [CommandDefinition] = [
        .init(id: .newWorkspace, action: "New Workspace", section: .file,
              defaultChord: chord("n", .control)),
        .init(id: .newWorkspaceInCurrentDirectory,
              action: "New Workspace in Current Directory", section: .workspace,
              defaultChord: chord("n", .control, .alt)),
        .init(id: .newWorkspaceGroup, action: "New Workspace Group…", section: .workspace,
              defaultChord: chord("n", .control, .superKey)),
        .init(id: .closePane, action: "Close Pane", section: .pane,
              defaultChord: chord("w", .control)),
        .init(id: .closeWorkspace, action: "Close Workspace", section: .workspace,
              defaultChord: chord("w", .control, .shift)),
        .init(id: .reopenClosedWorkspace, action: "Reopen Closed Workspace", section: .workspace,
              defaultChord: chord("t", .control, .shift)),
        .init(id: .splitRight, action: "Split Right", section: .pane,
              defaultChord: chord("d", .control)),
        .init(id: .splitDown, action: "Split Down", section: .pane,
              defaultChord: chord("d", .control, .shift)),
        .init(id: .previousWorkspace, action: "Previous Workspace", section: .workspace,
              defaultChord: chord("[", .control, .shift)),
        .init(id: .nextWorkspace, action: "Next Workspace", section: .workspace,
              defaultChord: chord("]", .control, .shift)),
        .init(id: .previousPane, action: "Previous Pane", section: .pane,
              defaultChord: chord("[", .control, .alt)),
        .init(id: .nextPane, action: "Next Pane", section: .pane,
              defaultChord: chord("]", .control, .alt)),
        .init(id: .commandPalette, action: "Command Palette", section: .view,
              defaultChord: chord("k", .control)),
        .init(id: .keyboardShortcuts, action: "Keyboard Shortcuts", section: .view,
              defaultChord: chord("/", .control)),
        .init(id: .toggleSidebarWidth, action: "Collapse/Expand Sidebar", section: .view,
              defaultChord: chord("\\", .control)),
        .init(id: .toggleSidebarVisibility, action: "Hide/Show Sidebar", section: .view,
              defaultChord: chord("\\", .control, .shift)),
    ]

    public static func definition(for id: CommandID) -> CommandDefinition {
        definitions.first { $0.id == id }!
    }
}
