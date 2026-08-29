public enum SidebarNavigationKey: Sendable {
    case previous
    case next
    case first
    case last
}

public enum SidebarKeyboardNavigationPolicy {
    public static func destination(current: Int?, count: Int, key: SidebarNavigationKey) -> Int? {
        guard count > 0 else { return nil }
        switch key {
        case .first: return 0
        case .last: return count - 1
        case .previous: return max(0, (current ?? 0) - 1)
        case .next: return min(count - 1, (current ?? -1) + 1)
        }
    }
}
