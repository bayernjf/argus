import XCTest
@testable import ArgusCore

final class ReplyCompletionDetectorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000)

    func testStartsIdle() {
        let detector = ReplyCompletionDetector()
        XCTAssertEqual(detector.phase, .idle)
    }

    func testGeneratingThenIdleSettlesThenCompletes() {
        var detector = ReplyCompletionDetector(settleDuration: 1.0)

        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.6)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(1.2)), .completed)
        XCTAssertEqual(detector.phase, .completed)
    }

    func testCompletedDoesNotReopenOnIdle() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.8)), .completed)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .completed)
    }

    func testGeneratingReopensCompletedReply() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.8)), .completed)
        XCTAssertEqual(detector.observe(.generating, at: t0.addingTimeInterval(1.0)), .streaming)
    }

    func testUnknownNeverClaimsCompletion() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.unknown, at: t0.addingTimeInterval(0.1)), .unknown)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .idle)
    }

    func testIdleWithoutSignalStaysIdle() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.idle, at: t0), .idle)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .idle)
    }

    func testResetReturnsToIdle() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        detector.reset()
        XCTAssertEqual(detector.phase, .idle)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(1.0)), .idle)
    }
}
