// Generated from CodeGenSpecs/SandboxTests.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Testing
@testable import SwiftSynapseContainers

// MARK: - ContainerConfiguration Tests

@Test func containerConfigurationDefaultsAreStrict() {
    let config = ContainerConfiguration(image: "swift:latest")
    #expect(config.policy == .strict)
    #expect(config.networkEnabled == false)
    #expect(config.mounts.isEmpty)
}

@Test func containerConfigurationStrictFactoryEnforcesNoNetwork() {
    let config = ContainerConfiguration.strict(image: "ubuntu:24.04")
    #expect(config.policy == .strict)
    #expect(config.networkEnabled == false)
    #expect(config.mounts.isEmpty)
}

@Test func containerConfigurationStandardFactoryEnablesNetwork() {
    let config = ContainerConfiguration.standard(image: "ubuntu:24.04")
    #expect(config.policy == .standard)
    #expect(config.networkEnabled == true)
    #expect(config.mounts.isEmpty)
}

@Test func containerConfigurationStrictPolicyOverridesNetworkParameter() {
    // Passing networkEnabled: true with .strict policy must be rejected
    let config = ContainerConfiguration(
        image: "swift:latest",
        policy: .strict,
        networkEnabled: true
    )
    #expect(config.networkEnabled == false)
}

@Test func containerConfigurationPermissiveAllowsMounts() {
    let mounts = [VolumeMount(hostPath: "/tmp/input", guestPath: "/input", readOnly: true)]
    let config = ContainerConfiguration.permissive(image: "ubuntu:24.04", mounts: mounts)
    #expect(config.mounts.count == 1)
    #expect(config.mounts[0].hostPath == "/tmp/input")
}

@Test func containerConfigurationStrictIgnoresMounts() {
    let mounts = [VolumeMount(hostPath: "/tmp/input", guestPath: "/input", readOnly: true)]
    let config = ContainerConfiguration(
        image: "swift:latest",
        policy: .strict,
        mounts: mounts
    )
    #expect(config.mounts.isEmpty)
}

@Test func containerConfigurationClampsMinimumResources() {
    let config = ContainerConfiguration(image: "swift:latest", cpuCount: 0, memoryGB: 0, diskGB: 0)
    #expect(config.cpuCount >= 1)
    #expect(config.memoryGB >= 1)
    #expect(config.diskGB >= 5)
}

// MARK: - SandboxPolicy Tests

@Test func sandboxPolicyNetworkEnabled() {
    #expect(SandboxPolicy.strict.networkEnabled == false)
    #expect(SandboxPolicy.standard.networkEnabled == true)
    #expect(SandboxPolicy.permissive.networkEnabled == true)
}

@Test func sandboxPolicyAllowsMounts() {
    #expect(SandboxPolicy.strict.allowsMounts == false)
    #expect(SandboxPolicy.standard.allowsMounts == false)
    #expect(SandboxPolicy.permissive.allowsMounts == true)
}

@Test func sandboxPolicyCaseIterable() {
    #expect(SandboxPolicy.allCases.count == 3)
}

// MARK: - ContainerizedResult Tests

@Test func containerizedResultIsInitializable() {
    let result = ContainerizedResult(
        value: "hello",
        containerID: "abc-123",
        cpuTimeSeconds: 1.5,
        peakMemoryBytes: 1024 * 1024,
        wallTimeSeconds: 2.0
    )
    #expect(result.value == "hello")
    #expect(result.containerID == "abc-123")
    #expect(result.cpuTimeSeconds == 1.5)
    #expect(result.peakMemoryBytes == 1024 * 1024)
    #expect(result.wallTimeSeconds == 2.0)
}

// MARK: - ContainerManager Tests

@Test func containerManagerCreationWithValidConfig() {
    // ContainerManager init must not throw — VM boot is deferred to run(goal:execute:)
    let config = ContainerConfiguration.strict(image: "swift:latest")
    let _ = ContainerManager(config: config)
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_CONTAINER_TESTS"] != nil))
func containerManagerRunsGoalInMicroVM() async throws {
    let config = ContainerConfiguration.strict(image: "swift:latest")
    let manager = ContainerManager(config: config)
    let result = try await manager.run(goal: "echo hello") { goal in
        return "hello from container"
    }
    #expect(result.value == "hello from container")
    #expect(!result.containerID.isEmpty)
}
