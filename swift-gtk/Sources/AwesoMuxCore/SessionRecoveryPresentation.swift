public struct SessionRecoveryPresentation: Equatable, Sendable {
    public let title: String
    public let message: String

    public init(title: String, message: String) {
        self.title = title
        self.message = message
    }

    public static func resolve(_ outcome: SessionLoadOutcome) -> SessionRecoveryPresentation? {
        switch outcome {
        case .missing, .restored:
            nil
        case .recoveredPrevious:
            SessionRecoveryPresentation(
                title: "Couldn't reopen your last workspaces",
                message: "Saved workspaces could not be decoded; the original snapshot was archived"
            )
        case .resetAfterQuarantine:
            SessionRecoveryPresentation(
                title: "Couldn't reopen your last workspaces",
                message: "We found a problem with your saved session and set it aside safely. Create a workspace with Control-N to start fresh."
            )
        }
    }
}
