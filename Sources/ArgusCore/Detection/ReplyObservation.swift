import Foundation

/// Where a completion observation came from.
///
/// Visual evidence is the baseline; Accessibility can strengthen or contradict
/// it. The detector only consumes the fused result, never a raw screenshot.
public enum ReplySignalSource: String, Codable, Sendable, CaseIterable {
    case visual
    case accessibility
    case fused
}

/// One sampled view of the target window.
///
/// `textFingerprint` is a normalized hash of visible text, not the text itself.
/// `isChanging` describes the visible reply region; `hasGeneratingIndicator`
/// is true when a visible Stop/Generating control is present. A missing field
/// means "not measured", never "false". The extractor must discard OCR text
/// after producing the fingerprint (docs/02 §4.1, no body persistence).
public struct ReplyObservation: Equatable, Sendable {
    public var isChanging: Bool?
    public var hasGeneratingIndicator: Bool?
    public var textFingerprint: String?
    public var confidence: Double
    public var source: ReplySignalSource

    public init(
        isChanging: Bool? = nil,
        hasGeneratingIndicator: Bool? = nil,
        textFingerprint: String? = nil,
        confidence: Double,
        source: ReplySignalSource = .visual
    ) {
        self.isChanging = isChanging
        self.hasGeneratingIndicator = hasGeneratingIndicator
        self.textFingerprint = textFingerprint
        self.confidence = min(1, max(0, confidence))
        self.source = source
    }

    /// Collapses a fused observation into the detector's raw activity.
    ///
    /// A visible generating control is a strong signal even when text looks
    /// stable. Everything else must meet the profile's confidence floor; low
    /// confidence becomes `unknown`, never `idle` (ADR-004).
    public func activity(minConfidence: Double) -> ReplyActivity {
        if hasGeneratingIndicator == true {
            return .generating
        }
        guard confidence >= minConfidence else {
            return .unknown
        }
        guard let isChanging else {
            return .unknown
        }
        return isChanging ? .generating : .idle
    }
}
