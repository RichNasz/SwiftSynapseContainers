# SwiftSynapseContainers

## Project Overview

SwiftSynapseContainers gives SwiftSynapse agents hardware-enforced sandbox isolation by running them inside Apple MicroVM containers. Each agent (or sub-agent) executes inside its own Virtualization.framework virtual machine, providing true per-agent security for risky tools, parallel execution across container pools, and enterprise-grade trust boundaries.

The package introduces the `@Containerized` macro, the `ContainerizedAgent` protocol, and a trait system (`Sandbox`, `ContainerPool`, `SecureInjection`, `ContainerMonitoring`, `ContainerPersistence`) that mirrors SwiftSynapseHarness's design exactly.

## Commands

- **Build**: `swift build`
- **Test**: `swift test`
- **Test (verbose)**: `swift test --verbose`
- **Clean**: `swift package clean`

## Architecture

### Three-Target Structure

1. **SwiftSynapseContainersMacros** (macro target) — Compiler plugin
   - `Plugin.swift` — `@main` CompilerPlugin entry point
   - `ContainerizedMacro.swift` — `@Containerized` member + extension macro
   - **SwiftSyntax only** — no sibling package imports

2. **SwiftSynapseContainers** (library target) — Main library
   - `Exports.swift` — `@_exported import SwiftSynapseHarness`
   - `TraitStubs.swift` — No-op stubs via `#if !TraitName`
   - Trait-guarded source files (one per subsystem)

3. **SwiftSynapseContainersTests** (test target) — Swift Testing suite

### Platform Scope

**macOS only.** `Virtualization.framework` does not exist on iOS or visionOS. Container workloads are server/desktop primitives. Platform declarations in `Package.swift`:

```swift
platforms: [.macOS(.v26)]
```

### Virtualization Backend

We use Apple's `Virtualization.framework` directly to create and manage lightweight Linux MicroVMs. The `container` CLI tool (from [apple/container](https://github.com/apple/container)) provides OCI image management and is invoked via `Foundation.Process` — it is a CLI tool, not a Swift library. Install it separately:

```bash
brew install container
# or download from https://github.com/apple/container/releases
```

### Package Traits

SwiftSynapseContainers uses SwiftPM Package Traits (SE-0450), matching the pattern in SwiftSynapseHarness exactly.

| Trait | Files | Default? |
|-------|-------|----------|
| `Sandbox` | ContainerConfiguration, SandboxPolicy, ContainerizedAgent, MicroVMHandle, ContainerManager | No |
| `ContainerPool` | ContainerPool | No |
| `SecureInjection` | SecureInjection | No |
| `ContainerMonitoring` | ContainerMonitoring | No |
| `ContainerPersistence` | ContainerPersistence | No |
| `SecureProduction` | Sandbox + ContainerPool + SecureInjection + ContainerMonitoring | **Yes** |
| `Full` | SecureProduction + ContainerPersistence | No |

`TraitStubs.swift` provides `#if !TraitName` no-op stubs for every cross-trait type reference.

### Key Types

| Type | Trait | Purpose |
|------|-------|---------|
| `ContainerConfiguration` | Sandbox | CPU/memory/disk limits, image name, mounts, policy |
| `SandboxPolicy` | Sandbox | `.strict` / `.standard` / `.permissive` security modes |
| `ContainerizedAgent` | Sandbox | Protocol that `@Containerized` actors conform to |
| `ContainerizedResult<T>` | Sandbox | Value + container metadata (CPU time, peak memory, exit code) |
| `MicroVMHandle` | Sandbox | Handle to a running `VZVirtualMachine` |
| `ContainerManager` | Sandbox | Actor managing a single container lifecycle |
| `ContainerPool` | ContainerPool | Actor managing a pool of pre-warmed containers |
| `SecureInjectionBundle` | SecureInjection | Encrypted tool credentials for in-container injection |
| `ContainerMetrics` | ContainerMonitoring | Real-time CPU/memory/disk metrics |
| `ContainerSnapshot` | ContainerPersistence | Serializable container state for warm restart |

### @Containerized Macro

Attaches to `@SpecDrivenAgent` actors. Generates:
- `public var containerConfig: ContainerConfiguration` (configured via macro arguments)
- `public var _containerID: String? = nil`
- `public func containerized(goal: String) async throws -> ContainerizedResult<String>`
- Extension: `MyAgent: ContainerizedAgent`

Usage:
```swift
@Containerized(image: "swift:latest", cpuCount: 2, memoryGB: 4, policy: .strict)
@SpecDrivenAgent
public actor MyAgent {
    // execute(goal:) runs in the host; containerized(goal:) runs in a MicroVM
}
```

## Spec-Driven Workflow

All `.swift` files are generated from specs in `CodeGenSpecs/`. Specs are the single source of truth.

1. Edit the relevant spec in `CodeGenSpecs/`
2. Re-generate the corresponding `.swift` file(s)
3. Run `swift build` to verify
4. Commit both spec and generated files together

**Never edit generated `.swift` files directly.**

## File Structure

```
Sources/
  SwiftSynapseContainersMacros/
    Plugin.swift
    ContainerizedMacro.swift
  SwiftSynapseContainers/
    Exports.swift
    TraitStubs.swift
    ContainerConfiguration.swift       (#if Sandbox)
    SandboxPolicy.swift                (#if Sandbox)
    ContainerizedAgent.swift           (#if Sandbox)
    MicroVMHandle.swift                (#if Sandbox)
    ContainerManager.swift             (#if Sandbox)
    ContainerPool.swift                (#if ContainerPool)
    SecureInjection.swift              (#if SecureInjection)
    ContainerMonitoring.swift          (#if ContainerMonitoring)
    ContainerPersistence.swift         (#if ContainerPersistence)
Tests/
  SwiftSynapseContainersTests/
    SandboxTests.swift
    ContainerPoolTests.swift
CodeGenSpecs/
  Overview.md
  ContainerSpec.md
  MacroSpec.md
  Traits.md
  SandboxTests.md
  ContainerPoolTests.md
  README-Generation.md
```

## Dependencies

- [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) (branch: main) — harness, macros, traits
- [swift-syntax](https://github.com/swiftlang/swift-syntax) >= 602.0.0 — macro plugin compilation
- [apple/container](https://github.com/apple/container) — OCI image management CLI (invoked as subprocess)
- `Virtualization.framework` — system framework, linked automatically on macOS

## Requirements

- Swift 6.2+
- macOS 26+
- `container` CLI tool installed (for OCI image pulls/pushes)
- SIP-compatible hardware (Apple Silicon recommended for best Virtualization.framework performance)

## Relationship to SwiftSynapseHarness

SwiftSynapseContainers **wraps** SwiftSynapseHarness, not replaces it. The `@Containerized` macro composes with `@SpecDrivenAgent`. A containerized agent still uses all Harness features (hooks, permissions, resilience, MCP) — they run in the host orchestrating the container, while `execute(goal:)` is the payload that runs inside the MicroVM.

## Claude Code Files

Only `CLAUDE.md` is tracked. The `.claude/` directory is gitignored.
