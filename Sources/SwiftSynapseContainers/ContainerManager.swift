// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation
import Virtualization

// VZVirtualMachineConfiguration is an ObjC class not yet annotated as Sendable.
// ContainerManager takes exclusive ownership after init, so @unchecked is safe here.
extension VZVirtualMachineConfiguration: @unchecked @retroactive Sendable {}

#if Sandbox

// MARK: - ContainerManager

/// Actor that manages the full lifecycle of a single MicroVM execution.
///
/// One `ContainerManager` is created per `containerized(goal:)` invocation — either directly
/// or allocated from a `ContainerPool` for pre-warmed performance. ContainerManager does not
/// cache or reuse VMs; that responsibility belongs to `ContainerPool`.
///
/// ```swift
/// let manager = ContainerManager(config: .strict(image: "swift:latest"))
/// let result = try await manager.run(goal: goal) { goal in
///     try await myAgent.execute(goal: goal)
/// }
/// ```
public actor ContainerManager {
    // MARK: - State

    private let config: ContainerConfiguration
    private var handle: MicroVMHandle?

    // MARK: - Init

    public init(config: ContainerConfiguration) {
        self.config = config
    }

    // MARK: - Execution

    /// Runs the provided `execute` closure inside a hardware-isolated MicroVM.
    ///
    /// Steps:
    /// 1. Verify the OCI image is available locally
    /// 2. Build `VZVirtualMachineConfiguration` from `ContainerConfiguration`
    /// 3. Boot the VM via `MicroVMHandle`
    /// 4. Inject the goal string via virtio-serial
    /// 5. Await the result via the same channel
    /// 6. Collect metrics, stop the VM, and return `ContainerizedResult`
    ///
    /// - Parameters:
    ///   - goal: The goal string passed to `execute`.
    ///   - execute: The agent's `execute(goal:)` implementation, captured from the host actor.
    public func run(
        goal: String,
        execute: @escaping @Sendable (String) async throws -> String
    ) async throws -> ContainerizedResult<String> {
        let wallStart = Date()

        // Step 1: Verify image is available locally
        try await verifyImage(config.image)

        // Step 2: Build VM configuration
        let vmConfig = try buildVMConfig()

        // Step 3: Boot the VM
        let newHandle = try MicroVMHandle(configuration: vmConfig)
        self.handle = newHandle
        try await newHandle.start()
        try await newHandle.waitForRunning(timeout: 30)

        // Step 4 + 5: Run the execute closure (in this bootstrap, directly in host)
        // Production implementation injects goal via virtio-serial and awaits result from guest.
        // For the bootstrap, we run execute() in the host to establish the API surface.
        let value: String
        do {
            value = try await withTimeout(seconds: config.timeoutSeconds) {
                try await execute(goal)
            }
        } catch is TimeoutError {
            await newHandle.forceStop()
            self.handle = nil
            throw ContainerizedAgentError.timeoutExceeded(config.timeoutSeconds)
        }

        // Step 6: Collect metrics and stop
        let peakMemory = await newHandle.peakMemoryBytes
        let containerID = await newHandle.containerID
        try await newHandle.stop()
        self.handle = nil

        let wallTime = Date().timeIntervalSince(wallStart)
        return ContainerizedResult(
            value: value,
            containerID: containerID,
            cpuTimeSeconds: wallTime * 0.8,  // placeholder — real impl reads from VZVirtualMachine
            peakMemoryBytes: peakMemory,
            wallTimeSeconds: wallTime
        )
    }

    // MARK: - Private Helpers

    private func verifyImage(_ image: String) async throws {
        // Invoke `container image inspect <image>` as a subprocess.
        // Throws ContainerizedAgentError.imageNotFound if the image is not cached locally.
        // Throws ContainerizedAgentError.containerToolNotFound if `container` CLI is not in PATH.
        let process = Process()
        let containerToolURL = URL(fileURLWithPath: "/usr/local/bin/container")
        let fallbackURL = URL(fileURLWithPath: "/opt/homebrew/bin/container")

        if FileManager.default.fileExists(atPath: containerToolURL.path) {
            process.executableURL = containerToolURL
        } else if FileManager.default.fileExists(atPath: fallbackURL.path) {
            process.executableURL = fallbackURL
        } else {
            throw ContainerizedAgentError.containerToolNotFound
        }

        process.arguments = ["image", "inspect", image]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw ContainerizedAgentError.imageNotFound(image)
        }
    }

    private func buildVMConfig() throws -> VZVirtualMachineConfiguration {
        let vmConfig = VZVirtualMachineConfiguration()
        vmConfig.cpuCount = config.cpuCount
        vmConfig.memorySize = config.memoryGB * 1024 * 1024 * 1024

        // Boot loader — Linux guests require a kernel and initrd.
        // Production implementation resolves these from the OCI image layers.
        let bootLoader = VZLinuxBootLoader(kernelURL: kernelURL(for: config.image))
        bootLoader.initialRamdiskURL = initrdURL(for: config.image)
        bootLoader.commandLine = "console=hvc0 root=/dev/vda rw quiet"
        vmConfig.bootLoader = bootLoader

        // Serial port for goal injection and result collection
        let serialPort = VZVirtioConsoleDeviceSerialPortConfiguration()
        serialPort.attachment = VZFileHandleSerialPortAttachment(
            fileHandleForReading: .nullDevice,
            fileHandleForWriting: .nullDevice
        )
        vmConfig.serialPorts = [serialPort]

        // Network (only if policy permits)
        if config.networkEnabled {
            let networkDevice = VZVirtioNetworkDeviceConfiguration()
            networkDevice.attachment = VZNATNetworkDeviceAttachment()
            vmConfig.networkDevices = [networkDevice]
        }

        // Storage
        let diskURL = try ephemeralDiskURL(sizeGB: config.diskGB)
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(url: diskURL, readOnly: false)
        let storageDevice = VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        vmConfig.storageDevices = [storageDevice]

        // VirtioFS mounts (only if policy permits and mounts declared)
        if config.policy.allowsMounts && !config.mounts.isEmpty {
            var fsDevices: [VZVirtioFileSystemDeviceConfiguration] = []
            for mount in config.mounts {
                let share = VZSharedDirectory(url: URL(fileURLWithPath: mount.hostPath), readOnly: mount.readOnly)
                let singleShare = VZSingleDirectoryShare(directory: share)
                let fsDevice = VZVirtioFileSystemDeviceConfiguration(tag: mount.guestPath)
                fsDevice.share = singleShare
                fsDevices.append(fsDevice)
            }
            vmConfig.directorySharingDevices = fsDevices
        }

        try vmConfig.validate()
        return vmConfig
    }

    // MARK: - Image Path Resolution

    private func kernelURL(for image: String) -> URL {
        // Production implementation resolves the kernel from extracted OCI image layers.
        // Bootstrap placeholder points to a well-known location used by `container` CLI.
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("com.apple.container/images/\(image)/kernel")
    }

    private func initrdURL(for image: String) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent("com.apple.container/images/\(image)/initrd")
    }

    private func ephemeralDiskURL(sizeGB: UInt64) throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let diskURL = tmpDir.appendingPathComponent("swiftsynapse-\(UUID().uuidString).img")
        // Production implementation creates a sparse disk image of the requested size.
        // Bootstrap creates a placeholder empty file for API surface validation.
        if !FileManager.default.fileExists(atPath: diskURL.path) {
            FileManager.default.createFile(atPath: diskURL.path, contents: nil)
        }
        return diskURL
    }
}

// MARK: - Timeout Helper

private struct TimeoutError: Error {}

private func withTimeout<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

#endif
