import ArgusCore
import XCTest
@testable import Argus

final class ReplyProfileRegistryTests: XCTestCase {
    func testDoubaoWorkUsesCalibratedProfile() {
        let profile = ReplyProfileRegistry.profileForBundle("com.work.pc.doubao")
        XCTAssertEqual(profile.id, "doubao-work")
        XCTAssertEqual(profile.bundleIdentifier, "com.work.pc.doubao")
        XCTAssertEqual(profile.replyROI?.x, 0.17)
        XCTAssertEqual(profile.replyROI?.y, 0.08)
        XCTAssertEqual(profile.controlROI?.x, 0.88)
        XCTAssertEqual(profile.settleDuration, 1.0)
    }

    func testUnknownBundleFallsBackToGeneric() {
        let profile = ReplyProfileRegistry.profileForBundle("com.example.unknown")
        XCTAssertEqual(profile, .generic)
    }
}
