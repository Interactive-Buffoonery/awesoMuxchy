import Foundation

public struct AttentionAcknowledgementDwellRequest: Equatable, Sendable {
    public let workspaceID: UUID
    public let paneID: UUID

    public init(workspaceID: UUID, paneID: UUID) {
        self.workspaceID = workspaceID
        self.paneID = paneID
    }
}

/// Owns the cancellable 500 ms passive-read dwell without knowing about GTK.
/// The injected scheduler keeps timing deterministic in tests; the app supplies
/// its GTK-main scheduler and current selection/focus projection.
public final class AttentionAcknowledgementDwellCoordinator: @unchecked Sendable {
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
        request: AttentionAcknowledgementDwellRequest,
        currentRequest: @escaping @Sendable () -> AttentionAcknowledgementDwellRequest?,
        acknowledge: @escaping @Sendable (AttentionAcknowledgementDwellRequest) -> Void
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
            acknowledge(request)
        }
    }

    private func isCurrent(_ scheduledGeneration: UInt64) -> Bool {
        lock.withLock { generation == scheduledGeneration }
    }
}
