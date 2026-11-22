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
    /// OCR succeeded but the answer region was empty. This lets the detector
    /// treat the first later text as new even when its hash equals an older
    /// reply (for example the user sends "收到" twice).
    public var textRegionEmpty: Bool
    /// A new right-aligned user prompt appeared. Even if the answer arrives
    /// in the same sample (and is byte-identical to the previous answer), the
    /// detector can still start a fresh text baseline.
    public var newPrompt: Bool
    public var confidence: Double
    public var source: ReplySignalSource

    public init(
        isChanging: Bool? = nil,
        hasGeneratingIndicator: Bool? = nil,
        textFingerprint: String? = nil,
        textRegionEmpty: Bool = false,
        newPrompt: Bool = false,
        confidence: Double,
        source: ReplySignalSource = .visual
    ) {
        self.isChanging = isChanging
        self.hasGeneratingIndicator = hasGeneratingIndicator
        self.textFingerprint = textFingerprint
        self.textRegionEmpty = textRegionEmpty
        self.newPrompt = newPrompt
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
