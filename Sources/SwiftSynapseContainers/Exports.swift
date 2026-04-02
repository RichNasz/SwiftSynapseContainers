// Generated from CodeGenSpecs/Overview.md — Do not edit manually. Update spec and re-generate.

// Re-export the full Harness so users only need `import SwiftSynapseContainers`.
// This mirrors the same pattern as SwiftSynapseHarness re-exporting SwiftSynapseMacrosClient.
@_exported import SwiftSynapseHarness

// MARK: - @Containerized Macro Declaration

#if Sandbox

import Virtualization

/// Adds MicroVM container lifecycle to a `@SpecDrivenAgent` actor.
///
/// Generates:
/// - `containerConfig: ContainerConfiguration` — the VM resource and security configuration
/// - `_containerID: String?` — the container instance ID from the most recent invocation
/// - `containerized(goal:) async throws -> ContainerizedResult<String>` — runs `execute(goal:)` inside a MicroVM
///
/// Attach to an `actor` declaration alongside `@SpecDrivenAgent`:
///
/// ```swift
/// @Containerized(image: "swift:latest", policy: .strict)
/// @SpecDrivenAgent
/// public actor MyAgent { ... }
/// ```
@attached(member, names: named(containerConfig), named(_containerID), named(containerized))
@attached(extension, conformances: ContainerizedAgent)
public macro Containerized(
    image: String,
    cpuCount: Int = 2,
    memoryGB: UInt64 = 4,
    diskGB: UInt64 = 20,
    policy: SandboxPolicy = .strict,
    timeoutSeconds: TimeInterval = 300
) = #externalMacro(module: "SwiftSynapseContainersMacros", type: "ContainerizedMacro")

#endif
