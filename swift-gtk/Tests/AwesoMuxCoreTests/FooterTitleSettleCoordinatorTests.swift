import Foundation
import Testing
@testable import AwesoMuxCore

private final class InjectedFooterSettleScheduler: @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [(delay: Int, action: @Sendable () -> Void)] = []

    func schedule(delay: Int, action: @escaping @Sendable () -> Void) {
        lock.withLock { scheduled.append((delay, action)) }
    }

    var delays: [Int] { lock.withLock { scheduled.map(\.delay) } }

    func run(_ index: Int) {
        let action = lock.withLock { scheduled[index].action }
        action()
    }
}

private final class FooterSettleTestState: @unchecked Sendable {
    private let lock = NSLock()
    private var current: FooterTitleSettleRequest?
    private var refreshed: [FooterTitleSettleRequest] = []

    init(current: FooterTitleSettleRequest?) { self.current = current }

    func setCurrent(_ request: FooterTitleSettleRequest?) {
        lock.withLock { current = request }
    }

    func currentRequest() -> FooterTitleSettleRequest? {
        lock.withLock { current }
    }

    func record(_ request: FooterTitleSettleRequest) {
        lock.withLock { refreshed.append(request) }
    }

    var recorded: [FooterTitleSettleRequest] { lock.withLock { refreshed } }
}

@Test func footerTitleRefreshWaitsForFiveHundredMillisecondSettle() {
    let scheduler = InjectedFooterSettleScheduler()
    let coordinator = FooterTitleSettleCoordinator(scheduler: scheduler.schedule)
    let request = FooterTitleSettleRequest(
        workspaceID: UUID(), paneID: UUID(), surfaceGeneration: 1
    )
    let state = FooterSettleTestState(current: request)

    coordinator.schedule(
        request: request,
        currentRequest: state.currentRequest,
        refresh: state.record
    )
    scheduler.run(0)

    #expect(scheduler.delays == [500])
    #expect(state.recorded == [request])
}

@Test func footerTitleRefreshRunsOnlyForNewestLivePaneIdentity() {
    let scheduler = InjectedFooterSettleScheduler()
    let coordinator = FooterTitleSettleCoordinator(scheduler: scheduler.schedule)
    let first = FooterTitleSettleRequest(
        workspaceID: UUID(), paneID: UUID(), surfaceGeneration: 1
    )
    let second = FooterTitleSettleRequest(
        workspaceID: first.workspaceID, paneID: first.paneID, surfaceGeneration: 2
    )
    let state = FooterSettleTestState(current: first)

    coordinator.schedule(
        request: first,
        currentRequest: state.currentRequest,
        refresh: state.record
    )
    state.setCurrent(second)
    coordinator.schedule(
        request: second,
        currentRequest: state.currentRequest,
        refresh: state.record
    )
    scheduler.run(0)
    scheduler.run(1)
    #expect(state.recorded == [second])

    coordinator.schedule(
        request: second,
        currentRequest: state.currentRequest,
        refresh: state.record
    )
    coordinator.cancel()
    scheduler.run(2)
    #expect(state.recorded == [second])
}
