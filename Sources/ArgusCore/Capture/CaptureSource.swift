import Foundation

/// A per-target frame source.
///
/// M1 will provide a ScreenCaptureKit implementation. Keeping the protocol
/// platform-neutral lets tests inject deterministic frame sequences.
public protocol CaptureSource: AnyObject {
    var targetID: UUID { get }
    func start() throws
    func stop()
    func latestFrame() -> CaptureFrame?
}
