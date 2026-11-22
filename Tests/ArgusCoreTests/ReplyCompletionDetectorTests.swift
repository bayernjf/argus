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

    func testGeneratingReopensSettlingReply() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
        XCTAssertEqual(detector.observe(.generating, at: t0.addingTimeInterval(0.3)), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.4)), .settling)
    }

    func testGeneratingReopensCompletedReply() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.8)), .completed)
        XCTAssertEqual(detector.observe(.generating, at: t0.addingTimeInterval(1.0)), .streaming)
    }

    func testUnknownNeverClaimsCompletionAndKeepsGeneratingHistory() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.unknown, at: t0.addingTimeInterval(0.1)), .unknown)
        // A transient signal loss must not erase the fact that generation was
        // seen. Recovery to a quiet frame starts a fresh settle window first.
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .settling)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.6)), .completed)
    }

    func testUnknownBeforeGenerationStaysIdleAfterRecovery() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.unknown, at: t0), .unknown)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .idle)
    }

    func testPhaseChangedAtTracksTransitions() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertNil(detector.phaseChangedAt)
        detector.observe(.generating, at: t0)
        XCTAssertEqual(detector.phaseChangedAt, t0)
        detector.observe(.generating, at: t0.addingTimeInterval(0.2))
        XCTAssertEqual(detector.phaseChangedAt, t0)
        detector.observe(.idle, at: t0.addingTimeInterval(0.3))
        XCTAssertEqual(detector.phaseChangedAt, t0.addingTimeInterval(0.3))
    }

    func testObservationRequiresConfidenceFloor() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        let low = ReplyObservation(isChanging: false, confidence: 0.2)
        XCTAssertEqual(detector.observe(low, at: t0), .unknown)
        XCTAssertNotEqual(detector.phase, .completed)
    }

    func testGeneratingIndicatorOverridesStableText() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        let observation = ReplyObservation(
            isChanging: false,
            hasGeneratingIndicator: true,
            confidence: 0.95,
            source: .fused
        )
        XCTAssertEqual(detector.observe(observation, at: t0), .streaming)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(0.1)), .settling)
    }

    func testProfileSettleDurationIsUsedByDetector() {
        var detector = ReplyCompletionDetector(settleDuration: 2.0)
        let profile = ReplyProfile(id: "slow", settleDuration: 2.0)
        XCTAssertEqual(
            detector.observe(ReplyObservation(isChanging: true, confidence: 0.9), profile: profile, at: t0),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(ReplyObservation(isChanging: false, confidence: 0.9), profile: profile, at: t0.addingTimeInterval(0.1)),
            .settling
        )
        XCTAssertEqual(
            detector.observe(ReplyObservation(isChanging: false, confidence: 0.9), profile: profile, at: t0.addingTimeInterval(2.1)),
            .completed
        )
    }

    func testIdleWithoutSignalStaysIdle() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.idle, at: t0), .idle)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(2.0)), .idle)
    }

    func testQuietTextWithoutGrowthDoesNotComplete() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        let unchanged = ReplyObservation(
            isChanging: false,
            textFingerprint: "old-reply",
            confidence: 0.9
        )
        let generating = ReplyObservation(
            isChanging: true,
            textFingerprint: "old-reply",
            confidence: 0.9
        )

        // Seed the pre-generation fingerprint; a Stop control appears while
        // the visible text is unchanged (the thinking-dots case).
        XCTAssertEqual(detector.observe(unchanged, at: t0), .idle)
        XCTAssertEqual(detector.observe(generating, at: t0.addingTimeInterval(0.1)), .streaming)
        XCTAssertEqual(detector.observe(unchanged, at: t0.addingTimeInterval(0.8)), .settling)
        XCTAssertEqual(detector.observe(unchanged, at: t0.addingTimeInterval(2.0)), .settling)
        XCTAssertEqual(detector.phase, .settling)
    }

    func testShortReplyBetweenSamplesCompletes() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "old-reply", confidence: 0.9),
                at: t0
            ),
            .idle
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "old-reply+new", confidence: 0.9),
                at: t0.addingTimeInterval(0.1)
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "old-reply+new", confidence: 0.9),
                at: t0.addingTimeInterval(0.2)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "old-reply+new", confidence: 0.9),
                at: t0.addingTimeInterval(0.8)
            ),
            .completed
        )
    }

    func testTextGrowthAllowsCompletion() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "prompt", confidence: 0.9),
                at: t0
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply", confidence: 0.9),
                at: t0.addingTimeInterval(0.1)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply", confidence: 0.9),
                at: t0.addingTimeInterval(0.8)
            ),
            .completed
        )
    }

    func testNewGenerationResetsTextBaseline() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "prompt", confidence: 0.9),
                at: t0
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply", confidence: 0.9),
                at: t0.addingTimeInterval(0.1)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply", confidence: 0.9),
                at: t0.addingTimeInterval(0.8)
            ),
            .completed
        )
        // A second prompt starts a fresh generation; the previous reply is the
        // new baseline, so quiet thinking text must not immediately complete.
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "prompt+reply+prompt2", confidence: 0.9),
                at: t0.addingTimeInterval(1.0)
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply+prompt2", confidence: 0.9),
                at: t0.addingTimeInterval(1.1)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "prompt+reply+prompt2+reply2", confidence: 0.9),
                at: t0.addingTimeInterval(1.8)
            ),
            .completed
        )
    }

    func testEmptyAnswerRegionMakesRepeatedShortReplyNew() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textRegionEmpty: true, confidence: 0.9),
                at: t0
            ),
            .idle
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(0.1)
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(0.8)
            ),
            .settling
        )

        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(1.4)
            ),
            .completed
        )

        // The next answer is identical, but the prompt observation saw an
        // empty answer region; that must reset the text baseline.
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(
                    isChanging: true,
                    textRegionEmpty: true,
                    confidence: 0.9
                ),
                at: t0.addingTimeInterval(1.6)
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(1.7)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(2.4)
            ),
            .completed
        )
    }

    func testNewPromptResetsBaselineWhenAnswerArrivesInSameSample() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: true, textFingerprint: "收到", confidence: 0.9),
                at: t0
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(0.1)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(0.7)
            ),
            .completed
        )

        // A repeated prompt plus its identical answer can arrive in one
        // sample. The prompt itself is the new-generation evidence.
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(
                    isChanging: true,
                    textFingerprint: "收到",
                    newPrompt: true,
                    confidence: 0.9
                ),
                at: t0.addingTimeInterval(1.0)
            ),
            .streaming
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(1.1)
            ),
            .settling
        )
        XCTAssertEqual(
            detector.observe(
                ReplyObservation(isChanging: false, textFingerprint: "收到", confidence: 0.9),
                at: t0.addingTimeInterval(1.7)
            ),
            .completed
        )
    }

    func testResetReturnsToIdle() {
        var detector = ReplyCompletionDetector(settleDuration: 0.5)
        XCTAssertEqual(detector.observe(.generating, at: t0), .streaming)
        detector.reset()
        XCTAssertEqual(detector.phase, .idle)
        XCTAssertEqual(detector.observe(.idle, at: t0.addingTimeInterval(1.0)), .idle)
    }
}
