import Foundation

/// A per-target frame source.
///
/// M1 provides a ScreenCaptureKit implementation. Keeping the protocol
/// platform-neutral lets tests inject deterministic frame sequences.
public protocol CaptureSource: AnyObject, Sendable {
    var targetID: UUID { get }
    /// True once the session hit an unrecoverable error (target window
    /// closed, permission revoked). Sessions never auto-recover; deciding
    /// whether to re-establish is the coordinator's job (M2).
    var isFailed: Bool { get }
    var failureMessage: String? { get }
    func start() async throws
    func stop()
    /// The most recent frame, in memory only. `nil` before the first frame
    /// arrives; callers drive refresh by polling.
    func latestFrame() -> CaptureFrame?
}

extension CaptureSource {
    // Default no-failure surface so lightweight test doubles only implement
    // what they exercise.
    public var isFailed: Bool { false }
    public var failureMessage: String? { nil }
}
