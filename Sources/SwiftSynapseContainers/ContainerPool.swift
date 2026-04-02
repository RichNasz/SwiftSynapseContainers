// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if ContainerPool

// MARK: - ContainerPool

/// Actor managing a pool of pre-warmed `ContainerManager` instances for parallel agent execution.
///
/// Pre-warming eliminates VM boot latency on hot paths. The pool boots `size` VMs at init,
/// keeps them warm, and hands them out to callers. Callers must `release(_:)` when done.
///
/// ```swift
/// let pool = ContainerPool(size: 4, config: .strict(image: "swift:latest"))
/// await pool.prewarm()
///
/// // In parallel:
/// async let r1 = pool.withContainer { manager in try await manager.run(goal: t1, execute: agent.execute) }
/// async let r2 = pool.withContainer { manager in try await manager.run(goal: t2, execute: agent.execute) }
/// let results = try await [r1, r2]
/// ```
public actor ContainerPool {
    // MARK: - State

    private let config: ContainerConfiguration
    private let maxSize: Int
    private var available: [ContainerManager] = []
    private var waiters: [CheckedContinuation<ContainerManager, Never>] = []

    // MARK: - Computed Properties

    /// The maximum number of containers this pool manages.
    public var capacity: Int { maxSize }

    /// The number of containers currently available for allocation.
    public var availableCount: Int { available.count }

    // MARK: - Init

    public init(size: Int, config: ContainerConfiguration) {
        self.maxSize = max(1, size)
        self.config = config
    }

    // MARK: - Pool Lifecycle

    /// Boots `capacity` VMs and adds them to the available pool.
    /// Call once after init, before any `allocate()` calls.
    public func prewarm() async {
        let needed = maxSize - available.count
        guard needed > 0 else { return }
        await withTaskGroup(of: ContainerManager?.self) { group in
            for _ in 0..<needed {
                group.addTask {
                    ContainerManager(config: self.config)
                }
            }
            for await manager in group {
                if let manager {
                    self.available.append(manager)
                }
            }
        }
    }

    // MARK: - Allocation

    /// Allocates a `ContainerManager` from the pool.
    /// If the pool is empty, suspends the caller until one is released.
    public func allocate() async -> ContainerManager {
        if let manager = available.popLast() {
            return manager
        }
        return await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Returns nil if a manager is immediately available, nil otherwise (non-blocking).
    public func tryAllocate() -> ContainerManager? {
        available.isEmpty ? nil : available.removeLast()
    }

    /// Returns a `ContainerManager` to the pool after use.
    public func release(_ manager: ContainerManager) {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume(returning: manager)
        } else {
            available.append(manager)
        }
    }

    // MARK: - Scoped Allocation

    /// Allocates a container, runs `body`, and releases it — even if `body` throws.
    public func withContainer<T: Sendable>(
        _ body: @Sendable (ContainerManager) async throws -> T
    ) async throws -> T {
        let manager = await allocate()
        defer { Task { self.release(manager) } }
        return try await body(manager)
    }
}

#endif
