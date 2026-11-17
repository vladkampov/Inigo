import XCTest
@testable import InigoCore

final class OperationTimingTests: XCTestCase {
    func testRetryStagesAccumulateAndFinishIsIdempotent() {
        var timing = OperationTiming(now: 0)
        timing.transition(.generate, now: 1_000_000)
        timing.transition(.validate, now: 4_000_000)
        timing.transition(.generate, now: 5_000_000)
        timing.transition(.insert, now: 7_000_000)
        timing.finish(.replaced, now: 8_000_000)
        timing.finish(.failed, now: 20_000_000)
        XCTAssertEqual(timing.milliseconds[.capture], 1)
        XCTAssertEqual(timing.milliseconds[.generate], 5)
        XCTAssertEqual(timing.milliseconds[.validate], 1)
        XCTAssertEqual(timing.milliseconds[.insert], 1)
        XCTAssertEqual(timing.totalMilliseconds, 8)
        XCTAssertEqual(timing.outcome, .replaced)
    }
}
