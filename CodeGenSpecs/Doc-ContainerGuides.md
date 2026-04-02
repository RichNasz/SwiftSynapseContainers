# Spec: DocC Guides

**Generates:**
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/GettingStarted.md`
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/ContainerSandboxGuide.md`
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/SecureProductionGuide.md`
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/HowToContainerizeAnAgent.md`
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/HowToUseContainerPool.md`

---

## GettingStarted.md

A four-step onboarding guide. Audience: Swift developers who already know SwiftSynapseHarness.

Steps:
1. Add the Package — Package.swift snippet
2. Pull the Container Image — `brew install container` + `container pull swift:latest`
3. Annotate Your Agent — `@Containerized` macro + what it generates
4. Call the Agent — both `run(goal:)` and `containerized(goal:)` side by side

End with policy selection table and links to deeper guides.

---

## ContainerSandboxGuide.md

Full runtime reference. Audience: developers integrating the package into production systems.

Topics:
- Host vs. guest execution diagram (what runs where and why)
- `ContainerConfiguration` construction and policy enforcement
- Resource minimums
- `MicroVMHandle` lifecycle
- `ContainerizedResult` fields and how to use them for tuning
- Error handling for all `ContainerizedAgentError` cases
- Virtualization.framework entitlement requirements

---

## SecureProductionGuide.md

Production deployment guide. Audience: engineers shipping containerized agents to customers.

Topics:
- `SecureProduction` trait bundle contents
- `SecureInjectionBundle` — encryption model, usage, what it protects
- `ContainerHealthMonitor` — threshold configuration, status callbacks, `ContainerMetrics`
- `ContainerSnapshotStore` — save/load/delete, storage location, warm restart
- Production checklist (images, entitlements, resource sizing, timeout tuning, pool sizing, monitoring hooks)

---

## HowToContainerizeAnAgent.md

Step-by-step procedural. Audience: developers migrating an existing `@SpecDrivenAgent` actor.

Steps:
1. Prerequisites
2. Add `@Containerized` — before/after snippet
3. Choose the right policy — three patterns
4. Size the VM — how to read `peakMemoryBytes`
5. Call `containerized(goal:)` — side-by-side with `run(goal:)`
6. Handle container errors — `ContainerizedAgentError` catch block
7. Complete example — end-to-end agent definition and usage

---

## HowToUseContainerPool.md

Step-by-step procedural. Audience: developers building multi-agent crews.

Topics:
- Basic pool setup and `prewarm()`
- `withContainer(_:)` for scoped allocation
- Manual `allocate()` / `release()` pattern
- Parallel execution with `async let` and `TaskGroup`
- Pool sizing guidance table
- Checking `capacity` and `availableCount` at runtime
- Cancellation and release safety notes

---

## Style Rules

- Use ` ``TypeName`` ` for all symbol references
- Use `<doc:ArticleName>` for cross-article links
- Code blocks use `swift` syntax highlighting
- Tables over bullet lists for comparison content
- No emoji
