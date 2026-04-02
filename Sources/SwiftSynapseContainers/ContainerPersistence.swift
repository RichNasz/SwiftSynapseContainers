// Generated from CodeGenSpecs/ContainerSpec.md — Do not edit manually. Update spec and re-generate.

import Foundation

#if ContainerPersistence

// MARK: - ContainerSnapshot

/// A serializable snapshot of container state for warm restart.
///
/// Snapshots let frequently-run containers skip the full boot sequence by restoring
/// a known-good VM state. Use `ContainerSnapshotStore` to persist and retrieve snapshots.
public struct ContainerSnapshot: Sendable, Codable {
    /// The container instance ID this snapshot was taken from.
    public let containerID: String
    /// The OCI image name used when this snapshot was created.
    public let image: String
    /// When this snapshot was created.
    public let createdAt: Date
    /// Opaque VM state data (Virtualization.framework snapshot bytes).
    public let data: Data
    /// Approximate size of the snapshot in bytes.
    public var sizeBytes: Int { data.count }

    public init(containerID: String, image: String, createdAt: Date = Date(), data: Data) {
        self.containerID = containerID
        self.image = image
        self.createdAt = createdAt
        self.data = data
    }
}

// MARK: - ContainerSnapshotStore

/// Actor that persists and retrieves `ContainerSnapshot` values to disk.
///
/// Snapshots are stored under `baseDirectory/<image-tag>/latest.snapshot`.
/// Only the most recent snapshot per image tag is retained.
public actor ContainerSnapshotStore {
    // MARK: - State

    private let baseDirectory: URL

    // MARK: - Init

    /// Creates a store backed by `baseDirectory`.
    /// The directory is created on demand on first write.
    public init(baseDirectory: URL? = nil) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.baseDirectory = baseDirectory ?? caches.appendingPathComponent("com.swiftsynapse.containers/snapshots")
    }

    // MARK: - Read / Write

    /// Saves `snapshot` to disk, overwriting any existing snapshot for the same image.
    public func save(_ snapshot: ContainerSnapshot) throws {
        let dir = snapshotDirectory(for: snapshot.image)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("latest.snapshot")
        let encoded = try JSONEncoder().encode(snapshot)
        try encoded.write(to: url, options: .atomic)
    }

    /// Loads the most recent snapshot for `image`, or returns nil if none exists.
    public func load(for image: String) throws -> ContainerSnapshot? {
        let url = snapshotDirectory(for: image).appendingPathComponent("latest.snapshot")
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ContainerSnapshot.self, from: data)
    }

    /// Deletes the stored snapshot for `image`.
    public func delete(for image: String) throws {
        let url = snapshotDirectory(for: image).appendingPathComponent("latest.snapshot")
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Private Helpers

    private func snapshotDirectory(for image: String) -> URL {
        // Sanitize the image tag for use as a path component
        let sanitized = image.replacingOccurrences(of: ":", with: "-")
                             .replacingOccurrences(of: "/", with: "_")
        return baseDirectory.appendingPathComponent(sanitized)
    }
}

#endif
