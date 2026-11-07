import XCTest
import InigoCore

@MainActor
final class MobileTranslationTests: XCTestCase {
    func testSameLanguagePreservesExactOriginalWithoutModels() async throws {
        let text = "Please send an update by Friday. 🙂 https://example.com/spec?id=7"
        let result = try await MobileTranslationService.translate(text, to: .en)
        XCTAssertEqual(result, text)
    }
    func testCancelledTranslationDoesNotBeginWork() async {
        let task = Task {
            return try await MobileTranslationService.translate("Please send an update.", to: .pl)
        }
        task.cancel()
        do { _ = try await task.value; XCTFail("Cancelled request returned a translation") }
        catch { XCTAssertTrue(error is CancellationError) }
    }
}
