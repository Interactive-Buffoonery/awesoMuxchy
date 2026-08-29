public enum CommandID: String, CaseIterable, Codable, Sendable {
    case newWorkspace
    case newWorkspaceInCurrentDirectory
    case newWorkspaceGroup
    case renameWorkspace
    case acknowledgeWorkspace
    case togglePinWorkspace
    case closePane
    case closeWorkspace
    case clearWorkspace
    case reopenClosedWorkspace
    case splitRight
    case splitDown
    case growActivePane
    case shrinkActivePane
    case previousWorkspace
    case nextWorkspace
    case jumpWorkspace1
    case jumpWorkspace2
    case jumpWorkspace3
    case jumpWorkspace4
    case jumpWorkspace5
    case jumpWorkspace6
    case jumpWorkspace7
    case jumpWorkspace8
    case jumpWorkspace9
    case previousPane
    case nextPane
    case commandPalette
    case keyboardShortcuts
    case focusSidebar
    case toggleSidebarWidth
    case toggleSidebarVisibility

    public var workspaceJumpIndex: Int? {
        switch self {
        case .jumpWorkspace1: 0
        case .jumpWorkspace2: 1
        case .jumpWorkspace3: 2
        case .jumpWorkspace4: 3
        case .jumpWorkspace5: 4
        case .jumpWorkspace6: 5
        case .jumpWorkspace7: 6
        case .jumpWorkspace8: 7
        case .jumpWorkspace9: 8
        default: nil
        }
    }
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
        .init(id: .renameWorkspace, action: "Rename Workspace", section: .workspace,
              defaultChord: chord("r", .control, .shift)),
        .init(id: .acknowledgeWorkspace, action: "Acknowledge Workspace", section: .workspace,
              defaultChord: chord("k", .control, .shift)),
        .init(id: .togglePinWorkspace, action: "Pin or Unpin Workspace", section: .workspace,
              defaultChord: chord("p", .control, .alt)),
        .init(id: .closePane, action: "Close Pane", section: .pane,
              defaultChord: chord("w", .control)),
        .init(id: .closeWorkspace, action: "Close Workspace", section: .workspace,
              defaultChord: chord("w", .control, .shift)),
        .init(id: .clearWorkspace, action: "Clear Workspace", section: .workspace,
              defaultChord: chord("w", .control, .shift, .alt)),
        .init(id: .reopenClosedWorkspace, action: "Reopen Closed Workspace", section: .workspace,
              defaultChord: chord("t", .control, .shift)),
        .init(id: .splitRight, action: "Split Right", section: .pane,
              defaultChord: chord("d", .control)),
        .init(id: .splitDown, action: "Split Down", section: .pane,
              defaultChord: chord("d", .control, .shift)),
        .init(id: .growActivePane, action: "Grow Active Pane", section: .pane,
              defaultChord: chord("=", .control, .alt)),
        .init(id: .shrinkActivePane, action: "Shrink Active Pane", section: .pane,
              defaultChord: chord("-", .control, .alt)),
        .init(id: .previousWorkspace, action: "Previous Workspace", section: .workspace,
              defaultChord: chord("[", .control, .shift)),
        .init(id: .nextWorkspace, action: "Next Workspace", section: .workspace,
              defaultChord: chord("]", .control, .shift)),
        .init(id: .jumpWorkspace1, action: "Jump to Workspace 1", section: .workspace,
              defaultChord: chord("1", .control)),
        .init(id: .jumpWorkspace2, action: "Jump to Workspace 2", section: .workspace,
              defaultChord: chord("2", .control)),
        .init(id: .jumpWorkspace3, action: "Jump to Workspace 3", section: .workspace,
              defaultChord: chord("3", .control)),
        .init(id: .jumpWorkspace4, action: "Jump to Workspace 4", section: .workspace,
              defaultChord: chord("4", .control)),
        .init(id: .jumpWorkspace5, action: "Jump to Workspace 5", section: .workspace,
              defaultChord: chord("5", .control)),
        .init(id: .jumpWorkspace6, action: "Jump to Workspace 6", section: .workspace,
              defaultChord: chord("6", .control)),
        .init(id: .jumpWorkspace7, action: "Jump to Workspace 7", section: .workspace,
              defaultChord: chord("7", .control)),
        .init(id: .jumpWorkspace8, action: "Jump to Workspace 8", section: .workspace,
              defaultChord: chord("8", .control)),
        .init(id: .jumpWorkspace9, action: "Jump to Workspace 9", section: .workspace,
              defaultChord: chord("9", .control)),
        .init(id: .previousPane, action: "Previous Pane", section: .pane,
              defaultChord: chord("[", .control, .alt)),
        .init(id: .nextPane, action: "Next Pane", section: .pane,
              defaultChord: chord("]", .control, .alt)),
        .init(id: .commandPalette, action: "Command Palette", section: .view,
              defaultChord: chord("k", .control)),
        .init(id: .keyboardShortcuts, action: "Keyboard Shortcuts", section: .view,
              defaultChord: chord("/", .control)),
        .init(id: .focusSidebar, action: "Focus Sidebar", section: .view,
              defaultChord: chord("s", .control, .superKey)),
        .init(id: .toggleSidebarWidth, action: "Collapse/Expand Sidebar", section: .view,
              defaultChord: chord("\\", .control)),
        .init(id: .toggleSidebarVisibility, action: "Hide/Show Sidebar", section: .view,
              defaultChord: chord("\\", .control, .shift)),
    ]

    public static func definition(for id: CommandID) -> CommandDefinition {
        definitions.first { $0.id == id }!
    }
}
