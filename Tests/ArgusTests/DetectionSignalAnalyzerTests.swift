import ArgusCore
import CoreGraphics
import XCTest
@testable import Argus

final class ReplySignalAnalyzerTests: XCTestCase {
    private func makeImage(
        width: Int = 640,
        height: Int = 360,
        draw: (CGContext) -> Void = { _ in }
    ) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        draw(context)
        return context.makeImage()!
    }

    private func frame(_ image: CGImage, at time: TimeInterval) -> CaptureFrame {
        CaptureFrame(
            targetID: UUID(),
            image: image,
            capturedAt: Date(timeIntervalSince1970: time)
        )
    }

    func testLumaGridDetectsLargeVisualChange() {
        let before = makeImage()
        let after = makeImage { context in
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 180))
        }
        let a = LumaSampler.grid(from: before, roi: nil)!
        let b = LumaSampler.grid(from: after, roi: nil)!
        XCTAssertGreaterThan(b.changedPixelRatio(comparedTo: a) ?? 0, 0.2)
    }

    func testAnalyzerTreatsLargeVisualChangeAsGenerating() async {
        let analyzer = ReplySignalAnalyzer()
        let profile = ReplyProfile(id: "test", ocrInterval: 1)
        let base = makeImage()
        let changed = makeImage { context in
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 240))
        }

        let first = await analyzer.analyze(
            frame: frame(base, at: 100),
            profile: profile,
            accessibilityGenerating: nil
        )
        XCTAssertEqual(first.activity(minConfidence: profile.minConfidence), .idle)

        let second = await analyzer.analyze(
            frame: frame(changed, at: 101),
            profile: profile,
            accessibilityGenerating: nil
        )
        XCTAssertEqual(second.isChanging, true)
        XCTAssertEqual(second.activity(minConfidence: profile.minConfidence), .generating)
    }

    func testAnalyzerResetDropsPreviousFrameBaseline() async {
        let analyzer = ReplySignalAnalyzer()
        let profile = ReplyProfile(id: "test", ocrInterval: 1)
        let base = makeImage()
        let changed = makeImage { context in
            context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 240))
        }

        _ = await analyzer.analyze(
            frame: frame(base, at: 100),
            profile: profile,
            accessibilityGenerating: nil
        )
        await analyzer.reset()
        let afterReset = await analyzer.analyze(
            frame: frame(changed, at: 101),
            profile: profile,
            accessibilityGenerating: nil
        )
        // First sample after reset establishes a baseline; it must not claim
        // that the just-changed window is still streaming.
        XCTAssertEqual(afterReset.isChanging, false)
    }

    func testAXProbeIsUnmeasuredWithoutPermission() {
        XCTAssertNil(AXStopControlProbe.generatingIndicator(
            processID: 1,
            windowTitle: "any",
            isTrusted: false
        ))
    }

    func testTextFingerprintNormalizesWhitespaceAndCase() {
        XCTAssertEqual(
            TextFingerprint.make(from: "Hello\n  World"),
            TextFingerprint.make(from: "hello world")
        )
        XCTAssertNotEqual(
            TextFingerprint.make(from: "Hello"),
            TextFingerprint.make(from: "Hello!")
        )
        XCTAssertEqual(
            TextFingerprint.make(from: " \n\t "),
            TextFingerprint.make(from: "")
        )
    }
}
