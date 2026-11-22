import Foundation

/// A rectangle expressed in normalized image coordinates (0...1).
///
/// The origin is top-left, matching `CGImage` and ScreenCaptureKit output.
/// Profiles stay platform-neutral data so `ArgusCore` never imports AppKit or
/// Vision (ADR-010).
public struct NormalizedRect: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// A rectangle clipped to the image; an empty result means "no usable
    /// region" and the extractor must fall back instead of crashing.
    public func clamped() -> NormalizedRect? {
        let minX = min(max(x, 0), 1)
        let minY = min(max(y, 0), 1)
        let maxX = min(max(x + width, 0), 1)
        let maxY = min(max(y + height, 0), 1)
        guard maxX > minX, maxY > minY else { return nil }
        return NormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

/// Per-application detection parameters. It may narrow the sampled region or
/// change timing, but it never changes the state machine itself (ADR-010).
public struct ReplyProfile: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public var bundleIdentifier: String?
    /// Region containing the reply text. `nil` means the whole window.
    public var replyROI: NormalizedRect?
    /// Region containing the Stop/Generating control. `nil` means no visual
    /// control search; Accessibility may still provide the signal.
    public var controlROI: NormalizedRect?
    public var settleDuration: TimeInterval
    public var ocrInterval: TimeInterval
    /// Fraction of sampled pixels that must change to count as visual motion.
    public var changeThreshold: Double
    public var stopKeywords: [String]
    public var minConfidence: Double
    /// For chat UIs with right-aligned user bubbles: fingerprint only text
    /// below the latest right-aligned prompt, so a new prompt is not mistaken
    /// for assistant reply growth.
    public var answerTextBelowPrompt: Bool

    public init(
        id: String,
        bundleIdentifier: String? = nil,
        replyROI: NormalizedRect? = nil,
        controlROI: NormalizedRect? = nil,
        settleDuration: TimeInterval = 1.0,
        ocrInterval: TimeInterval = 1.0,
        changeThreshold: Double = 0.005,
        stopKeywords: [String] = [],
        minConfidence: Double = 0.6,
        answerTextBelowPrompt: Bool = false
    ) {
        precondition(settleDuration >= 0, "settleDuration must be non-negative")
        precondition(ocrInterval > 0, "ocrInterval must be positive")
        precondition((0...1).contains(changeThreshold), "changeThreshold must be 0...1")
        precondition((0...1).contains(minConfidence), "minConfidence must be 0...1")
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.replyROI = replyROI
        self.controlROI = controlROI
        self.settleDuration = settleDuration
        self.ocrInterval = ocrInterval
        self.changeThreshold = changeThreshold
        self.stopKeywords = stopKeywords
        self.minConfidence = minConfidence
        self.answerTextBelowPrompt = answerTextBelowPrompt
    }

    /// Conservative fallback used until a target has a calibrated profile.
    /// Visual stop-word detection stays off because the whole window may
    /// legitimately contain the word "stop" in a reply.
    public static let generic = ReplyProfile(
        id: "generic",
        // 0.5 s sampling keeps the completion latency inside the PRD's 3 s
        // draft while 1.0 s settle still absorbs short streaming pauses.
        settleDuration: 1.0,
        ocrInterval: 0.5,
        changeThreshold: 0.005,
        stopKeywords: [
            "stop", "stop generating", "cancel", "generating", "thinking",
            "停止", "停止生成", "取消", "正在生成", "思考中",
        ],
        minConfidence: 0.6
    )

    public func contains(stopControlIn text: String) -> Bool {
        guard controlROI != nil else { return false }
        return stopKeywords.contains { keyword in
            containsKeyword(keyword, in: text)
        }
    }

    private func containsKeyword(_ keyword: String, in text: String) -> Bool {
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(
            of: keyword,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: searchRange
        ) {
            if isWordBoundary(keyword: keyword, text: text, match: range) {
                return true
            }
            searchRange = range.upperBound..<text.endIndex
        }
        return false
    }

    private func isWordBoundary(
        keyword: String,
        text: String,
        match: Range<String.Index>
    ) -> Bool {
        let keywordStart = keyword.first.map(isASCIILetter) ?? false
        let keywordEnd = keyword.last.map(isASCIILetter) ?? false

        if keywordStart, match.lowerBound > text.startIndex {
            let previous = text[text.index(before: match.lowerBound)]
            if isASCIILetterOrDigit(previous) { return false }
        }
        if keywordEnd, match.upperBound < text.endIndex {
            let next = text[match.upperBound]
            if isASCIILetterOrDigit(next) { return false }
        }
        return true
    }

    private func isASCIILetter(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, scalar.isASCII else { return false }
        return CharacterSet.letters.contains(scalar)
    }

    private func isASCIILetterOrDigit(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first, scalar.isASCII else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }
}
