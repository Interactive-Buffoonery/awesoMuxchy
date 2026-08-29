import Testing
@testable import AwesoMuxCore

@Test func sidebarKeyboardNavigationClampsAndHandlesMissingFocus() {
    #expect(SidebarKeyboardNavigationPolicy.destination(current: nil, count: 0, key: .next) == nil)
    #expect(SidebarKeyboardNavigationPolicy.destination(current: nil, count: 4, key: .next) == 0)
    #expect(SidebarKeyboardNavigationPolicy.destination(current: 0, count: 4, key: .previous) == 0)
    #expect(SidebarKeyboardNavigationPolicy.destination(current: 3, count: 4, key: .next) == 3)
    #expect(SidebarKeyboardNavigationPolicy.destination(current: 2, count: 4, key: .first) == 0)
    #expect(SidebarKeyboardNavigationPolicy.destination(current: 1, count: 4, key: .last) == 3)
}

@Test func emptySearchYieldsArrowNavigationToSidebarHierarchy() {
    #expect(!SidebarKeyboardNavigationPolicy.searchConsumesArrow(resultCount: 0))
    #expect(SidebarKeyboardNavigationPolicy.searchConsumesArrow(resultCount: 1))
}
