import Foundation

/// The on-disk shape of one monitored target (docs/02 §7: persist bundle id,
/// title match, card order; never screenshots, frames or reply text).
///
/// `windowTitle` is a human hint, not an identity. Restoring never trusts it
/// alone: `TargetRestorer` binds only when the bundle resolves to exactly one
/// available window (owner decision, 2026-11-21).
public struct PersistedTarget: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public var displayName: String
    public var bundleIdentifier: String
    public var windowTitle: String
    public var note: String?

    public init(
        id: UUID,
        displayName: String,
        bundleIdentifier: String,
        windowTitle: String,
        note: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.note = note
    }

    public init(target: TargetApplication) {
        self.init(
            id: target.id,
            displayName: target.displayName,
            bundleIdentifier: target.bundleIdentifier,
            windowTitle: target.windowTitle,
            note: target.note
        )
    }

    /// Rebuilds the card for the unresolved state. Phase and frame time are
    /// deliberately reset: a stale "Completed" from the previous launch must
    /// not be presented as current truth.
    public func makeTargetApplication() -> TargetApplication {
        TargetApplication(
            id: id,
            displayName: displayName,
            bundleIdentifier: bundleIdentifier,
            windowTitle: windowTitle,
            phase: .idle,
            lastFrameAt: nil,
            note: note
        )
    }
}

/// Versioned container for `~/Library/Application Support/Argus/targets.json`.
/// Decoding rejects unknown versions instead of guessing a migration.
public struct TargetFile: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var targets: [PersistedTarget]

    public init(version: Int = TargetFile.currentVersion, targets: [PersistedTarget]) {
        self.version = version
        self.targets = targets
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Self.currentVersion else {
            throw TargetFileError.unsupportedVersion(version)
        }
        self.version = version
        self.targets = try container.decode([PersistedTarget].self, forKey: .targets)
    }
}

public enum TargetFileError: Error, Equatable, Sendable, CustomStringConvertible {
    case unsupportedVersion(Int)

    public var description: String {
        switch self {
        case .unsupportedVersion(let version):
            "Unsupported targets file version \(version); expected \(TargetFile.currentVersion)."
        }
    }
}
