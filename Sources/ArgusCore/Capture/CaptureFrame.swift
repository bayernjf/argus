import CoreGraphics
import Foundation

/// One captured frame from a target window.
///
/// Frames live in memory for the lifetime of the capture session. They are
/// deliberately not `Codable` and must not be written to disk by default.
public struct CaptureFrame {
    public let targetID: UUID
    public let image: CGImage
    public let capturedAt: Date

    public init(targetID: UUID, image: CGImage, capturedAt: Date = Date()) {
        self.targetID = targetID
        self.image = image
        self.capturedAt = capturedAt
    }
}
