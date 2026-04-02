# Getting Started with SwiftSynapseContainers

From a standard SwiftSynapse agent to a hardware-isolated MicroVM agent in four steps.

## Overview

SwiftSynapseContainers wraps `SwiftSynapseHarness` and adds Apple MicroVM isolation. If you have an existing `@SpecDrivenAgent` actor, adding `@Containerized` is the only change required to run it inside a hardware-isolated virtual machine.

## Step 1: Add the Package

Add `SwiftSynapseContainers` to your `Package.swift`. It re-exports `SwiftSynapseHarness`, so you can replace that dependency entirely:

```swift
// Package.swift
dependencies: [
    .package(
        url: "https://github.com/RichNasz/SwiftSynapseContainers",
        branch: "main"
    )
],
targets: [
    .target(
        name: "MyAgent",
        dependencies: [
            .product(name: "SwiftSynapseContainers", package: "SwiftSynapseContainers")
        ]
    )
]
```

One import gives you the full stack — containers, harness, macros, and core types:

```swift
import SwiftSynapseContainers
```

## Step 2: Pull the Container Image

SwiftSynapseContainers uses the `container` CLI to manage OCI images. Install it and pull the image your agent will run inside:

```bash
# Install (Homebrew)
brew install container

# Pull the image you want to use
container pull swift:latest
```

The image must be available locally before your agent boots a VM.

## Step 3: Annotate Your Agent

Add `@Containerized` above `@SpecDrivenAgent`. All arguments have sensible defaults — only `image:` is required:

```swift
@Containerized(image: "swift:latest", policy: .strict)
@SpecDrivenAgent
public actor CodeSandboxAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        _ = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        // This body runs inside the MicroVM when called via containerized(goal:)
        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)
        return try await agent.respond(to: goal)
    }
}
```

`@Containerized` generates three members on the actor:
- `containerConfig` — the ``ContainerConfiguration`` built from your macro arguments
- `_containerID` — the instance ID from the last `containerized(goal:)` call
- `containerized(goal:)` — runs `execute(goal:)` inside a hardware-isolated MicroVM

## Step 4: Call the Agent

You now have two entry points. Use whichever fits your trust model:

```swift
let agent = try CodeSandboxAgent(configuration: config)

// Standard Harness run — hooks, permissions, and resilience apply in host:
let response = try await agent.run(goal: "Explain this algorithm")

// Containerized run — execute() runs inside a MicroVM, isolated from host:
let result = try await agent.containerized(goal: "Compile and run this Swift snippet")
print("Value:       \(result.value)")
print("Peak memory: \(result.peakMemoryBytes / 1_048_576) MB")
print("Wall time:   \(result.wallTimeSeconds)s")
```

## Choosing a Policy

| Policy | Network | Mounts | Use for |
|--------|---------|--------|---------|
| ``SandboxPolicy/strict`` | No | No | Untrusted code, default for `@Containerized` |
| ``SandboxPolicy/standard`` | Outbound | No | Agents that call external APIs |
| ``SandboxPolicy/permissive`` | Full | Declared | Agents with filesystem requirements |

## Next Steps

- <doc:ContainerSandboxGuide> — full reference for the container runtime
- <doc:HowToUseContainerPool> — pre-warm multiple VMs for parallel execution
- <doc:SecureProductionGuide> — credential injection, monitoring, and persistence
