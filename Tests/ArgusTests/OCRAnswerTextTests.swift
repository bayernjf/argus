import CoreGraphics
import XCTest
@testable import Argus

final class OCRAnswerTextTests: XCTestCase {
    func testKeepsOnlyTextBelowLatestRightAlignedPrompt() {
        let lines: [OCRRecognizer.Line] = [
            .init(text: "old answer", bounds: CGRect(x: 0.05, y: 0.80, width: 0.70, height: 0.05)),
            .init(text: "new prompt", bounds: CGRect(x: 0.45, y: 0.65, width: 0.40, height: 0.05)),
            .init(text: "new answer", bounds: CGRect(x: 0.05, y: 0.30, width: 0.70, height: 0.05)),
        ]
        XCTAssertEqual(OCRRecognizer.answerText(from: lines), "new answer")
    }

    func testNoPromptKeepsAllText() {
        let lines: [OCRRecognizer.Line] = [
            .init(text: "first", bounds: CGRect(x: 0.05, y: 0.80, width: 0.70, height: 0.05)),
            .init(text: "second", bounds: CGRect(x: 0.05, y: 0.70, width: 0.70, height: 0.05)),
        ]
        XCTAssertEqual(OCRRecognizer.answerText(from: lines), "first\nsecond")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(OCRRecognizer.answerText(from: []), "")
    }
}
