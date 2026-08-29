import Testing
@testable import AwesoMuxCore

@Test func primaryWindowActivationBuildsOnceThenPresentsTheExistingWindow() {
    #expect(
        PrimaryWindowActivationAction.resolve(hasPrimaryWindow: false)
            == .buildPrimaryWindow
    )
    #expect(
        PrimaryWindowActivationAction.resolve(hasPrimaryWindow: true)
            == .presentPrimaryWindow
    )
}
