import Foundation

/// A small, deterministic state machine for "the visible AI reply has stopped".
///
/// The detector deliberately has a `settling` phase: a single quiet frame is
/// not enough to call a reply complete. If the signal is missing, it reports
/// `unknown` rather than guessing.
public struct ReplyCompletionDetector: Sendable {
    public private(set) var phase: ReplyPhase = .idle
    public let settleDuration: TimeInterval

    private var sawGenerating = false
    private var idleSince: Date?

    public init(settleDuration: TimeInterval = 1.0) {
        precondition(settleDuration >= 0, "settleDuration must be non-negative")
        self.settleDuration = settleDuration
    }

    @discardableResult
    public mutating func observe(
        _ activity: ReplyActivity,
        at date: Date = Date()
    ) -> ReplyPhase {
        switch activity {
        case .generating:
            sawGenerating = true
            idleSince = nil
            phase = .streaming

        case .idle:
            guard phase != .completed else {
                return phase
            }
            guard sawGenerating || idleSince != nil else {
                phase = .idle
                return phase
            }

            if let idleSince {
                phase = date.timeIntervalSince(idleSince) >= settleDuration
                    ? .completed
                    : .settling
            } else {
                self.idleSince = date
                phase = .settling
            }

        case .unknown:
            sawGenerating = false
            idleSince = nil
            phase = .unknown
        }

        return phase
    }

    public mutating func reset() {
        sawGenerating = false
        idleSince = nil
        phase = .idle
    }
}
