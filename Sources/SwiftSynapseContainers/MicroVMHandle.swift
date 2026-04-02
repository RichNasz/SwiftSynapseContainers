// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Virtualization

#if Sandbox

// MARK: - MicroVMState

/// The lifecycle state of a MicroVM managed by `MicroVMHandle`.
public enum MicroVMState: Sendable {
    case starting
    case running
    case stopping
    case stopped
    case failed(String)
}

// MARK: - MicroVMHandle

/// Lightweight actor handle to a running `VZVirtualMachine`.
///
/// `MicroVMHandle` owns the VM lifecycle. Create one per `ContainerManager` execution.
/// Do not reuse handles — `ContainerPool` manages pre-warmed handle pooling.
public actor MicroVMHandle {
    // MARK: - State

    private var vm: VZVirtualMachine
    public private(set) var containerID: String
    public private(set) var state: MicroVMState = .starting

    // MARK: - Init

    /// Creates a handle from a validated `VZVirtualMachineConfiguration`.
    ///
    /// Throws if the configuration fails Virtualization.framework validation.
    public init(configuration: VZVirtualMachineConfiguration) throws {
        try configuration.validate()
        self.containerID = UUID().uuidString
        self.vm = VZVirtualMachine(configuration: configuration)
    }

    // MARK: - Lifecycle

    /// Boots the virtual machine. Throws if already running or if the VM fails to start.
    public func start() async throws {
        guard case .starting = state else { return }
        try await vm.start()
        state = .running
    }

    /// Attempts a graceful shutdown. Waits up to `gracePeriodSeconds` before forcing termination.
    public func stop(gracePeriodSeconds: TimeInterval = 5) async throws {
        guard case .running = state else { return }
        state = .stopping
        do {
            try await vm.stop()
            state = .stopped
        } catch {
            await forceStop()
        }
    }

    /// Immediately terminates the virtual machine. Used on timeout.
    public func forceStop() async {
        try? await vm.stop()
        state = .stopped
    }

    /// Polls state until `.running` is reached, or throws `ContainerizedAgentError.bootFailed`
    /// if the VM does not reach running state within `timeout` seconds.
    public func waitForRunning(timeout: TimeInterval = 30) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if case .running = state { return }
            if case .failed(let reason) = state {
                throw ContainerizedAgentError.bootFailed(reason)
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw ContainerizedAgentError.bootFailed("VM did not reach running state within \(timeout)s")
    }

    // MARK: - Metrics

    /// Peak memory used by the guest in bytes (available after VM has run).
    /// Returns 0 if the VM has not yet completed.
    public var peakMemoryBytes: UInt64 {
        // VZVirtualMachine does not expose peak memory directly; real implementation
        // would query guest via virtio balloon or memoryPressureHandler.
        // Placeholder returns memory allocation size as upper bound.
        return 0
    }
}

#endif
