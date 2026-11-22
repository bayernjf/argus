import ArgusCore
import XCTest

final class DiagnosticReportTests: XCTestCase {
    func testRedactedTextContainsStateAndStableCodes() {
        let report = DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 100),
            appVersion: "0.4.0 (42)",
            osVersion: "macOS 27.0",
            screenRecording: .denied,
            accessibility: .granted,
            targets: [
                DiagnosticTarget(
                    slot: 1,
                    bundleIdentifier: "com.example.app",
                    phase: .unknown,
                    captureState: .failed,
                    frameAgeSeconds: 3.2,
                    frameRate: 0,
                    detectionLatencyMilliseconds: 18,
                    lastError: .captureFailed
                )
            ],
            events: [
                DiagnosticEvent(
                    sequence: 0,
                    timestamp: Date(timeIntervalSince1970: 101),
                    slot: 1,
                    kind: .phaseTransition,
                    fromPhase: .streaming,
                    toPhase: .unknown
                ),
                DiagnosticEvent(
                    sequence: 1,
                    timestamp: Date(timeIntervalSince1970: 102),
                    slot: 1,
                    kind: .error,
                    code: .captureFailed
                )
            ]
        )

        let text = report.redactedText()
        XCTAssertTrue(text.contains("Target 1"))
        XCTAssertTrue(text.contains("com.example.app"))
        XCTAssertTrue(text.contains("D05_CAPTURE"))
        XCTAssertTrue(text.contains("streaming->unknown"))
        XCTAssertTrue(text.contains("Screen Recording: denied"))
        XCTAssertTrue(text.contains("Accessibility: granted"))
    }

    func testRedactedTextHasNoPlaceForWindowTitlesOrRawMessages() {
        let report = DiagnosticReport(
            generatedAt: Date(timeIntervalSince1970: 100),
            appVersion: "dev",
            osVersion: "macOS",
            screenRecording: .granted,
            accessibility: .granted,
            targets: [],
            events: []
        )

        let text = report.redactedText()
        XCTAssertFalse(text.contains("windowTitle"))
        XCTAssertFalse(text.contains("Secret window title"))
        XCTAssertTrue(text.contains("no screenshots, OCR text or window titles"))
    }
}
