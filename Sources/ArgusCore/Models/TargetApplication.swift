import Foundation

/// A window that Argus is allowed to observe.
///
/// `id` identifies the Argus-side target, not the target application's
/// process. The same application may have more than one monitored window.
public struct TargetApplication: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public var displayName: String
    public var bundleIdentifier: String
    public var windowTitle: String
    public var phase: ReplyPhase
    /// When `phase` last changed. Nil on a restored card until live capture
    /// establishes a fresh baseline; never persisted as current truth.
    public var phaseChangedAt: Date?
    public var lastFrameAt: Date?
    public var note: String?

    public init(
        id: UUID = UUID(),
        displayName: String,
        bundleIdentifier: String,
        windowTitle: String,
        phase: ReplyPhase = .idle,
        phaseChangedAt: Date? = nil,
        lastFrameAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.windowTitle = windowTitle
        self.phase = phase
        self.phaseChangedAt = phaseChangedAt
        self.lastFrameAt = lastFrameAt
        self.note = note
    }
}
