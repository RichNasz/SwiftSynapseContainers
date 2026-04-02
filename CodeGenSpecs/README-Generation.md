# Spec: README Generation

**Generates:** `README.md`

---

## Badge Pattern

Match the exact badge style used in the SwiftSynapse ecosystem (flat-square, shields.io).
Three badges appear on the line immediately after the `# SwiftSynapseContainers` heading:

```markdown
[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2026%2B-0078D4?style=flat-square&logo=apple&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)](#license)
```

Note: Platform badge says `macOS 26+` only — this package is macOS-exclusive (Virtualization.framework).
The SwiftSynapse main repo uses iOS/macOS/visionOS; do NOT copy that here.

## README Structure

The README must cover:

1. **Header** — `# SwiftSynapseContainers` heading, then the three badges on the next line, then the one-line description
2. **What It Is** — 2-3 sentences on purpose (hardware-enforced sandbox via MicroVM)
3. **Quick Start** — minimal Package.swift dependency + 5-line usage example
4. **Trait Selection** — table of all traits, what they enable, when to use each
5. **@Containerized Macro** — syntax, all arguments with defaults, what it generates
6. **ContainerConfiguration** — all properties with descriptions and defaults
7. **SandboxPolicy** — the three modes (strict/standard/permissive) and when to use each
8. **ContainerPool** — parallel execution pattern with code example
9. **Secure Injection** — how to inject credentials without exposing in logs
10. **Integration with SwiftSynapseHarness** — @Containerized composes with @SpecDrivenAgent; Harness features run in host
11. **Prerequisites** — Swift 6.2+, macOS 26+, container CLI installation
12. **Repository Links** — SwiftSynapse ecosystem links
13. **License** — MIT

## Style Rules

- No emojis in the README
- Code blocks use `swift` syntax highlighting
- Keep the Quick Start under 30 lines total
- Link to `VISION.md` for the full motivation
- Note clearly that this package is macOS-only
