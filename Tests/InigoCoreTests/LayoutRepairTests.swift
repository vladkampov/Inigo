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
    func testURLSchemesAreProtectedRegardlessOfCase() throws {
        for scheme in ["http", "HTTP", "Http", "https", "HTTPS", "Https"] {
            let url = scheme + "://EXAMPLE.com/CaseSensitive/Path?Key=Value#Fragment"
            let draft = "ghsdbn " + url
            let converted = try XCTUnwrap(LayoutConversion(draft, caret: draft.utf16.count, mapping: mapping))
            XCTAssertEqual(converted.text, "привіт " + url)
            XCTAssertEqual(LayoutConversion.proseWords(draft), ["ghsdbn"])
            XCTAssertEqual(LayoutConversion.proseWords(converted.text), ["привіт"])
        }
    }
    func testInteriorCaretOffsetsInUnchangedEmojiArePreserved() throws {
        for (emoji, offsets) in [("👩‍💻", [0, 2, 3, 5]), ("🇺🇦", [0, 2, 4]), ("👍🏽", [0, 2, 4])] {
            for caret in offsets {
                let converted = try XCTUnwrap(LayoutConversion(emoji + "ghsdbn", caret: caret, mapping: mapping))
                XCTAssertEqual(converted.text, emoji + "привіт")
                XCTAssertEqual(converted.caret, caret)
            }
        }
    }
    func testInteriorCaretInProtectedCombiningSequenceIsPreserved() throws {
        let prefix = "https://example.com/", draft = prefix + "e\u{301} ghsdbn"
        let caret = prefix.utf16.count + 1
        let converted = try XCTUnwrap(LayoutConversion(draft, caret: caret, mapping: mapping))
        XCTAssertEqual(converted.text, prefix + "e\u{301} привіт")
        XCTAssertEqual(converted.caret, caret)
    }
    func testInteriorCaretInChangedGraphemeIsRejected() throws {
        var custom = mapping; custom["e\u{301}"] = "x"
        XCTAssertNil(LayoutConversion("e\u{301}ghsdbn", caret: 1, mapping: custom))
        let boundary = try XCTUnwrap(LayoutConversion("e\u{301}ghsdbn", caret: 2, mapping: custom))
        XCTAssertEqual(boundary.text, "xпривіт"); XCTAssertEqual(boundary.caret, 1)
        custom["e\u{301}"] = "e\u{301}"
        XCTAssertEqual(LayoutConversion("e\u{301}ghsdbn", caret: 1, mapping: custom)?.caret, 1)
    }
    private var protectedStressDraft: String {
        let unit = "ghsdbn @alice ", repetitions = 20_000 / unit.utf16.count
        let text = String(repeating: unit, count: repetitions)
        return text + String(repeating: " ", count: 20_000 - text.utf16.count)
    }
    func testMaximumLengthDraftPreservesManyProtectedSpans() throws {
        let draft = protectedStressDraft
        XCTAssertEqual(draft.utf16.count, LayoutRepairPolicy.maximumLength)
        let converted = try XCTUnwrap(LayoutConversion(draft, caret: 20_000, mapping: mapping))
        XCTAssertEqual(converted.text, draft.replacingOccurrences(of: "ghsdbn", with: "привіт"))
        XCTAssertEqual(converted.caret, 20_000)
        XCTAssertEqual(LayoutConversion.protectedRanges(draft).count, 20_000 / "ghsdbn @alice ".utf16.count)
        XCTAssertTrue(LayoutConversion.proseWords(draft).allSatisfy { $0 == "ghsdbn" })
        XCTAssertEqual(LayoutConversion.proseWords(draft).count, LayoutConversion.protectedRanges(draft).count)
    }
    func testConversionPerformanceOnProtectedMaximumDraft() {
        let draft = protectedStressDraft, mapping = self.mapping
        measure { _ = LayoutConversion(draft, caret: 20_000, mapping: mapping) }
    }
    func testProseExtractionPerformanceOnProtectedMaximumDraft() {
        let draft = protectedStressDraft
        measure { _ = LayoutConversion.proseWords(draft) }
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
