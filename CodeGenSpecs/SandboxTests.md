# Spec: Sandbox Tests

**Generates:** `Tests/SwiftSynapseContainersTests/SandboxTests.swift`

---

## Test Coverage

All tests use **Swift Testing** (`import Testing`). Tests that require a running `container` CLI or Virtualization.framework entitlements are gated on `SWIFTSYNAPSE_CONTAINER_TESTS` environment variable.

### Standard Tests (always run)

1. `containerConfigurationDefaultsAreStrict`
   - Create `ContainerConfiguration(image: "swift:latest")`
   - Assert: `policy == .strict`, `networkEnabled == false`, `mounts.isEmpty == true`

2. `containerConfigurationStrictFactoryEnforcesNoNetwork`
   - Create `ContainerConfiguration.strict(image: "ubuntu:24.04")`
   - Assert: `networkEnabled == false`, `policy == .strict`

3. `containerConfigurationStandardFactoryEnablesNetwork`
   - Create `ContainerConfiguration.standard(image: "ubuntu:24.04")`
   - Assert: `networkEnabled == true`, `policy == .standard`

4. `sandboxPolicyNetworkEnabled`
   - Assert: `SandboxPolicy.strict.networkEnabled == false`
   - Assert: `SandboxPolicy.standard.networkEnabled == true`
   - Assert: `SandboxPolicy.permissive.networkEnabled == true`

5. `sandboxPolicyAllowsMounts`
   - Assert: `SandboxPolicy.strict.allowsMounts == false`
   - Assert: `SandboxPolicy.standard.allowsMounts == false`
   - Assert: `SandboxPolicy.permissive.allowsMounts == true`

6. `containerizedResultIsInitializable`
   - Create `ContainerizedResult(value: "hello", containerID: "abc", cpuTimeSeconds: 1.5, peakMemoryBytes: 1024, wallTimeSeconds: 2.0)`
   - Assert: `result.value == "hello"`, `result.containerID == "abc"`, `result.peakMemoryBytes == 1024`

7. `containerManagerCreationWithValidConfig`
   - Create `ContainerManager(config: .strict(image: "swift:latest"))`
   - Assert: creation does not throw (manager is created before any VM boot)

### Live Integration Tests (gated on SWIFTSYNAPSE_CONTAINER_TESTS)

8. `containerManagerRunsGoalInMicroVM` — full VM boot, executes `execute()` in container, returns result

---

## File Template

```swift
// Generated from CodeGenSpecs/SandboxTests.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Testing
@testable import SwiftSynapseContainers

// MARK: - ContainerConfiguration Tests

@Test func containerConfigurationDefaultsAreStrict() { ... }
@Test func containerConfigurationStrictFactoryEnforcesNoNetwork() { ... }
@Test func containerConfigurationStandardFactoryEnablesNetwork() { ... }

// MARK: - SandboxPolicy Tests

@Test func sandboxPolicyNetworkEnabled() { ... }
@Test func sandboxPolicyAllowsMounts() { ... }

// MARK: - ContainerizedResult Tests

@Test func containerizedResultIsInitializable() { ... }

// MARK: - ContainerManager Tests

@Test func containerManagerCreationWithValidConfig() { ... }

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerManagerRunsGoalInMicroVM() async throws { ... }
```
