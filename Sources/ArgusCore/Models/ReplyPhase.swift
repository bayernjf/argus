import Foundation

/// The visible state of an AI reply inside a target application.
///
/// Argus does not claim to read the model's internal state. It observes the
/// target window and reports what is visible on screen.
public enum ReplyPhase: String, Codable, Sendable, CaseIterable {
    case idle
    case streaming
    case settling
    case completed
    case unknown
}
