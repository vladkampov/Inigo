import XCTest
@testable import InigoCore

final class LayoutRepairTests: XCTestCase {
    private let latin = Array("qwertyuiop[]asdfghjkl;'zxcvbnm,./QWERTYUIOP{}ASDFGHJKL:\"ZXCVBNM<>?")
    private let ukrainian = Array("йцукенгшщзхїфивапролджєячсмітьбю.ЙЦУКЕНГШЩЗХЇФИВАПРОЛДЖЄЯЧСМІТЬБЮ,")
    private var mapping: [Character: Character] { Dictionary(uniqueKeysWithValues: zip(latin, ukrainian)) }
    func testUkrainianRoundTripCasePunctuationCaretAndEmoji() throws {
        let draft = "Ghsdbn ghsdbn 👋"
        let converted = try XCTUnwrap(LayoutConversion(draft, caret: 7, mapping: mapping))
        XCTAssertEqual(converted.text, "Привіт привіт 👋")
        XCTAssertEqual(converted.caret, 7)
        let inverse = Dictionary(uniqueKeysWithValues: zip(ukrainian, latin))
        XCTAssertEqual(LayoutConversion(converted.text, caret: converted.caret, mapping: inverse)?.text, draft)
        XCTAssertEqual(LayoutConversion(";.;.;.", caret: 6, mapping: mapping)?.text, "жюжюжю")
    }
    func testProtectedObjectsRemainExact() throws {
        let draft = "ghsdbn https://example.com/a?q=1 @alice <@U123> a@example.com `code()` 👋"
        let output = try XCTUnwrap(LayoutConversion(draft, caret: draft.utf16.count, mapping: mapping))
        XCTAssertEqual(output.text, draft.replacingOccurrences(of: "ghsdbn", with: "привіт"))
        XCTAssertEqual(LayoutConversion.proseWords(draft), ["ghsdbn"])
    }
    func testUnsupportedAndInvalidUnicodeBoundariesAreRejected() {
        XCTAssertNil(LayoutConversion("ghsdbn é", caret: 0, mapping: mapping))
        XCTAssertNil(LayoutConversion("👋ghsdbn", caret: 1, mapping: mapping))
        XCTAssertNil(LayoutConversion("👋", caret: 2, mapping: mapping))
    }
    private func candidate(_ text: String = "ghsdbn", id: String = "uk", score: Double = 1) -> LayoutRepairCandidate {
        LayoutRepairCandidate(sourceID: id, conversion: LayoutConversion(text, caret: 0, mapping: mapping)!, recognition: score)
    }
    func testConservativeThresholdsAndUnavailableEvidence() {
        XCTAssertNotNil(LayoutRepairPolicy.winner(original: "ghsdbn", recognition: 0, candidates: [candidate()]))
        for score: Double? in [nil, 0.21, 1, .nan, -.infinity] {
            XCTAssertNil(LayoutRepairPolicy.winner(original: "ghsdbn", recognition: score, candidates: [candidate()]))
        }
        XCTAssertNil(LayoutRepairPolicy.winner(original: "ghsdbn", recognition: 0, candidates: [candidate(score: 0.89)]))
        XCTAssertNil(LayoutRepairPolicy.winner(original: "hi", recognition: 0, candidates: [candidate()]))
        XCTAssertNil(LayoutRepairPolicy.winner(original: String(repeating: "x", count: 20_001), recognition: 0, candidates: [candidate()]))
    }
    func testDistinctCandidateTieIsRejectedButEquivalentLayoutsAreDeduplicated() {
        XCTAssertNil(LayoutRepairPolicy.winner(original: "ghsdbn", recognition: 0, candidates: [candidate(), candidate("ghsdbnq", id: "other", score: 0.9)]))
        XCTAssertNotNil(LayoutRepairPolicy.winner(original: "ghsdbn", recognition: 0, candidates: [candidate(), candidate(id: "duplicate")]))
    }
    func testCorrectAndMixedDraftEvidencePreventsConversion() {
        for draft in ["Hello team", "Some correct words ghsdbn", "SELECT name FROM users", "Vlad Kampov", "Hello привіт"] {
            XCTAssertNil(LayoutRepairPolicy.winner(original: draft, recognition: 0.5, candidates: [candidate()]))
        }
    }
}
