# Spec: ContainerPool Tests

**Generates:** `Tests/SwiftSynapseContainersTests/ContainerPoolTests.swift`

---

## Test Coverage

All tests use **Swift Testing** (`import Testing`). Live tests gated on `SWIFTSYNAPSE_CONTAINER_TESTS`.

### Standard Tests (always run)

1. `containerPoolCreationWithValidSize`
   - Create `ContainerPool(size: 2, config: .strict(image: "swift:latest"))`
   - Assert: creation does not throw

2. `containerPoolSizeIsRespected`
   - Create pool with size 3
   - Assert: `await pool.capacity == 3`

3. `containerPoolAllocateReturnsManagerOrNilWhenEmpty`
   - When `#if !ContainerPool` (stub): `allocate()` returns nil
   - When `#if ContainerPool` (real): allocate returns a manager or nil

4. `containerPoolReleaseDoesNotThrow`
   - Create pool, allocate a manager (or use stub), release it
   - Assert: no throw

### Live Integration Tests (gated on SWIFTSYNAPSE_CONTAINER_TESTS)

5. `containerPoolAllocatesAndReleasesVMs` — full pre-warm, allocate, run, release cycle
6. `containerPoolParallelAllocations` — allocate N managers concurrently, all succeed

---

## File Template

```swift
// Generated from CodeGenSpecs/ContainerPoolTests.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Testing
@testable import SwiftSynapseContainers

// MARK: - ContainerPool Tests

@Test func containerPoolCreationWithValidSize() { ... }
@Test func containerPoolSizeIsRespected() async { ... }
@Test func containerPoolAllocateReturnsManagerOrNilWhenEmpty() async { ... }
@Test func containerPoolReleaseDoesNotThrow() async throws { ... }

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerPoolAllocatesAndReleasesVMs() async throws { ... }

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerPoolParallelAllocations() async throws { ... }
```
