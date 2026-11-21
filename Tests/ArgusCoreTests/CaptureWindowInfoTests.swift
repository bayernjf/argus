import CoreGraphics
import XCTest

@testable import ArgusCore

final class CaptureWindowInfoTests: XCTestCase {
    private let ownBundleID = "com.bayernjf.argus"

    private func window(
        id: UInt32 = 1,
        app: String = "ChatGPT",
        bundle: String = "com.openai.chat",
        title: String = "ChatGPT",
        width: CGFloat = 1200,
        height: CGFloat = 800
    ) -> CaptureWindowInfo {
        CaptureWindowInfo(
            id: id,
            appName: app,
            appBundleIdentifier: bundle,
            windowTitle: title,
            frame: CGRect(x: 0, y: 0, width: width, height: height)
        )
    }

    func testValidTargetsKeepsRegularWindows() {
        let windows = [window(), window(id: 2, app: "Claude", bundle: "com.anthropic.claudefordesktop")]
        let valid = CaptureWindowInfo.validTargets(from: windows, ownBundleIdentifier: ownBundleID)
        XCTAssertEqual(valid.map(\.id), [1, 2])
    }

    func testValidTargetsDropsArgusOwnWindows() {
        let windows = [window(app: "Argus", bundle: ownBundleID)]
        XCTAssertTrue(CaptureWindowInfo.validTargets(from: windows, ownBundleIdentifier: ownBundleID).isEmpty)
    }

    func testValidTargetsDropsTinyWindows() {
        let windows = [
            window(id: 1, width: 100, height: 800),
            window(id: 2, height: 40),
        ]
        XCTAssertTrue(CaptureWindowInfo.validTargets(from: windows, ownBundleIdentifier: ownBundleID).isEmpty)
    }

    func testValidTargetsKeepsWindowAtMinimumSize() {
        let windows = [window(width: CaptureWindowInfo.minimumContentSize, height: CaptureWindowInfo.minimumContentSize)]
        XCTAssertEqual(CaptureWindowInfo.validTargets(from: windows, ownBundleIdentifier: ownBundleID).count, 1)
    }

    func testMakeTargetMapsWindowFields() {
        let target = window(id: 42, app: "ChatGPT", bundle: "com.openai.chat", title: "ChatGPT — main").makeTarget()
        XCTAssertEqual(target.displayName, "ChatGPT")
        XCTAssertEqual(target.bundleIdentifier, "com.openai.chat")
        XCTAssertEqual(target.windowTitle, "ChatGPT — main")
        XCTAssertEqual(target.phase, .idle)
        XCTAssertNil(target.lastFrameAt)
        XCTAssertEqual(target.note, "window #42")
    }

    func testMakeTargetAssignsFreshIdentityPerCall() {
        let source = window()
        XCTAssertNotEqual(source.makeTarget().id, source.makeTarget().id)
    }
}
