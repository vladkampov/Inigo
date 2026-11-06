import XCTest
@testable import InigoCore
final class DiagnosticEventTests: XCTestCase {
    func testOnlyAllowlistedFieldsAndNoRawText() throws {
        let event = DiagnosticEvent(code:.rewriteFailed,version:"0.2.0",osMajor:26)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(event)) as? [String:Any])
        XCTAssertEqual(Set(json.keys),Set(["event_id","level","platform","message","release","tags"]))
        XCTAssertEqual(json["message"] as? String,"rewrite_failed")
        XCTAssertEqual(json["release"] as? String,"Inigo@0.2.0")
        XCTAssertEqual(json["tags"] as? [String:String],["os_major":"26"])
    }
    func testVersionCannotCarryArbitraryContent() {
        let event = DiagnosticEvent(code:.rewriteFailed,version:"private draft /Users/example",osMajor:26)
        XCTAssertEqual(event.release,"Inigo@development")
    }
}
