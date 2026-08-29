import Foundation
import Testing
@testable import AwesoMuxCore

private final class InjectedDwellScheduler: @unchecked Sendable {
    private let lock = NSLock()
    private var scheduled: [(delay: Int, action: @Sendable () -> Void)] = []

    func schedule(delay: Int, action: @escaping @Sendable () -> Void) {
        lock.withLock { scheduled.append((delay, action)) }
    }

    var delays: [Int] {
        lock.withLock { scheduled.map(\.delay) }
    }

    func run(_ index: Int) {
        let action = lock.withLock { scheduled[index].action }
        action()
    }
}

private final class DwellTestState: @unchecked Sendable {
    private let lock = NSLock()
    private var current: AttentionAcknowledgementDwellRequest?
    private var acknowledged: [AttentionAcknowledgementDwellRequest] = []

    init(current: AttentionAcknowledgementDwellRequest?) {
        self.current = current
    }

    func setCurrent(_ request: AttentionAcknowledgementDwellRequest?) {
        lock.withLock { current = request }
    }

    func currentRequest() -> AttentionAcknowledgementDwellRequest? {
        lock.withLock { current }
    }

    func record(_ request: AttentionAcknowledgementDwellRequest) {
        lock.withLock { acknowledged.append(request) }
    }

    var recorded: [AttentionAcknowledgementDwellRequest] {
        lock.withLock { acknowledged }
    }
}

@Test func attentionDwellUsesFiveHundredMillisecondsAndRejectsStaleSelections() {
    let scheduler = InjectedDwellScheduler()
    let coordinator = AttentionAcknowledgementDwellCoordinator(scheduler: scheduler.schedule)
    let first = AttentionAcknowledgementDwellRequest(workspaceID: UUID(), paneID: UUID())
    let second = AttentionAcknowledgementDwellRequest(workspaceID: UUID(), paneID: UUID())
    let state = DwellTestState(current: first)

    coordinator.schedule(
        request: first,
        currentRequest: state.currentRequest,
        acknowledge: state.record
    )
    state.setCurrent(second)
    scheduler.run(0)

    #expect(scheduler.delays == [500])
    #expect(state.recorded.isEmpty)
}

@Test func attentionDwellOnlyRunsTheNewestUninterruptedRequest() {
    let scheduler = InjectedDwellScheduler()
    let coordinator = AttentionAcknowledgementDwellCoordinator(scheduler: scheduler.schedule)
    let first = AttentionAcknowledgementDwellRequest(workspaceID: UUID(), paneID: UUID())
    let second = AttentionAcknowledgementDwellRequest(workspaceID: UUID(), paneID: UUID())
    let state = DwellTestState(current: first)

    coordinator.schedule(
        request: first,
        currentRequest: state.currentRequest,
        acknowledge: state.record
    )
    state.setCurrent(second)
    coordinator.schedule(
        request: second,
        currentRequest: state.currentRequest,
        acknowledge: state.record
    )
    scheduler.run(0)
    scheduler.run(1)

    #expect(scheduler.delays == [500, 500])
    #expect(state.recorded == [second])

    coordinator.schedule(
        request: second,
        currentRequest: state.currentRequest,
        acknowledge: state.record
    )
    coordinator.cancel()
    scheduler.run(2)
    #expect(state.recorded == [second])
}
