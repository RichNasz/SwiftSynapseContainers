// swift-tools-version: 6.2

import CompilerPluginSupport
import PackageDescription

// NOTE: This package bridges to the `container` CLI tool (https://github.com/apple/container)
// via Foundation.Process for OCI image management. Install the tool separately:
//   brew install container
// Virtualization.framework is linked directly as a system framework (macOS 26+, macOS-only).

let package = Package(
    name: "SwiftSynapseContainers",
    platforms: [
        // Virtualization.framework is macOS-only. No iOS/visionOS support.
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "SwiftSynapseContainers",
            targets: ["SwiftSynapseContainers"]
        ),
    ],
    traits: [
        // Leaf traits — each enables a specific container subsystem
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

        // Composite traits — opinionated bundles
        .trait(name: "SecureProduction",
               description: "Sandbox + ContainerPool + SecureInjection + ContainerMonitoring — recommended for most agents",
               enabledTraits: ["Sandbox", "ContainerPool", "SecureInjection", "ContainerMonitoring"]),
        .trait(name: "Full",
               description: "All traits enabled — SecureProduction + ContainerPersistence",
               enabledTraits: ["SecureProduction", "ContainerPersistence"]),

        // Default trait set — what users get without specifying traits
        .default(enabledTraits: ["SecureProduction"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
    ],
    targets: [
        // MARK: - Macro Plugin (SwiftSyntax only — no sibling package imports)
        .macro(
            name: "SwiftSynapseContainersMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),

        // MARK: - Main Library
        .target(
            name: "SwiftSynapseContainers",
            dependencies: [
                "SwiftSynapseContainersMacros",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            linkerSettings: [
                // Virtualization.framework is macOS system framework — no extra install required
                .linkedFramework("Virtualization"),
            ]
        ),

        // MARK: - Tests
        .testTarget(
            name: "SwiftSynapseContainersTests",
            dependencies: ["SwiftSynapseContainers"],
            path: "Tests/SwiftSynapseContainersTests"
        ),
    ]
)
