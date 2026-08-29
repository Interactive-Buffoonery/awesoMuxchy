import Testing
@testable import AwesoMuxCore

@Test func sidebarDensityUsesThePinnedReferenceSpacing() {
    #expect(
        SidebarDensity.standard.layout
            == SidebarDensityLayout(
                groupStackSpacing: 14,
                groupHeaderBottomPadding: 3,
                sessionStackSpacing: 5
            )
    )
    #expect(
        SidebarDensity.compact.layout
            == SidebarDensityLayout(
                groupStackSpacing: 8,
                groupHeaderBottomPadding: 1,
                sessionStackSpacing: 3
            )
    )
}
