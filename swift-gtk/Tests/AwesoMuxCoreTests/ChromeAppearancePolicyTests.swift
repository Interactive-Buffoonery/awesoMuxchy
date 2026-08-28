import Testing
@testable import AwesoMuxCore

@Test func systemAppearanceFollowsGTKTheme() {
    #expect(ChromeAppearancePolicy.resolve(
        preference: .system,
        gtkThemeName: "Adwaita-dark",
        prefersDark: false,
        animationsEnabled: true
    ) == ChromeAppearance(theme: .dark, isHighContrast: false, reducesMotion: false))
}

@Test func explicitThemeWinsWithoutDiscardingAccessibilityPreferences() {
    #expect(ChromeAppearancePolicy.resolve(
        preference: .light,
        gtkThemeName: "Adwaita",
        themeOverride: "HighContrastInverse",
        prefersDark: false,
        animationsEnabled: false
    ) == ChromeAppearance(theme: .light, isHighContrast: true, reducesMotion: true))
}

@Test func highContrastThemeOverrideDrivesSystemDarkMode() {
    #expect(ChromeAppearancePolicy.resolve(
        preference: .system,
        gtkThemeName: "Adwaita",
        themeOverride: "HighContrastInverse",
        prefersDark: false,
        animationsEnabled: true
    ) == ChromeAppearance(theme: .dark, isHighContrast: true, reducesMotion: false))
}
