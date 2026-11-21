import ArgusCore
import XCTest

@testable import ArgusCore

final class WindowMatchPolicyTests: XCTestCase {
    func testNoCandidatesNeverMatches() {
        XCTAssertEqual(WindowMatchPolicy.match(targetTitle: "ChatGPT", candidateTitles: []), .none)
    }

    func testSingleWindowIsUsedRegardlessOfTitle() {
        XCTAssertEqual(
            WindowMatchPolicy.match(targetTitle: "Old title", candidateTitles: ["New title"]),
            .unique(index: 0),
            "docs/02 §5.1 single-window fallback"
        )
    }

    func testUniqueTitleMatchSelectsThatWindow() {
        XCTAssertEqual(
            WindowMatchPolicy.match(
                targetTitle: "Release checklist",
                candidateTitles: ["Release checklist", "Other chat", "Notes"]
            ),
            .unique(index: 0)
        )
        XCTAssertEqual(
            WindowMatchPolicy.match(
                targetTitle: "Notes",
                candidateTitles: ["Release checklist", "Other chat", "Notes"]
            ),
            .unique(index: 2)
        )
    }

    func testSeveralWindowsWithoutTitleMatchStayUnresolved() {
        XCTAssertEqual(
            WindowMatchPolicy.match(
                targetTitle: "Release checklist",
                candidateTitles: ["Chat A", "Chat B"]
            ),
            .none
        )
    }

    func testDuplicateTitlesAreAmbiguous() {
        XCTAssertEqual(
            WindowMatchPolicy.match(
                targetTitle: "Claude",
                candidateTitles: ["Claude", "Claude"]
            ),
            .ambiguous(count: 2)
        )
    }

    func testWhitespaceAroundTitlesIsIgnored() {
        XCTAssertEqual(
            WindowMatchPolicy.match(
                targetTitle: "  Claude\n",
                candidateTitles: ["Chat A", "\tClaude "]
            ),
            .unique(index: 1)
        )
    }

    func testEmptyTargetTitleCannotDisambiguateSeveralWindows() {
        XCTAssertEqual(
            WindowMatchPolicy.match(targetTitle: "   ", candidateTitles: ["", "Chat"]),
            .none
        )
    }
}
