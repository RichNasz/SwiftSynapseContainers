# Spec: Package Traits

**Generates:**
- `Sources/SwiftSynapseContainers/TraitStubs.swift`

---

## Overview

SwiftSynapseContainers uses SwiftPM Package Traits (SE-0450), exactly matching the pattern in SwiftSynapseHarness. Trait names declared in `Package.swift` are directly available as compilation conditions — `#if Sandbox`, `#if ContainerPool`, etc. No `.define()` or `swiftSettings` are needed.

---

## Trait Definitions

| Trait | What it enables | Default? |
|-------|----------------|----------|
| `Sandbox` | ContainerConfiguration, SandboxPolicy, ContainerizedAgent, ContainerizedResult, MicroVMHandle, ContainerManager | No |
| `ContainerPool` | ContainerPool (pre-warmed VM pool for parallel execution) | No |
| `SecureInjection` | SecureInjectionBundle, SecureInjector | No |
| `ContainerMonitoring` | ContainerMetrics, ContainerHealthMonitor | No |
| `ContainerPersistence` | ContainerSnapshot, ContainerSnapshotStore | No |
| `SecureProduction` | Sandbox + ContainerPool + SecureInjection + ContainerMonitoring | **Yes** (default) |
| `Full` | SecureProduction + ContainerPersistence | No |

---

## Cross-Trait Dependencies and Stubs

`ContainerManager` (Sandbox) references `ContainerPool` (ContainerPool), `SecureInjectionBundle` (SecureInjection), and `ContainerMetrics` (ContainerMonitoring) in method signatures. Since Swift does not support `#if` inside function parameter lists, these types must always exist at compile time.

`TraitStubs.swift` provides `#if !TraitName` stub blocks:

- `ContainerPool` stub: `ContainerPool` actor with no-op `allocate()` → `nil`
- `SecureInjection` stub: `SecureInjectionBundle` struct with no-op init
- `ContainerMonitoring` stub: `ContainerMetrics` struct with zero values
- `ContainerPersistence` stub: `ContainerSnapshot` struct with empty data

---

## TraitStubs.swift Structure

```swift
// Generated from CodeGenSpecs/Traits.md — Do not edit manually. Update spec and re-generate.

// MARK: - ContainerPool Stubs
#if !ContainerPool
public actor ContainerPool {
    public init(size: Int, config: ContainerConfiguration) {}
    public func allocate() async -> ContainerManager? { nil }
    public func release(_ manager: ContainerManager) async {}
}
#endif

// MARK: - SecureInjection Stubs
#if !SecureInjection
public struct SecureInjectionBundle: Sendable {
    public init(credentials: [String: String] = [:]) {}
}
#endif

// MARK: - ContainerMonitoring Stubs
#if !ContainerMonitoring
public struct ContainerMetrics: Sendable {
    public var cpuTimeSeconds: Double = 0
    public var peakMemoryBytes: UInt64 = 0
    public var diskReadBytes: UInt64 = 0
    public var diskWriteBytes: UInt64 = 0
    public init() {}
}
#endif

// MARK: - ContainerPersistence Stubs
#if !ContainerPersistence
public struct ContainerSnapshot: Sendable {
    public var containerID: String = ""
    public var data: Data = Data()
    public init() {}
}
#endif
```

**Note:** The `#if !Sandbox` stubs are NOT needed in TraitStubs because all cross-trait references are to types in non-Sandbox traits. The Sandbox trait is the root — all other traits depend on types from Sandbox.

---

## Package.swift Trait Declarations

```swift
traits: [
    .trait(name: "Sandbox",
           description: "MicroVM sandbox isolation via Virtualization.framework — core container runtime"),
    .trait(name: "ContainerPool",
           description: "Pre-warmed container pool for parallel agent and sub-agent execution"),
    .trait(name: "SecureInjection",
           description: "Cryptographically secure tool credential injection into containers"),
    .trait(name: "ContainerMonitoring",
           description: "Real-time CPU, memory, and disk metrics with health checks and alerts"),
    .trait(name: "ContainerPersistence",
           description: "Container snapshots, diff layers, and warm-restart state management"),
    .trait(name: "SecureProduction",
           description: "Sandbox + ContainerPool + SecureInjection + ContainerMonitoring — recommended for most agents",
           enabledTraits: ["Sandbox", "ContainerPool", "SecureInjection", "ContainerMonitoring"]),
    .trait(name: "Full",
           description: "All traits enabled — SecureProduction + ContainerPersistence",
           enabledTraits: ["SecureProduction", "ContainerPersistence"]),
    .default(enabledTraits: ["SecureProduction"]),
]
```

---

## User-Facing Examples

```swift
// Minimal — smallest binary (isolation only):
.package(url: "https://github.com/RichNasz/SwiftSynapseContainers", branch: "main", traits: ["Sandbox"])

// Default (most users — zero config):
.package(url: "https://github.com/RichNasz/SwiftSynapseContainers", branch: "main")

// Default + persistence:
.package(url: "https://github.com/RichNasz/SwiftSynapseContainers", branch: "main", traits: ["SecureProduction", "ContainerPersistence"])

// Everything:
.package(url: "https://github.com/RichNasz/SwiftSynapseContainers", branch: "main", traits: ["Full"])
```
