import Dispatch

public enum SessionPersistenceWriteOutcome: Equatable, Sendable {
    case saved
    case failed
}

/// Serializes snapshot writes away from the UI thread and collapses mutation
/// bursts into one trailing-edge save. `flush` invalidates any delayed write
/// and synchronously commits the caller's latest value at a lifecycle boundary.
public final class SessionPersistenceCoordinator: @unchecked Sendable {
    public static let debounceNanoseconds: UInt64 = 500_000_000

    private let store: SessionStore
    private let delay: DispatchTimeInterval
    private let queue: DispatchQueue
    private let outcomeHandler: @Sendable (SessionPersistenceWriteOutcome) -> Void
    private var pendingSnapshot: SessionSnapshot?
    private var generation: UInt64 = 0

    public init(
        store: SessionStore,
        debounceNanoseconds: UInt64 = SessionPersistenceCoordinator.debounceNanoseconds,
        outcomeHandler: @escaping @Sendable (SessionPersistenceWriteOutcome) -> Void = { _ in }
    ) {
        self.store = store
        delay = .nanoseconds(Int(min(debounceNanoseconds, UInt64(Int.max))))
        queue = DispatchQueue(label: "com.awesomux.session-persistence", qos: .utility)
        self.outcomeHandler = outcomeHandler
    }

    public func schedule(_ snapshot: SessionSnapshot) {
        queue.async { [self] in
            pendingSnapshot = snapshot
            generation &+= 1
            let scheduledGeneration = generation
            queue.asyncAfter(deadline: .now() + delay) { [self] in
                guard generation == scheduledGeneration else { return }
                writePending(notify: true)
            }
        }
    }

    @discardableResult
    public func flush(_ latestSnapshot: SessionSnapshot? = nil) -> SessionPersistenceWriteOutcome {
        queue.sync { [self] in
            if let latestSnapshot { pendingSnapshot = latestSnapshot }
            generation &+= 1
            return writePending(notify: false)
        }
    }

    @discardableResult
    private func writePending(notify: Bool) -> SessionPersistenceWriteOutcome {
        guard let snapshot = pendingSnapshot else { return .saved }
        do {
            try store.save(snapshot)
            pendingSnapshot = nil
            if notify { outcomeHandler(.saved) }
            return .saved
        } catch {
            if notify { outcomeHandler(.failed) }
            return .failed
        }
    }
}
