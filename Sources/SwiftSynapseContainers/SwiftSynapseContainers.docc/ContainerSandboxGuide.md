# Container Sandbox Guide

A complete reference for the SwiftSynapseContainers runtime — configuration, lifecycle, security policies, and the relationship between host and guest.

## Overview

Every `containerized(goal:)` call creates a hardware-isolated MicroVM, passes the goal string to the guest, runs `execute(goal:)` inside the VM, collects the result and metrics, and tears the VM down. The host process never executes untrusted code.

```
Host (ContainerManager)
  ├── verifyImage()           — confirms OCI image is present locally
  ├── buildVMConfig()         — builds VZVirtualMachineConfiguration
  ├── MicroVMHandle.start()   — boots the VZVirtualMachine
  ├── inject goal via serial  — sends goal string to guest init process
  ├── await result via serial — receives execute(goal:) return value
  ├── collect metrics         — CPU time, peak memory
  └── MicroVMHandle.stop()    — graceful shutdown
```

## ContainerConfiguration

``ContainerConfiguration`` is an immutable value type. Construct it directly or use the static factories:

```swift
// Explicit construction
let config = ContainerConfiguration(
    image: "swift:latest",
    cpuCount: 4,
    memoryGB: 8,
    diskGB: 40,
    policy: .standard,
    networkEnabled: true,
    environment: ["LOG_LEVEL": "debug"],
    timeoutSeconds: 600
)

// Static factories
let strict      = ContainerConfiguration.strict(image: "swift:latest")
let standard    = ContainerConfiguration.standard(image: "ubuntu:24.04")
let permissive  = ContainerConfiguration.permissive(image: "ubuntu:24.04", mounts: [
    VolumeMount(hostPath: "/tmp/workspace", guestPath: "/workspace", readOnly: false)
])
```

### Policy Enforcement

``SandboxPolicy`` enforces security constraints at construction time, regardless of other parameters:

- ``SandboxPolicy/strict`` — `networkEnabled` is always `false`, `mounts` is always `[]`
- ``SandboxPolicy/standard`` — `mounts` is always `[]`
- ``SandboxPolicy/permissive`` — `networkEnabled` and `mounts` are used as specified

```swift
// This will have networkEnabled = false regardless of the parameter:
let config = ContainerConfiguration(image: "swift:latest", policy: .strict, networkEnabled: true)
assert(config.networkEnabled == false)
```

### Resource Minimums

``ContainerConfiguration`` enforces minimum resource allocations at init:
- `cpuCount` minimum: 1
- `memoryGB` minimum: 1
- `diskGB` minimum: 5
- `timeoutSeconds` minimum: 1

## MicroVMHandle

``MicroVMHandle`` is the actor that owns a `VZVirtualMachine` lifecycle. You do not create it directly — ``ContainerManager`` creates and manages handles internally.

The handle tracks ``MicroVMState`` and exposes `start()`, `stop(gracePeriodSeconds:)`, and `forceStop()`. On timeout, `ContainerManager` calls `forceStop()` which immediately terminates the VM.

## ContainerizedResult

Every successful `containerized(goal:)` call returns a ``ContainerizedResult``:

```swift
public struct ContainerizedResult<T: Sendable>: Sendable {
    public let value: T              // execute(goal:) return value
    public let containerID: String   // UUID for this VM instance
    public let cpuTimeSeconds: Double
    public let peakMemoryBytes: UInt64
    public let wallTimeSeconds: Double
}
```

Use `peakMemoryBytes` and `wallTimeSeconds` to tune resource limits in ``ContainerConfiguration``.

## Error Handling

``ContainerizedAgentError`` covers all failure modes:

```swift
do {
    let result = try await agent.containerized(goal: task)
} catch ContainerizedAgentError.imageNotFound(let image) {
    // Run: container pull <image>
} catch ContainerizedAgentError.bootFailed(let reason) {
    // VM failed to start — check Virtualization.framework entitlements
} catch ContainerizedAgentError.timeoutExceeded(let seconds) {
    // Increase containerConfig.timeoutSeconds or reduce agent workload
} catch ContainerizedAgentError.containerToolNotFound {
    // Install: brew install container
}
```

## Host vs. Guest Execution

Understanding what runs where is critical for security architecture:

| Component | Runs in | Rationale |
|-----------|---------|-----------|
| `AgentHookPipeline` | Host | Hooks observe and control agent lifecycle |
| `PermissionGate` | Host | Policy decisions must not be delegable to guest |
| `RecoveryChain` | Host | Recovery logic wraps the full containerized call |
| `AgentToolLoop` | Host | Tool dispatch coordinates multiple VM calls |
| `execute(goal:)` | **Guest** | Domain logic, LLM calls, file writes — isolated |
| `@LLMTool` implementations | **Guest** | Tool execution happens inside the VM |

## Virtualization.framework Requirements

SwiftSynapseContainers uses `Virtualization.framework` directly. Running VMs requires:

- macOS 26+ (macOS 11+ minimum for the framework, 26 is the package's deployment target)
- The process must have the `com.apple.security.virtualization` entitlement
- Apple Silicon recommended — Rosetta VMs are not supported

For development builds signed with Xcode, the entitlement is added automatically via the default development signing. For distribution, add it to your `.entitlements` file:

```xml
<key>com.apple.security.virtualization</key>
<true/>
```
