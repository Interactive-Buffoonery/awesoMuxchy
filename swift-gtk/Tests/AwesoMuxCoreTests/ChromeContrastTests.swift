import Testing
@testable import AwesoMuxCore

@Test func sidebarAndFooterChromeMeetsWCAGContrastRequirements() {
    for requirement in ChromeContrastAudit.requirements {
        #expect(
            requirement.passes,
            Comment(rawValue: "\(requirement.name): \(requirement.measuredRatio) < \(requirement.minimumRatio)")
        )
    }
}

@Test func contrastCalculationMatchesWCAGReferenceExtremes() {
    #expect(ChromeColor(hex: "000000").contrastRatio(with: ChromeColor(hex: "ffffff")) == 21)
    #expect(ChromeColor(hex: "777777").contrastRatio(with: ChromeColor(hex: "ffffff")) > 4.47)
    #expect(ChromeColor(hex: "777777").contrastRatio(with: ChromeColor(hex: "ffffff")) < 4.49)
}
