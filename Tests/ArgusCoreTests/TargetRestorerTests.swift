import ArgusCore
import CoreGraphics
import XCTest

@testable import ArgusCore

final class TargetRestorerTests: XCTestCase {
    private func record(
        id: UUID = UUID(),
        app: String = "ChatGPT",
        bundle: String = "com.openai.chat",
        title: String = "ChatGPT"
    ) -> PersistedTarget {
        PersistedTarget(id: id, displayName: app, bundleIdentifier: bundle, windowTitle: title)
    }

    private func window(
        id: UInt32 = 1,
        app: String = "ChatGPT",
        bundle: String = "com.openai.chat",
        title: String = "ChatGPT"
    ) -> CaptureWindowInfo {
        CaptureWindowInfo(
            id: id,
            appName: app,
            appBundleIdentifier: bundle,
            windowTitle: title,
            frame: CGRect(x: 0, y: 0, width: 1200, height: 800)
        )
    }

    func testBindsWhenBundleHasExactlyOneWindow() {
        let saved = record()
        let restoration = TargetRestorer.restore([saved], against: [window(id: 7)])
        XCTAssertEqual(restoration.restored.count, 1)
        XCTAssertEqual(restoration.restored.first?.record.id, saved.id)
        XCTAssertEqual(restoration.restored.first?.window.id, 7)
    }

    func testDoesNotBindWhenAppHasNoWindow() {
        let restoration = TargetRestorer.restore([record()], against: [window(bundle: "com.anthropic.claudefordesktop")])
        XCTAssertTrue(restoration.restored.isEmpty)
        XCTAssertEqual(restoration.unresolved.first?.issue, .noEligibleWindow)
        XCTAssertEqual(restoration.unresolved.first?.candidateCount, 0)
    }

    func testDoesNotBindWhenBundleHasSeveralWindowsEvenIfTitleMatches() {
        let saved = record(title: "Release checklist")
        let windows = [
            window(id: 1, title: "Release checklist"),
            window(id: 2, title: "Other chat"),
        ]
        let restoration = TargetRestorer.restore([saved], against: windows)
        XCTAssertTrue(restoration.restored.isEmpty, "title match alone must not bind")
        XCTAssertEqual(restoration.unresolved.first?.issue, .ambiguousWindows)
        XCTAssertEqual(restoration.unresolved.first?.candidateCount, 2)
    }

    func testEmptyBundleNeverBinds() {
        let restoration = TargetRestorer.restore(
            [record(bundle: "   ")],
            against: [window(bundle: "")]
        )
        XCTAssertTrue(restoration.restored.isEmpty)
        XCTAssertEqual(restoration.unresolved.first?.issue, .missingBundleIdentifier)
    }

    func testTwoRecordsNeverClaimTheSameWindow() {
        let first = record(id: UUID())
        let second = record(id: UUID())
        let restoration = TargetRestorer.restore([first, second], against: [window(id: 9)])

        XCTAssertEqual(restoration.restored.count, 1)
        XCTAssertEqual(restoration.restored.first?.record.id, first.id)

        let unresolved = restoration.unresolved.first
        XCTAssertEqual(unresolved?.record.id, second.id)
        XCTAssertEqual(unresolved?.issue, .windowAlreadyClaimed)
    }

    func testOutcomeOrderFollowsSavedOrder() {
        let a = record(app: "Claude", bundle: "com.anthropic.claudefordesktop")
        let b = record(app: "ChatGPT", bundle: "com.openai.chat")
        let restoration = TargetRestorer.restore(
            [a, b],
            against: [window(id: 5, bundle: "com.openai.chat")]
        )

        guard case .unresolved(let first) = restoration.outcomes[0],
              case .restored(let second) = restoration.outcomes[1]
        else {
            return XCTFail("unexpected outcome order")
        }
        XCTAssertEqual(first.record.id, a.id)
        XCTAssertEqual(second.record.id, b.id)
    }

    func testEmptyRecordsProduceEmptyRestoration() {
        XCTAssertTrue(TargetRestorer.restore([], against: [window()]).outcomes.isEmpty)
    }
}
