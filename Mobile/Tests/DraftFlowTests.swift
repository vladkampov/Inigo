import XCTest
import UIKit
import InigoCore

@MainActor
final class DraftFlowTests: XCTestCase {
    func testReceiveAutomaticallyRefinesAndUndoRestoresExactOriginal() async throws {
        let controller = DraftViewController(); controller.loadViewIfNeeded()
        let complete = expectation(description: "rewrite called")
        controller.rewrite = { text, action in
            XCTAssertEqual(action, .refine); XCTAssertEqual(text, "Hello 🙂")
            complete.fulfill(); return "Hello there 🙂"
        }
        controller.receive("Hello 🙂")
        await fulfillment(of: [complete], timeout: 2)
        await Task.yield()
        XCTAssertEqual(controller.draft.text, "Hello there 🙂")
        controller.undoRewrite()
        XCTAssertEqual(controller.draft.text, "Hello 🙂")
    }
    func testTypingPreventsLateModelResultEvenIfProviderIgnoresCancellation() async throws {
        let controller = DraftViewController(); controller.loadViewIfNeeded()
        let started = expectation(description: "started")
        controller.rewrite = { _, _ in
            started.fulfill(); try? await Task.sleep(for: .milliseconds(150)); return "stale result"
        }
        controller.receive("original")
        await fulfillment(of: [started], timeout: 2)
        controller.draft.text = "my newer edit"; controller.textViewDidChange(controller.draft)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(controller.draft.text, "my newer edit")
    }
    func testFailurePreservesDraft() async throws {
        let controller = DraftViewController(); controller.loadViewIfNeeded()
        let complete = expectation(description: "failed")
        controller.rewrite = { _, _ in complete.fulfill(); throw InigoError.message("Model unavailable") }
        controller.receive("original")
        await fulfillment(of: [complete], timeout: 2); await Task.yield()
        XCTAssertEqual(controller.draft.text, "original")
        XCTAssertEqual(controller.status.text, "Model unavailable")
        XCTAssertTrue(controller.copyButton.isEnabled)
    }
    func testUndoDoesNotOverwriteLaterEdits() async throws {
        let controller = DraftViewController(); controller.loadViewIfNeeded()
        let complete = expectation(description: "done")
        controller.rewrite = { _, _ in complete.fulfill(); return "refined" }
        controller.receive("original")
        await fulfillment(of: [complete], timeout: 2); await Task.yield()
        controller.draft.text = "refined plus my edit"
        controller.undoRewrite()
        XCTAssertEqual(controller.draft.text, "refined plus my edit")
    }
}
