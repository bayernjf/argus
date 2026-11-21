import XCTest
@testable import ArgusCore

final class LumaGridTests: XCTestCase {
    func testIdenticalGridsHaveNoChange() {
        let grid = LumaGrid(width: 2, height: 2, pixels: [0, 10, 20, 30])
        XCTAssertEqual(grid.changedPixelRatio(comparedTo: grid), 0)
    }

    func testChangedPixelRatioUsesPerPixelThreshold() {
        let a = LumaGrid(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let b = LumaGrid(width: 2, height: 2, pixels: [40, 4, 0, 0])
        XCTAssertEqual(b.changedPixelRatio(comparedTo: a, perPixelThreshold: 8), 0.25)
    }

    func testMismatchedDimensionsReturnNil() {
        let a = LumaGrid(width: 2, height: 2, pixels: [0, 0, 0, 0])
        let b = LumaGrid(width: 3, height: 1, pixels: [0, 0, 0])
        XCTAssertNil(b.changedPixelRatio(comparedTo: a))
    }
}

final class ReplyProfileTests: XCTestCase {
    func testNormalizedRectClampsToImage() {
        let rect = NormalizedRect(x: -0.2, y: 0.9, width: 0.4, height: 0.4)
        let clamped = rect.clamped()
        XCTAssertEqual(clamped?.x, 0)
        XCTAssertEqual(clamped?.y, 0.9)
        XCTAssertEqual(clamped?.width, 0.2)
        XCTAssertEqual(clamped?.height ?? 0, 0.1, accuracy: 0.0001)
    }

    func testEmptyNormalizedRectReturnsNil() {
        XCTAssertNil(NormalizedRect(x: 1, y: 0, width: 0, height: 1).clamped())
        XCTAssertNil(NormalizedRect(x: 1, y: 0, width: 0.5, height: 1).clamped())
    }

    func testStopKeywordsRequireControlROI() {
        let generic = ReplyProfile.generic
        XCTAssertFalse(generic.contains(stopControlIn: "Stop generating"))

        let profile = ReplyProfile(
            id: "fixture",
            controlROI: NormalizedRect(x: 0, y: 0.8, width: 1, height: 0.2),
            stopKeywords: ["Stop", "停止"]
        )
        XCTAssertTrue(profile.contains(stopControlIn: "⏹ Stop generating"))
        XCTAssertTrue(profile.contains(stopControlIn: "停止生成"))
        XCTAssertFalse(profile.contains(stopControlIn: "The answer stops here"))
    }
}

final class TargetPhaseTimestampTests: XCTestCase {
    func testOlderTargetJSONWithoutPhaseTimestampStillDecodes() throws {
        let json = """
        {
          "id": "9B6C03C6-FCFF-452C-A171-4A3016A3A3A1",
          "displayName": "Old",
          "bundleIdentifier": "com.example.old",
          "windowTitle": "Old Window",
          "phase": "completed"
        }
        """.data(using: .utf8)!
        let target = try JSONDecoder().decode(TargetApplication.self, from: json)
        XCTAssertEqual(target.phase, .completed)
        XCTAssertNil(target.phaseChangedAt)
    }
}
