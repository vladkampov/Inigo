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
    func testTranslationPickerStartsChosenLanguageAfterDismissal() async throws {
        let controller = DraftViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = controller; window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded(); controller.draft.text = "A synthetic draft"
        let translated = expectation(description: "chosen target starts translation")
        controller.rewrite = { text, action in
            XCTAssertEqual(text, "A synthetic draft")
            XCTAssertEqual(action, .translate(.uk))
            translated.fulfill(); return "Синтетична чернетка"
        }
        controller.translationTargets = { SupportedLanguage.allCases }
        controller.showTranslationPicker()
        try await Task.sleep(for: .milliseconds(400))
        let navigation = try XCTUnwrap(controller.presentedViewController as? UINavigationController)
        let picker = try XCTUnwrap(navigation.topViewController as? MobileLanguagePicker)
        picker.loadViewIfNeeded()
        for _ in 0..<50 {
            if picker.tableView(picker.tableView, numberOfRowsInSection: 0) > 0 { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let row = try XCTUnwrap(SupportedLanguage.allCases.firstIndex(of: .uk))
        picker.tableView(picker.tableView, didSelectRowAt: IndexPath(row: row, section: 0))
        await fulfillment(of: [translated], timeout: 3)
        await Task.yield()
        XCTAssertEqual(controller.draft.text, "Синтетична чернетка")
    }

}
