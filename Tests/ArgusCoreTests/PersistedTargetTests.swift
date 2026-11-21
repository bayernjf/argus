import ArgusCore
import XCTest

@testable import ArgusCore

final class PersistedTargetTests: XCTestCase {
    private func record() -> PersistedTarget {
        PersistedTarget(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            displayName: "ChatGPT",
            bundleIdentifier: "com.openai.chat",
            windowTitle: "Drafting a migration plan",
            note: "window #42"
        )
    }

    func testRoundTripKeepsIdentityAndOrder() throws {
        let file = TargetFile(targets: [record()])
        let data = try JSONEncoder().encode(file)
        let decoded = try JSONDecoder().decode(TargetFile.self, from: data)

        XCTAssertEqual(decoded, file)
        XCTAssertEqual(decoded.version, TargetFile.currentVersion)
    }

    func testUnknownVersionIsRejected() throws {
        var file = TargetFile(targets: [record()])
        file.version = 99
        let data = try JSONEncoder().encode(file)

        XCTAssertThrowsError(try JSONDecoder().decode(TargetFile.self, from: data)) { error in
            XCTAssertEqual(error as? TargetFileError, .unsupportedVersion(99))
        }
    }

    func testMakeTargetApplicationResetsVolatileState() {
        let saved = record()
        let target = saved.makeTargetApplication()
        XCTAssertEqual(target.id, saved.id)
        XCTAssertEqual(target.displayName, "ChatGPT")
        XCTAssertEqual(target.bundleIdentifier, "com.openai.chat")
        XCTAssertEqual(target.windowTitle, "Drafting a migration plan")
        XCTAssertEqual(target.note, "window #42")
        XCTAssertEqual(target.phase, .idle)
        XCTAssertNil(target.lastFrameAt, "a stale completed frame must not survive a relaunch")
    }

    func testInitFromTargetApplicationPreservesCardFields() {
        let target = TargetApplication(
            displayName: "Claude",
            bundleIdentifier: "com.anthropic.claudefordesktop",
            windowTitle: "Reviewing a release checklist",
            phase: .completed,
            lastFrameAt: Date(),
            note: "window #7"
        )
        let saved = PersistedTarget(target: target)
        XCTAssertEqual(saved.id, target.id)
        XCTAssertEqual(saved.displayName, target.displayName)
        XCTAssertEqual(saved.bundleIdentifier, target.bundleIdentifier)
        XCTAssertEqual(saved.windowTitle, target.windowTitle)
        XCTAssertEqual(saved.note, target.note)
    }

    func testTargetLimitAllowsThreeAndThenStops() {
        XCTAssertTrue(TargetLimits.allowsAnotherTarget(currentCount: 0))
        XCTAssertTrue(TargetLimits.allowsAnotherTarget(currentCount: 2))
        XCTAssertFalse(TargetLimits.allowsAnotherTarget(currentCount: TargetLimits.maximumMonitoredTargets))
    }
}
