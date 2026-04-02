# ``SwiftSynapseContainers``

Hardware-enforced MicroVM sandbox isolation for SwiftSynapse agents — true per-agent security via Apple's Virtualization.framework.

## Overview

SwiftSynapseContainers adds a hardware-isolated execution layer to the SwiftSynapse ecosystem. Each agent's `execute(goal:)` payload runs inside a lightweight Apple MicroVM, giving you true sandbox isolation without process-level shortcuts.

The `@Containerized` macro composes with `@SpecDrivenAgent`. Harness features — hooks, permissions, resilience, MCP — run in the host and orchestrate the container. The MicroVM runs only the domain logic.

Re-exports `SwiftSynapseHarness`, so a single import gives you the full stack:

```swift
import SwiftSynapseContainers
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:ContainerSandboxGuide>
- <doc:SecureProductionGuide>
- <doc:HowToContainerizeAnAgent>
- <doc:HowToUseContainerPool>

### Macro

- ``Containerized(image:cpuCount:memoryGB:diskGB:policy:timeoutSeconds:)``

### Container Protocol

- ``ContainerizedAgent``
- ``ContainerizedResult``
- ``ContainerizedAgentError``

### Configuration

- ``ContainerConfiguration``
- ``SandboxPolicy``
- ``VolumeMount``

### Container Runtime

- ``ContainerManager``
- ``MicroVMHandle``
- ``MicroVMState``

### Container Pool

- ``ContainerPool``

### Secure Injection

- ``SecureInjectionBundle``
- ``SecureInjector``

### Monitoring

- ``ContainerMetrics``
- ``ContainerHealthMonitor``
- ``ContainerHealthMonitor/Thresholds``
- ``ContainerHealthStatus``

### Persistence

- ``ContainerSnapshot``
- ``ContainerSnapshotStore``
