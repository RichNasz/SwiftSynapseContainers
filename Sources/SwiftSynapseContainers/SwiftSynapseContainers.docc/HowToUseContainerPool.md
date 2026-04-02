# How to Use ContainerPool

Pre-warm a pool of MicroVMs for near-instant parallel agent execution.

## Overview

``ContainerPool`` eliminates VM boot latency on hot paths. Instead of booting a fresh VM per request, the pool keeps `N` pre-warmed VMs ready for immediate allocation. This is essential for multi-agent crews, sub-agent spawning, and any workload where parallel container execution matters.

Requires the `ContainerPool` trait — included in the default `SecureProduction` bundle.

## Basic Pool Setup

```swift
// Create a pool of 4 pre-warmed containers
let pool = ContainerPool(size: 4, config: .strict(image: "swift:latest"))

// Boot all VMs in parallel — call once at app startup
await pool.prewarm()
```

Pre-warming boots all `size` VMs concurrently. Call it once, early in your app lifecycle, so VMs are ready before the first request arrives.

## Allocating and Releasing

Use ``ContainerPool/withContainer(_:)`` for automatic release — even if the body throws:

```swift
let result = try await pool.withContainer { manager in
    try await manager.run(goal: goal) { goal in
        try await myAgent.execute(goal: goal)
    }
}
```

For manual control:

```swift
let manager = await pool.allocate()
defer { Task { await pool.release(manager) } }

let result = try await manager.run(goal: goal) { goal in
    try await myAgent.execute(goal: goal)
}
```

If the pool is empty when `allocate()` is called, the caller suspends until another caller releases a manager. Use ``ContainerPool/tryAllocate()`` for non-blocking allocation that returns `nil` when the pool is empty.

## Parallel Multi-Agent Execution

``ContainerPool`` is designed for structured concurrency. Allocate multiple containers concurrently with `async let` or a `TaskGroup`:

```swift
// Three agents in three isolated VMs, concurrently:
async let r1 = pool.withContainer { m in try await m.run(goal: task1, execute: agent1.execute) }
async let r2 = pool.withContainer { m in try await m.run(goal: task2, execute: agent2.execute) }
async let r3 = pool.withContainer { m in try await m.run(goal: task3, execute: agent3.execute) }
let results = try await [r1, r2, r3]
```

With a `TaskGroup` for dynamic concurrency:

```swift
let tasks: [String] = loadTasks()
var outputs: [ContainerizedResult<String>] = []

try await withThrowingTaskGroup(of: ContainerizedResult<String>.self) { group in
    for task in tasks {
        group.addTask {
            try await pool.withContainer { manager in
                try await manager.run(goal: task) { goal in
                    try await myAgent.execute(goal: goal)
                }
            }
        }
    }
    for try await result in group {
        outputs.append(result)
    }
}
```

## Sizing the Pool

| Scenario | Recommended pool size |
|----------|----------------------|
| Single agent, occasional use | 1 (no pool needed — use `ContainerManager` directly) |
| Single agent, frequent requests | 2–3 |
| Multi-agent crew, fixed parallelism N | N |
| Dynamic sub-agent spawning | max expected concurrent sub-agents |

Check `await pool.availableCount` at runtime to observe pool utilization.

## Checking Pool Capacity

```swift
let total     = await pool.capacity        // always equals the size passed to init
let available = await pool.availableCount  // currently idle VMs
let inUse     = total - available
```

## Important Notes

- **Pre-warm before serving requests.** `allocate()` on an unwarmed pool will suspend indefinitely if the pool has no managers (``ContainerPool/tryAllocate()`` returns `nil` instead of suspending).
- **Pools are actor-isolated.** All `allocate()`, `release()`, and `withContainer(_:)` calls are safe to call concurrently from any number of tasks.
- **Release on cancellation.** `withContainer(_:)` uses `defer` to release the manager even when the task is cancelled. For manual `allocate()` calls, use `defer { Task { await pool.release(manager) } }`.
