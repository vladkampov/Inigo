import XCTest
import InigoCore
@testable import Inigo

@MainActor
private final class DelayedRecognizer: LayoutRecognizing {
    var calls = 0
    var afterCheck: (() -> Void)?
    func recognition(_ text: String, language: String) async -> Double? {
        calls += 1
        await Task.yield()
        afterCheck?()
        return language == "en" ? 0 : 1
    }
}

final class LayoutDetectionTests: XCTestCase {
    @MainActor func testAutomaticRepairStartsOffAndPersistsOnlyExplicitOptIn() throws {
        let name = "inigo-layout-tests-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let preferences = Preferences(defaults: defaults)
        XCTAssertFalse(preferences.automaticLayoutRepair)
        XCTAssertFalse(preferences.automaticLayoutRepairPaused)
        preferences.automaticLayoutRepair = true
        XCTAssertTrue(Preferences(defaults: defaults).automaticLayoutRepair)
        preferences.automaticLayoutRepairPaused = true
        XCTAssertTrue(Preferences(defaults: defaults).automaticLayoutRepairPaused)
        preferences.automaticLayoutRepair = false
        XCTAssertFalse(Preferences(defaults: defaults).automaticLayoutRepair)
    }
    @MainActor func testFocusTypingAndSourceChangesInvalidatePendingDetection() async {
        for _ in ["typing", "focus", "layout", "excluded", "permission", "disabled"] {
            let recognizer = DelayedRecognizer()
            var current = true
            recognizer.afterCheck = { current = false }
            let result = await LayoutRepairDetector.detect("ghsdbn", caret: 6, language: "en",
                targets: [LayoutDetectionTarget(id: "uk", language: "uk", mapping: Dictionary(uniqueKeysWithValues: zip(Array("ghsdbn"), Array("привіт"))))],
                recognizer: recognizer, isCurrent: { current })
            XCTAssertNil(result)
            XCTAssertEqual(recognizer.calls, 1)
        }
    }
    @MainActor func testCancellationDuringCandidateCheckNeverReturnsARepair() async {
        let recognizer = DelayedRecognizer()
        var current = true
        recognizer.afterCheck = { if recognizer.calls == 2 { current = false } }
        let result = await LayoutRepairDetector.detect("ghsdbn", caret: 6, language: "en",
            targets: [LayoutDetectionTarget(id: "uk", language: "uk", mapping: Dictionary(uniqueKeysWithValues: zip(Array("ghsdbn"), Array("привіт"))))],
            recognizer: recognizer, isCurrent: { current })
        XCTAssertNil(result)
        XCTAssertEqual(recognizer.calls, 2)
    }
    func testDiagnosticDetailsContainOnlyFixedCategoriesAndNumbers() {
        var timing = OperationTiming(now: 0); timing.finish(.cancelled, now: 3_000_000)
        let details = OperationDetails(timing: timing, processing: .customLocal).summary(version: "secret/path")
        XCTAssertTrue(details.contains("development")); XCTAssertTrue(details.contains("cancelled"))
        XCTAssertFalse(details.contains("secret")); XCTAssertFalse(details.contains("path"))
    }
    @MainActor func testSystemLayoutsWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["INIGO_TEST_LAYOUTS"] == "1" else { throw XCTSkip("Opt-in macOS layout/spelling integration check.") }
        let catalog = InputSourceCatalog(), recognizer = SystemLayoutRecognizer()
        let source = try XCTUnwrap(catalog.sources.first { $0.id == "com.apple.keylayout.US" })
        let target = try XCTUnwrap(catalog.sources.first { $0.id == "com.apple.keylayout.Ukrainian" })
        let conversion = try XCTUnwrap(LayoutConversion("ghsdbn", caret: 6, mapping: catalog.mapping(from: source, to: target)))
        XCTAssertEqual(conversion.text, "привіт")
        let original = await recognizer.recognition("ghsdbn", language: try XCTUnwrap(source.language))
        let repaired = await recognizer.recognition(conversion.text, language: try XCTUnwrap(target.language))
        XCTAssertLessThanOrEqual(try XCTUnwrap(original), 0.2)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(repaired), 0.9)
    }
    @MainActor func testSystemPositiveAndNegativeCorpusWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["INIGO_TEST_LAYOUTS"] == "1" else { throw XCTSkip("Opt-in macOS spelling corpus.") }
        let catalog = InputSourceCatalog(), recognizer = SystemLayoutRecognizer()
        let us = try XCTUnwrap(catalog.sources.first { $0.id == "com.apple.keylayout.US" })
        let uk = try XCTUnwrap(catalog.sources.first { $0.id == "com.apple.keylayout.Ukrainian" })
        for (intended, source, target) in [("Привіт", us, uk), ("Привіт друзі", us, uk), ("garden", uk, us), ("Hello team", uk, us)] {
            let wrong = try XCTUnwrap(LayoutConversion(intended, caret: 0, mapping: catalog.mapping(from: target, to: source)))
            let result = await LayoutRepairDetector.detect(wrong.text, caret: wrong.text.utf16.count, language: try XCTUnwrap(source.language),
                targets: [LayoutDetectionTarget(id: target.id, language: try XCTUnwrap(target.language), mapping: catalog.mapping(from: source, to: target))],
                recognizer: recognizer, isCurrent: { true })
            XCTAssertEqual(result?.conversion.text, intended, "Failed synthetic recovery: \(intended)")
        }
        for draft in ["Hello team", "Vlad Kampov", "SELECT name FROM users", "let value = 123", "Hello привіт", "OK", "https://example.com", "hello @alice", "a@example.com"] {
            let result = await LayoutRepairDetector.detect(draft, caret: draft.utf16.count, language: try XCTUnwrap(us.language),
                targets: [LayoutDetectionTarget(id: uk.id, language: try XCTUnwrap(uk.language), mapping: catalog.mapping(from: us, to: uk))],
                recognizer: recognizer, isCurrent: { true })
            XCTAssertNil(result, "Unexpected conversion: \(draft)")
        }
    }
}
