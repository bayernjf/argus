import Foundation

/// A small, deterministic state machine for "the visible AI reply has stopped".
///
/// The detector deliberately has a `settling` phase: a single quiet frame is
/// not enough to call a reply complete. If the signal is missing, it reports
/// `unknown` rather than guessing. It never exposes raw pixels or OCR text.
public struct ReplyCompletionDetector: Sendable {
    public private(set) var phase: ReplyPhase = .idle
    public private(set) var phaseChangedAt: Date?
    public let settleDuration: TimeInterval

    private var sawGenerating = false
    private var idleSince: Date?

    public init(settleDuration: TimeInterval = 1.0) {
        precondition(settleDuration >= 0, "settleDuration must be non-negative")
        self.settleDuration = settleDuration
    }

    @discardableResult
    public mutating func observe(
        _ observation: ReplyObservation,
        profile: ReplyProfile = .generic,
        at date: Date = Date()
    ) -> ReplyPhase {
        observe(observation.activity(minConfidence: profile.minConfidence), at: date)
    }

    @discardableResult
    public mutating func observe(
        _ activity: ReplyActivity,
        at date: Date = Date()
    ) -> ReplyPhase {
        let previous = phase
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
            // A transient signal loss must not erase the fact that generation
            // was observed. Clearing `sawGenerating` here would make a brief
            // OCR failure permanently block completion on a quiet reply.
            idleSince = nil
            phase = .unknown
        }

        if phase != previous {
            phaseChangedAt = date
        }
        return phase
    }

    public mutating func reset(at date: Date? = nil) {
        sawGenerating = false
        idleSince = nil
        phase = .idle
        phaseChangedAt = date
    }
}
