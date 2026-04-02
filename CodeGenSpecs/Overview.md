# CodeGenSpecs Overview

## Purpose

This directory contains the specifications that serve as the single source of truth for all generated `.swift` files in SwiftSynapseContainers. Every `.swift` file in `Sources/` and `Tests/` is a generated artifact — to change behavior, update the relevant spec and re-generate.

Specs are organized by **Package Trait**, matching the pattern in SwiftSynapseHarness exactly. The spec name matches the trait name directly (e.g., `ContainerSpec.md` → all `#if Sandbox` files).

## Trait Source Specs

| Spec | Trait Guard | Generates |
|------|------------|-----------|
| [ContainerSpec.md](ContainerSpec.md) | `#if Sandbox` | `ContainerConfiguration.swift`, `SandboxPolicy.swift`, `ContainerizedAgent.swift`, `MicroVMHandle.swift`, `ContainerManager.swift` |
| [ContainerPoolSpec.md](ContainerPoolSpec.md) | `#if ContainerPool` | `ContainerPool.swift` |
| [SecureInjectionSpec.md](SecureInjectionSpec.md) | `#if SecureInjection` | `SecureInjection.swift` |
| [ContainerMonitoringSpec.md](ContainerMonitoringSpec.md) | `#if ContainerMonitoring` | `ContainerMonitoring.swift` |
| [ContainerPersistenceSpec.md](ContainerPersistenceSpec.md) | `#if ContainerPersistence` | `ContainerPersistence.swift` |

## Infrastructure Specs

| Spec | Generates |
|------|-----------|
| [Traits.md](Traits.md) | `TraitStubs.swift` (no-op stubs via `#if !TraitName`), `Package.swift` trait declarations |
| [MacroSpec.md](MacroSpec.md) | `Sources/SwiftSynapseContainersMacros/Plugin.swift`, `ContainerizedMacro.swift` |

## Test Specs

| Spec | Generates |
|------|-----------|
| [SandboxTests.md](SandboxTests.md) | `Tests/SwiftSynapseContainersTests/SandboxTests.swift` |
| [ContainerPoolTests.md](ContainerPoolTests.md) | `Tests/SwiftSynapseContainersTests/ContainerPoolTests.swift` |

## Documentation Specs

| Spec | Generates |
|------|-----------|
| [Doc-ContainerCatalog.md](Doc-ContainerCatalog.md) | `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/SwiftSynapseContainers.md` |
| [Doc-ContainerGuides.md](Doc-ContainerGuides.md) | `GettingStarted.md`, `ContainerSandboxGuide.md`, `SecureProductionGuide.md`, `HowToContainerizeAnAgent.md`, `HowToUseContainerPool.md` |
| [README-Generation.md](README-Generation.md) | `README.md` |

## Generation Rules

1. Every generated `.swift` file starts with:
   ```
   // Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.
   ```

2. Specs are the authority — if code and spec disagree, the spec wins.

3. Edit spec → regenerate files → `swift build` → commit both together.

## Workflow

1. Identify which trait the change belongs to
2. Edit the corresponding spec (and the corresponding `*Tests.md` if behavior changes)
3. Re-generate the corresponding `.swift` file(s)
4. Run `swift build` to verify
5. Commit spec(s) and generated file(s) together

## Source File Structure

Every trait-guarded file follows this exact pattern:

```swift
// Generated from CodeGenSpecs/<SpecName>.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Virtualization  // only in Sandbox-guarded files

#if Sandbox  // or ContainerPool, SecureInjection, ContainerMonitoring, ContainerPersistence

// MARK: - ...
public struct/actor/enum/protocol ...

#endif
```

`Exports.swift` re-exports SwiftSynapseHarness outside any `#if` block (the re-export always happens):

```swift
@_exported import SwiftSynapseHarness
```

`TraitStubs.swift` uses `#if !TraitName` internally and has no outer `#if`.
