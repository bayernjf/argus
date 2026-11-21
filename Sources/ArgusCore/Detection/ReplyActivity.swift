import Foundation

/// The raw signal fed into `ReplyCompletionDetector`.
///
/// A frame pipeline may derive these values from text stability, a visible
/// stop button, or accessibility state. The detector itself stays pure.
public enum ReplyActivity: String, Codable, Sendable, CaseIterable {
    case generating
    case idle
    case unknown
}
