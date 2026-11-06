import XCTest
@testable import Inigo
final class ErrorReportsTests: XCTestCase {
    @MainActor func testOnlyConfiguredSentryIngestionIsAccepted() {
        XCTAssertNotNil(ErrorReports.endpoint("https://publickey@o123.ingest.us.sentry.io/456"))
        for value in ["http://key@o123.ingest.sentry.io/456","https://key@evil.example/456","https://key:secret@o123.ingest.sentry.io/456","https://key@o123.ingest.sentry.io/456?draft=private"] {
            XCTAssertNil(ErrorReports.endpoint(value))
        }
    }
}
