import XCTest
@testable import InigoCore

final class ClipboardPolicyTests: XCTestCase {
    func testCompatibilityRoutingIsLimitedToKnownEditors() {
        XCTAssertTrue(ClipboardPolicy.prefersPaste(appID: "com.openai.codex"))
        XCTAssertTrue(ClipboardPolicy.prefersPaste(appID: "com.openai.chat"))
        XCTAssertFalse(ClipboardPolicy.prefersPaste(appID: "com.apple.TextEdit"))
        XCTAssertFalse(ClipboardPolicy.prefersPaste(appID: "com.tinyspeck.slackmacgap"))
    }
    func testRestoreOnlyOurOwnClipboardWrite() {
        XCTAssertTrue(ClipboardPolicy.shouldRestore(ownedChangeCount: 5, currentChangeCount: 5))
        XCTAssertFalse(ClipboardPolicy.shouldRestore(ownedChangeCount: 5, currentChangeCount: 6))
    }
    func testOversizedClipboardFailsClosedWithoutOverflow() {
        XCTAssertTrue(ClipboardPolicy.canSnapshot(sizes: [4, 6], limit: 10))
        XCTAssertFalse(ClipboardPolicy.canSnapshot(sizes: [4, 7], limit: 10))
        XCTAssertFalse(ClipboardPolicy.canSnapshot(sizes: [Int.max, 1], limit: 10))
        XCTAssertFalse(ClipboardPolicy.canSnapshot(sizes: [-1], limit: 10))
    }
}
