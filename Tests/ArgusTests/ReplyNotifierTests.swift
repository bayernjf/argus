import XCTest
@testable import Argus

final class ReplyNotifierTests: XCTestCase {
    func testCompletedMessageUsesTargetNameOnly() {
        let message = ReplyNotificationMessage.completed(displayName: "豆包工作")

        XCTAssertEqual(message.title, "回复完成")
        XCTAssertEqual(message.body, "豆包工作 已完成回复")
        XCTAssertFalse(message.body.contains("收到"))
    }

    func testCompletedMessageFallsBackForBlankName() {
        let message = ReplyNotificationMessage.completed(displayName: "   ")

        XCTAssertEqual(message.title, "回复完成")
        XCTAssertEqual(message.body, "目标 已完成回复")
    }
}
