import ArgusCore
import XCTest
@testable import Argus

@MainActor
final class DiagnosticsStoreTests: XCTestCase {
    func testFrameRateUsesRecentFrameTimestamps() {
        let store = DiagnosticsStore()
        let targetID = UUID()
        let start = Date(timeIntervalSince1970: 0)

        for index in 0..<5 {
            store.recordFrame(
                targetID: targetID,
                capturedAt: start.addingTimeInterval(Double(index) * 0.5)
            )
        }

        let rate = store.frameRate(
            for: targetID,
            at: start.addingTimeInterval(2)
        )
        XCTAssertEqual(rate ?? 0, 2, accuracy: 0.01)
    }

    func testRepeatedErrorIsCoalescedUntilCooldown() {
        let store = DiagnosticsStore()
        let targetID = UUID()

        store.recordError(.noFrames, targetID: targetID, slot: 1, at: Date(timeIntervalSince1970: 0))
        store.recordError(.noFrames, targetID: targetID, slot: 1, at: Date(timeIntervalSince1970: 5))
        XCTAssertEqual(store.events.count, 1)

        store.recordError(.noFrames, targetID: targetID, slot: 1, at: Date(timeIntervalSince1970: 11))
        XCTAssertEqual(store.events.count, 2)
    }

    func testReportMapsCaptureFailureWithoutLeakingRawMessage() {
        let store = DiagnosticsStore()
        let targetID = UUID()
        let target = TargetApplication(
            id: targetID,
            displayName: "Example",
            bundleIdentifier: "com.example.app",
            windowTitle: "Secret window title",
            phase: .unknown,
            lastFrameAt: Date(timeIntervalSince1970: 9)
        )

        let report = store.makeReport(
            targets: [target],
            captureStates: [targetID: .failed("Secret window title")],
            screenRecording: .denied,
            accessibility: .denied,
            appVersion: "dev",
            osVersion: "macOS",
            now: Date(timeIntervalSince1970: 10)
        )

        XCTAssertEqual(report.targets.count, 1)
        XCTAssertEqual(report.targets[0].captureState, .failed)
        XCTAssertEqual(report.targets[0].lastError, .captureFailed)
        XCTAssertEqual(report.targets[0].frameAgeSeconds ?? -1, 1, accuracy: 0.01)
        XCTAssertFalse(report.redactedText().contains("Secret window title"))
    }

    func testPermissionTransitionIsRecordedOncePerSignature() {
        let store = DiagnosticsStore()
        let date = Date(timeIntervalSince1970: 0)

        store.recordPermission(screen: .denied, accessibility: .granted, at: date)
        store.recordPermission(screen: .denied, accessibility: .granted, at: date.addingTimeInterval(1))

        XCTAssertEqual(store.events.filter { $0.code == .screenRecordingDenied }.count, 1)
    }
}
