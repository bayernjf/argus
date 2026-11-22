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
    /// Fingerprint of the reply region when this generation was first seen.
    /// A quiet frame that still shows the same text (for example the user's
    /// prompt plus Doubao's thinking dots) is not a completed reply; the text
    /// must have grown since generation started before completion is allowed.
    private var generationBaselineFingerprint: String?
    private var sawTextChangeSinceGenerating = false
    private var hasFingerprintSignal = false
    /// Last readable reply-region fingerprint before this observation. Used as
    /// the baseline when a new generation starts, so a reply that finishes
    /// entirely between two samples can still be recognized as new text.
    private var previousFingerprint: String?

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
        observe(
            observation.activity(minConfidence: profile.minConfidence),
            fingerprint: observation.textFingerprint,
            textRegionEmpty: observation.textRegionEmpty,
            newPrompt: observation.newPrompt,
            at: date
        )
    }

    @discardableResult
    public mutating func observe(
        _ activity: ReplyActivity,
        at date: Date = Date()
    ) -> ReplyPhase {
        observe(activity, fingerprint: nil, textRegionEmpty: false, newPrompt: false, at: date)
    }

    private mutating func observe(
        _ activity: ReplyActivity,
        fingerprint: String?,
        textRegionEmpty: Bool,
        newPrompt: Bool,
        at date: Date
    ) -> ReplyPhase {
        let previous = phase
        defer {
            if let fingerprint {
                previousFingerprint = fingerprint
            }
        }
        if fingerprint != nil {
            hasFingerprintSignal = true
        }
        switch activity {
        case .generating:
            let startsNewGeneration = !sawGenerating
                || phase == .completed
                || phase == .idle
                || phase == .unknown
            if startsNewGeneration {
                // An empty answer region is a real baseline: the first text
                // that appears after it is new, even if its hash matches the
                // previous reply (a repeated short answer).
                generationBaselineFingerprint = (textRegionEmpty || newPrompt)
                    ? nil
                    : previousFingerprint
                sawTextChangeSinceGenerating = false
            }
            noteTextChange(fingerprint)
            sawGenerating = true
            idleSince = nil
            phase = .streaming

        case .idle:
            if sawGenerating {
                noteTextChange(fingerprint)
            }
            guard phase != .completed else {
                return phase
            }
            guard sawGenerating || idleSince != nil else {
                phase = .idle
                return phase
            }

            if let idleSince {
                if date.timeIntervalSince(idleSince) >= settleDuration,
                   canComplete {
                    phase = .completed
                } else {
                    phase = .settling
                }
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

    private var canComplete: Bool {
        // Legacy activity-only observers have no text signal; preserve their
        // behaviour. When OCR provides a fingerprint, require evidence that
        // the reply text changed after generation started.
        !hasFingerprintSignal || sawTextChangeSinceGenerating
    }

    private mutating func noteTextChange(_ fingerprint: String?) {
        guard let fingerprint else { return }
        guard let baseline = generationBaselineFingerprint else {
            // The reply region was empty when generation started; the first
            // readable text is new assistant content.
            generationBaselineFingerprint = fingerprint
            sawTextChangeSinceGenerating = true
            return
        }
        if fingerprint != baseline {
            sawTextChangeSinceGenerating = true
        }
    }

    public mutating func reset(at date: Date? = nil) {
        sawGenerating = false
        idleSince = nil
        generationBaselineFingerprint = nil
        sawTextChangeSinceGenerating = false
        hasFingerprintSignal = false
        previousFingerprint = nil
        phase = .idle
        phaseChangedAt = date
    }
}
