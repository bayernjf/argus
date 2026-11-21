import ArgusCore
import CoreGraphics
import CryptoKit
import Foundation
import Vision

/// Samples one target's latest frame and turns it into a `ReplyObservation`.
///
/// The actor owns only the previous luma grid and a hashed text fingerprint.
/// `CGImage`s and recognized strings are local variables and are dropped as
/// soon as the observation is returned (docs/02 §4.3, no body persistence).
actor ReplySignalAnalyzer {
    private var previousGrid: LumaGrid?
    private var previousFingerprint: String?
    private var lastOCRAt: Date?
    private var ocrAvailable = false
    private var visualStopControl = false

    func reset() {
        previousGrid = nil
        previousFingerprint = nil
        lastOCRAt = nil
        ocrAvailable = false
        visualStopControl = false
    }

    /// Runs vision and (optional) Accessibility signals. Accessibility is
    /// fetched outside this actor because AX traversal belongs to AppKit/OS
    /// integration; `accessibilityGenerating` is `nil` when unmeasured.
    func analyze(
        frame: CaptureFrame,
        profile: ReplyProfile,
        accessibilityGenerating: Bool?
    ) async -> ReplyObservation {
        let image = frame.image
        let grid = LumaSampler.grid(from: image, roi: profile.replyROI)
        let visualChangeRatio = grid.flatMap { current in
            previousGrid.flatMap { current.changedPixelRatio(comparedTo: $0) }
        }
        let visualChanged = visualChangeRatio.map { $0 >= profile.changeThreshold }

        var fingerprint = previousFingerprint
        // OCR is the expensive signal: run it for the baseline, to recover
        // from a failed read, and only when pixels actually moved. A static
        // completed card must not burn 2 Hz Vision work forever.
        let elapsedSinceOCR = lastOCRAt.map { frame.capturedAt.timeIntervalSince($0) }
        let ocrDue = lastOCRAt == nil
            || !ocrAvailable
            || (visualChanged == true && (elapsedSinceOCR ?? 0) >= profile.ocrInterval)

        if ocrDue {
            lastOCRAt = frame.capturedAt
            if let recognized = try? OCRRecognizer.recognizeText(in: image, roi: profile.replyROI) {
                fingerprint = TextFingerprint.make(from: recognized)
                ocrAvailable = true
            } else {
                // Keep the last good hash: an OCR failure is not evidence that
                // the reply disappeared. Low confidence below prevents it from
                // being treated as a stable completion signal.
                ocrAvailable = false
            }
            if let controlROI = profile.controlROI,
               let controlText = try? OCRRecognizer.recognizeText(in: image, roi: controlROI) {
                visualStopControl = profile.contains(stopControlIn: controlText)
            }
        }

        let textChanged: Bool? = {
            guard ocrAvailable, let fingerprint, let previousFingerprint else { return nil }
            return fingerprint != previousFingerprint
        }()

        let hasGeneratingIndicator: Bool? = {
            if visualStopControl { return true }
            return accessibilityGenerating
        }()

        let isChanging: Bool?
        let confidence: Double
        if hasGeneratingIndicator == true {
            isChanging = true
            confidence = 0.95
        } else if textChanged == true {
            isChanging = true
            confidence = 0.95
        } else if !ocrAvailable {
            // Text signal unavailable: never infer a completion from pixels
            // alone. The next successful OCR may recover.
            isChanging = visualChanged
            confidence = 0.45
        } else if let visualChanged {
            isChanging = visualChanged
            // Stable text plus a small visual delta is likely an animation
            // (spinner/caret). It may delay settling, but never fabricates a
            // completion while the window is still visibly active.
            confidence = visualChanged ? 0.7 : 0.9
        } else {
            // First sample: establish a baseline but do not claim activity.
            isChanging = false
            confidence = 0.8
        }

        previousGrid = grid
        previousFingerprint = fingerprint

        let source: ReplySignalSource = accessibilityGenerating == nil ? .visual : .fused
        return ReplyObservation(
            isChanging: isChanging,
            hasGeneratingIndicator: hasGeneratingIndicator,
            textFingerprint: fingerprint,
            confidence: confidence,
            source: source
        )
    }
}

/// Builds deterministic grayscale grids for frame comparison.
enum LumaSampler {
    static func grid(from image: CGImage, roi: ArgusCore.NormalizedRect?) -> LumaGrid? {
        let source = crop(image, to: roi) ?? image
        var pixels = [UInt8](
            repeating: 0,
            count: 160 * 160
        )
        guard let context = CGContext(
            data: &pixels,
            width: 160,
            height: 160,
            bitsPerComponent: 8,
            bytesPerRow: 160,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(source, in: CGRect(x: 0, y: 0, width: 160, height: 160))
        return LumaGrid(width: 160, height: 160, pixels: pixels)
    }

    static func crop(_ image: CGImage, to roi: ArgusCore.NormalizedRect?) -> CGImage? {
        guard let roi, let clamped = roi.clamped() else { return nil }
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let rect = CGRect(
            x: clamped.x * width,
            y: clamped.y * height,
            width: clamped.width * width,
            height: clamped.height * height
        ).integral
        guard rect.width > 1, rect.height > 1 else { return nil }
        return image.cropping(to: rect)
    }
}

/// Normalizes visible text into a SHA-256 fingerprint. The text itself never
/// leaves this function, and no OCR body is kept in the analyzer state.
enum TextFingerprint {
    static func make(from text: String) -> String {
        let normalized = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let digest = SHA256.hash(data: Data(normalized.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// Local Vision OCR. Recognition runs only on the supplied image/ROI; no text
/// is persisted and no network request is made.
enum OCRRecognizer {
    static func recognizeText(in image: CGImage, roi: ArgusCore.NormalizedRect?) throws -> String {
        let source = LumaSampler.crop(image, to: roi) ?? image
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en-US", "zh-Hans"]
        let handler = VNImageRequestHandler(cgImage: source, orientation: .up)
        try handler.perform([request])
        let observations = request.results ?? []
        return observations
            .sorted { lhs, rhs in
                if lhs.boundingBox.minY != rhs.boundingBox.minY {
                    return lhs.boundingBox.minY > rhs.boundingBox.minY
                }
                return lhs.boundingBox.minX < rhs.boundingBox.minX
            }
            .compactMap { observation -> String? in
                guard let candidate = observation.topCandidates(1).first,
                      candidate.confidence >= 0.3
                else { return nil }
                return candidate.string
            }
            .joined(separator: "\n")
    }
}
