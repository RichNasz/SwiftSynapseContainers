// Generated from CodeGenSpecs/ContainerPoolTests.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Testing
@testable import SwiftSynapseContainers

// MARK: - ContainerPool Tests

@Test func containerPoolCreationWithValidSize() {
    let _ = ContainerPool(size: 2, config: .strict(image: "swift:latest"))
}

@Test func containerPoolSizeIsRespected() async {
    let pool = ContainerPool(size: 3, config: .strict(image: "swift:latest"))
    let capacity = await pool.capacity
    #expect(capacity == 3)
}

@Test func containerPoolClampsMinimumSizeToOne() async {
    let pool = ContainerPool(size: 0, config: .strict(image: "swift:latest"))
    let capacity = await pool.capacity
    #expect(capacity >= 1)
}

@Test func containerPoolTryAllocateReturnsNilBeforePrewarm() async {
    let pool = ContainerPool(size: 2, config: .strict(image: "swift:latest"))
    // Pool is empty before prewarm() is called
    let manager = await pool.tryAllocate()
    #expect(manager == nil)
}

@Test func containerPoolReleaseDoesNotThrow() async throws {
    let pool = ContainerPool(size: 1, config: .strict(image: "swift:latest"))
    let manager = ContainerManager(config: .strict(image: "swift:latest"))
    // Releasing to an empty pool adds it to available
    await pool.release(manager)
    let available = await pool.availableCount
    #expect(available == 1)
}

@Test func containerPoolWithContainerScopedAllocation() async throws {
    let pool = ContainerPool(size: 1, config: .strict(image: "swift:latest"))
    let manager = ContainerManager(config: .strict(image: "swift:latest"))
    await pool.release(manager)  // seed pool with one manager

    let result = try await pool.withContainer { _ in
        return "scoped"
    }
    #expect(result == "scoped")

    // After withContainer, manager should be back in pool
    let available = await pool.availableCount
    #expect(available == 1)
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerPoolAllocatesAndReleasesVMs() async throws {
    let pool = ContainerPool(size: 2, config: .strict(image: "swift:latest"))
    await pool.prewarm()

    let result = try await pool.withContainer { manager in
        try await manager.run(goal: "test") { _ in "ok" }
    }
    #expect(result.value == "ok")
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerPoolParallelAllocations() async throws {
    let pool = ContainerPool(size: 3, config: .strict(image: "swift:latest"))
    await pool.prewarm()

    async let r1 = pool.withContainer { manager in try await manager.run(goal: "t1") { _ in "r1" } }
    async let r2 = pool.withContainer { manager in try await manager.run(goal: "t2") { _ in "r2" } }
    async let r3 = pool.withContainer { manager in try await manager.run(goal: "t3") { _ in "r3" } }
    let results = try await [r1, r2, r3]

    #expect(results.map(\.value).sorted() == ["r1", "r2", "r3"])
}
