import XCTest
import InigoCore

final class MobilePreferencesTests: XCTestCase {
    private func fixture(_ body: (MobilePreferences, MobilePreferences, URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(MobilePreferences(directory: dir), MobilePreferences(directory: dir), dir)
    }
    func testAppAndExtensionReadLatestSettingsWithoutLosingOtherChanges() throws {
        try fixture { app, ext, _ in
            try app.update { $0.interfaceLanguage = "uk" }
            try ext.update { $0.translationLanguage = "pl" }
            XCTAssertEqual(app.state.translationLanguage, "pl")
            XCTAssertEqual(ext.state.interfaceLanguage, "uk")
        }
    }
    func testConcurrentWritersPreserveEvidence() throws {
        try fixture { app, _, dir in
            let group = DispatchGroup()
            for _ in 0..<8 {
                group.enter()
                DispatchQueue.global().async {
                    defer { group.leave() }
                    let store = MobilePreferences(directory: dir)
                    do { try store.update { state in
                        let old = state.profile.evidence["en"]?["shorterSentences"] ?? 0
                        Thread.sleep(forTimeInterval: 0.005)
                        state.profile.evidence["en", default: [:]]["shorterSentences"] = old + 1
                    } } catch { XCTFail("Concurrent preference write failed") }
                }
            }
            XCTAssertEqual(group.wait(timeout: .now() + 3), .success)
            XCTAssertEqual(app.state.profile.evidence["en"]?["shorterSentences"], 8)
        }
    }
    func testLearningIsPerLanguageAndStoresNoWriting() throws {
        try fixture { app, ext, dir in
            let source = "Synthetic private draft marker: please send an update when you have a moment!!!"
            for _ in 0..<3 { try app.observeCopy(original: source, result: "Please update.", language: "en") }
            XCTAssertFalse(ext.state.profile.preferences(for: "en").isEmpty)
            XCTAssertTrue(ext.state.profile.preferences(for: "pl").isEmpty)
            let saved = try String(contentsOf: dir.appendingPathComponent("settings.json"), encoding: .utf8)
            XCTAssertFalse(saved.contains(source)); XCTAssertFalse(saved.contains("Please update."))
            try app.update { $0.learning = false; $0.interfaceLanguage = "pl" }
            try ext.observeCopy(original: source, result: "Update.", language: "en")
            XCTAssertEqual(app.state.profile.evidence["en"]?["shorterSentences"], 3)
            try ext.resetStyle()
            XCTAssertTrue(app.state.profile.evidence.isEmpty)
            XCTAssertEqual(app.state.interfaceLanguage, "pl")
            XCTAssertFalse(app.state.learning)
        }
    }
    func testClosedVocabularyAndBoundedEvidence() throws {
        try fixture { app, _, _ in
            try app.update { state in
                state.interfaceLanguage = "invalid"; state.translationLanguage = "invalid"
                state.profile.evidence = ["en": ["shorterSentences": 900, "conversation fact": 4], "invalid": ["shorterSentences": 4]]
            }
            XCTAssertEqual(app.state.interfaceLanguage, "system")
            XCTAssertEqual(app.state.translationLanguage, "en")
            XCTAssertEqual(app.state.profile.evidence, ["en": ["shorterSentences": 20]])
        }
    }
    func testCorruptStoreIsNotOverwritten() throws {
        try fixture { app, _, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let file = dir.appendingPathComponent("settings.json")
            try Data("corrupt".utf8).write(to: file)
            XCTAssertThrowsError(try app.update { $0.learning = false })
            XCTAssertEqual(try Data(contentsOf: file), Data("corrupt".utf8))
        }
    }
}
