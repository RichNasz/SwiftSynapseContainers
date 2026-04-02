# Spec: README Generation

**Generates:** `README.md`

---

## README Structure

The README must cover:

1. **Header** — package name, one-line description, badges (build, platforms, license)
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
