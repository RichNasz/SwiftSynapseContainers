# Spec: DocC Catalog

**Generates:**
- `Sources/SwiftSynapseContainers/SwiftSynapseContainers.docc/SwiftSynapseContainers.md`

---

## Overview

The catalog is the root DocC page for the `SwiftSynapseContainers` module. It groups all public symbols into named topic sections and links all article pages.

## Required Sections (in order)

1. `# ``SwiftSynapseContainers``` — module symbol link title
2. One-line abstract — hardware-enforced MicroVM sandbox isolation
3. `## Overview` — 2–3 sentences explaining what the package does and the re-export of SwiftSynapseHarness
4. `## Topics` with these groups:
   - **Essentials** — links to all article .md files
   - **Macro** — `@Containerized`
   - **Container Protocol** — `ContainerizedAgent`, `ContainerizedResult`, `ContainerizedAgentError`
   - **Configuration** — `ContainerConfiguration`, `SandboxPolicy`, `VolumeMount`
   - **Container Runtime** — `ContainerManager`, `MicroVMHandle`, `MicroVMState`
   - **Container Pool** — `ContainerPool`
   - **Secure Injection** — `SecureInjectionBundle`, `SecureInjector`
   - **Monitoring** — `ContainerMetrics`, `ContainerHealthMonitor`, `ContainerHealthMonitor.Thresholds`, `ContainerHealthStatus`
   - **Persistence** — `ContainerSnapshot`, `ContainerSnapshotStore`

## Rules

- All symbol links use backtick-double-backtick format: ` ``TypeName`` `
- All article links use `<doc:ArticleName>` format
- The catalog `.md` filename must exactly match the module target name
