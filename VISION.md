# SwiftSynapseContainers Vision

## The Problem

SwiftSynapse agents run in the host process. For most tasks this is fine. But some agent workloads require stronger guarantees:

- **Risky tools** — agents that execute shell commands, compile code, or manipulate files should not be able to affect the host system
- **Enterprise trust** — regulated environments require hardware-enforced isolation, not just process-level sandboxing
- **Parallel safety** — multi-agent crews running the same tools concurrently can interfere with each other through shared state
- **Supply-chain isolation** — sub-agents that pull and execute third-party code should never reach the host filesystem or credentials

The `@Sandbox` attribute on an agent is a promise, not a policy. What we need is enforcement.

## The Solution

SwiftSynapseContainers runs each agent's `execute(goal:)` payload inside an Apple MicroVM — a lightweight, hardware-isolated virtual machine provided by `Virtualization.framework`. The host process orchestrates (hooks, permissions, resilience, MCP) while the guest VM executes.

```
┌────────────────────────── Host Process ──────────────────────────────┐
│                                                                       │
│  @SpecDrivenAgent actor (orchestration)                              │
│    ├── AgentHookPipeline      (hooks fire in host)                   │
│    ├── PermissionGate         (policy evaluated in host)             │
│    ├── AgentToolLoop          (tool dispatch coordinated in host)    │
│    └── ContainerManager ──────────────────────────────────────────┐  │
│                                                                    │  │
│         ┌──────── MicroVM (VZVirtualMachine) ──────────────────┐  │  │
│         │                                                       │  │  │
│         │   execute(goal: String) async throws -> String        │  │  │
│         │     (tool calls, LLM calls, filesystem access)        │  │  │
│         │                                                       │  │  │
│         │   Isolated: no host filesystem, no host network,      │  │  │
│         │   no host memory, no host credentials                 │  │  │
│         └───────────────────────────────────────────────────────┘  │  │
│                                                                    │  │
│         ContainerizedResult<String> returned to host               │  │
└────────────────────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────────────────┘
```

## Non-Negotiables

1. **Hardware isolation, not sandbox policies** — every containerized execution runs in a real VM, not a chroot or namespace
2. **Zero host exposure** — a compromised agent cannot reach host credentials, filesystem, or network without explicit mounts
3. **Swift 6.2 strict concurrency** — zero data-race warnings, all container state behind actors
4. **Composition, not replacement** — `@Containerized` works alongside `@SpecDrivenAgent`, not instead of it
5. **macOS native** — Virtualization.framework is a first-party Apple API; we do not wrap third-party hypervisors
6. **Spec-driven** — every `.swift` file is generated from `CodeGenSpecs/`; never edit generated files directly
7. **Trait-modular** — users pay only for what they enable; a `Sandbox`-only build is the smallest possible footprint
8. **Observable** — all container lifecycle events flow through the Harness hook pipeline; nothing is silent

## Key Use Cases

### 1. Single Hardened Agent

```swift
@Containerized(image: "swift:latest", policy: .strict)
@SpecDrivenAgent
public actor CodeReviewAgent { ... }

// host orchestration:
let result = try await agent.containerized(goal: "Review this PR for security issues")
// agent.execute() ran inside an isolated MicroVM; host never saw the code
```

### 2. Multi-Agent Crew with Parallel Containers

```swift
// ContainerPool keeps N pre-warmed VMs ready for instant allocation
let pool = ContainerPool(size: 4, config: .init(image: "swift:latest", policy: .strict))

async let r1 = agent1.containerized(goal: task1)
async let r2 = agent2.containerized(goal: task2)
async let r3 = agent3.containerized(goal: task3)
let results = try await [r1, r2, r3]
// three parallel MicroVMs, hardware-isolated from each other
```

### 3. Sub-Agent Isolation

```swift
// In a MultiAgent coordinator:
let subAgent = try SubAgent(config: config)
let result = try await subAgent.containerized(goal: untrustedTask)
// sub-agent's LLM calls, tool calls, and filesystem access are contained
```

### 4. Secure Tool Injection

```swift
// Inject credentials into the container without exposing them in the goal string
let bundle = try SecureInjectionBundle(
    credentials: ["OPENAI_API_KEY": apiKey],
    tools: [CalculateTool.self]
)
let result = try await agent.containerized(goal: task, injecting: bundle)
// credentials are sealed, injected into VM environment, never visible to host logs
```

## Trait Strategy

| You need | Use |
|----------|-----|
| Basic isolation for one agent | `traits: ["Sandbox"]` |
| Parallel multi-agent isolation | `traits: ["Sandbox", "ContainerPool"]` |
| Enterprise production (recommended) | default — `SecureProduction` |
| Full feature set | `traits: ["Full"]` |

## The `SecureProduction` Opinionated Bundle

`SecureProduction` = Sandbox + ContainerPool + SecureInjection + ContainerMonitoring

This is the default. It gives you:
- Hardware-isolated MicroVM per agent execution
- Pre-warmed pool for near-instant allocation (eliminates VM boot latency on hot paths)
- Sealed credential injection (credentials never appear in goal strings or logs)
- Real-time CPU/memory metrics with configurable kill switches

## What SwiftSynapseContainers Does NOT Do

- It does not replace the Harness. Hooks, permissions, resilience, and MCP all run in the host.
- It does not manage container registries. Use `container pull` (the CLI tool) to pre-fetch images.
- It does not provide networking between containers. Inter-agent communication goes through the host actor layer.
- It does not support iOS or visionOS. MicroVMs require macOS.

## Integration with the SwiftSynapse Ecosystem

```
SwiftOpenResponsesDSL          ← Foundation LLM response DSL
SwiftLLMToolMacros             ← @LLMTool, @LLMToolArguments
SwiftSynapseMacros             ← @SpecDrivenAgent, @StructuredOutput, @Capability, @AgentGoal
SwiftSynapseHarness            ← Full agent harness (re-exports all of the above)
  ↑ consumed by
SwiftSynapseContainers         ← MicroVM container layer (this package)
  ↑ consumed by
SwiftSynapse agents             ← import SwiftSynapseContainers (gets everything)
```
