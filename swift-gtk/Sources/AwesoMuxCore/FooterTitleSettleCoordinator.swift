import Foundation

public struct FooterTitleSettleRequest: Equatable, Sendable {
    public let workspaceID: UUID
    public let paneID: UUID
    public let surfaceGeneration: Int

    public init(workspaceID: UUID, paneID: UUID, surfaceGeneration: Int) {
        self.workspaceID = workspaceID
        self.paneID = paneID
        self.surfaceGeneration = surfaceGeneration
    }
}

/// Coalesces title-only footer refreshes without knowing about GTK.
///
/// Prompt and agent TUIs can publish titles many times per second. The title is
/// still a useful signal for an in-place branch change whose cwd did not move,
/// so the app refreshes repository context after the title settles instead of
/// walking the repository for every publication. The injected scheduler keeps
/// the timing and stale-identity behavior deterministic in tests.
public final class FooterTitleSettleCoordinator: @unchecked Sendable {
    public static let delayMilliseconds = 500

    public typealias Scheduler = @Sendable (
        _ delayMilliseconds: Int,
        _ action: @escaping @Sendable () -> Void
    ) -> Void

    private let lock = NSLock()
    private let scheduler: Scheduler
    private var generation: UInt64 = 0

    public init(scheduler: @escaping Scheduler) {
        self.scheduler = scheduler
    }

    public func cancel() {
        lock.withLock { generation &+= 1 }
    }

    public func schedule(
        request: FooterTitleSettleRequest,
        currentRequest: @escaping @Sendable () -> FooterTitleSettleRequest?,
        refresh: @escaping @Sendable (FooterTitleSettleRequest) -> Void
    ) {
        let scheduledGeneration = lock.withLock {
            generation &+= 1
            return generation
        }
        scheduler(Self.delayMilliseconds) { [weak self] in
            guard let self,
                  self.isCurrent(scheduledGeneration),
                  currentRequest() == request
            else { return }
            refresh(request)
        }
    }

    private func isCurrent(_ scheduledGeneration: UInt64) -> Bool {
        lock.withLock { generation == scheduledGeneration }
    }
}
