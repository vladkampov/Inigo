import XCTest
@testable import InigoCore

final class WriteVerificationTests: XCTestCase {
    func testDelayedEditorUpdateIsConfirmedWithoutSecondWrite() async {
        var reads = 0
        let result = await WriteVerification.verify(read: { reads += 1; return reads < 4 ? .original : .expected }, pause: {})
        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(reads, 4)
    }
    func testIgnoredWriteIsNeverReportedAsSuccess() async {
        var reads = 0
        let result = await WriteVerification.verify(attempts: 5, read: { reads += 1; return .original }, pause: {})
        XCTAssertEqual(result, .unconfirmed)
        XCTAssertEqual(reads, 5)
    }
    func testConcurrentUserEditStopsVerificationImmediately() async {
        var reads = 0
        let result = await WriteVerification.verify(read: { reads += 1; return .different }, pause: {})
        XCTAssertEqual(result, .interrupted)
        XCTAssertEqual(reads, 1)
    }
    func testTemporarilyUnavailableReadbackCanRecover() async {
        var reads = 0
        let result = await WriteVerification.verify(read: { reads += 1; return reads < 3 ? .unavailable : .expected }, pause: {})
        XCTAssertEqual(result, .confirmed)
    }
    func testCancellationDoesNotConfirmOrRetry() async {
        let result = await WriteVerification.verify(read: { .original }, pause: { throw CancellationError() })
        XCTAssertEqual(result, .interrupted)
    }
}
