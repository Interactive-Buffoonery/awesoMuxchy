public enum PrimaryWindowActivationAction: Equatable, Sendable {
    case buildPrimaryWindow
    case presentPrimaryWindow

    public static func resolve(hasPrimaryWindow: Bool) -> Self {
        hasPrimaryWindow ? .presentPrimaryWindow : .buildPrimaryWindow
    }
}
