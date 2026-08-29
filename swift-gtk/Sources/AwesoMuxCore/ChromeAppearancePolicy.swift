import Foundation

public struct ChromeAppearance: Equatable, Sendable {
    public let theme: AppTheme
    public let isHighContrast: Bool
    public let reducesMotion: Bool

    public init(theme: AppTheme, isHighContrast: Bool, reducesMotion: Bool) {
        self.theme = theme
        self.isHighContrast = isHighContrast
        self.reducesMotion = reducesMotion
    }
}

public enum ChromeAppearancePolicy {
    public static func resolve(
        preference: AppTheme,
        gtkThemeName: String,
        themeOverride: String? = nil,
        prefersDark: Bool,
        animationsEnabled: Bool
    ) -> ChromeAppearance {
        let effectiveThemeName = themeOverride.flatMap { $0.isEmpty ? nil : $0 } ?? gtkThemeName
        let normalizedThemeName = effectiveThemeName.lowercased()
        let systemTheme: AppTheme = prefersDark || normalizedThemeName.contains("dark")
            || normalizedThemeName.contains("inverse") ? .dark : .light

        return ChromeAppearance(
            theme: preference == .system ? systemTheme : preference,
            isHighContrast: normalizedThemeName.contains("highcontrast")
                || normalizedThemeName.contains("high-contrast"),
            reducesMotion: !animationsEnabled
        )
    }
}

public enum SidebarStructuralMotionPolicy {
    public static let durationMilliseconds = 140

    public static func duration(
        reducesMotion: Bool,
        isFiltering: Bool,
        isInitialLayout: Bool
    ) -> Int {
        reducesMotion || isFiltering || isInitialLayout ? 0 : durationMilliseconds
    }
}
