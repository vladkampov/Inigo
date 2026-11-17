import XCTest
@testable import Inigo

final class SpellingRecognitionTests: XCTestCase {
    func testUnsortedRangesAndWordBoundaries() throws {
        let score = try XCTUnwrap(SpellingRecognition.score(words: ["one", "two", "three"],
            misspelled: [NSRange(location: 8, length: 5), NSRange(location: 0, length: 3)]))
        XCTAssertEqual(score, 3.0 / 11.0, accuracy: 0.000001)
        XCTAssertEqual(SpellingRecognition.score(words: ["one", "two"], misspelled: [NSRange(location: 0, length: 4)]), 0.5)
    }
    func testPrefixOffsetUnicodeAndOverlappingErrors() throws {
        let unicode = try XCTUnwrap(SpellingRecognition.score(words: ["é", "привіт"],
            misspelled: [NSRange(location: 20, length: 6), NSRange(location: 0, length: 17)], offset: 18))
        XCTAssertEqual(unicode, 1.0 / 7.0, accuracy: 0.000001)
        let overlap = try XCTUnwrap(SpellingRecognition.score(words: ["one", "two", "three"],
            misspelled: [NSRange(location: 4, length: 3), NSRange(location: 0, length: 7)]))
        XCTAssertEqual(overlap, 5.0 / 11.0, accuracy: 0.000001)
    }
    func testNoWordsProducesNoEvidence() {
        XCTAssertNil(SpellingRecognition.score(words: [], misspelled: []))
    }
    func testFiveThousandMisspelledWordsAtDraftLimit() {
        let words = Array(repeating: "bad", count: 5_000)
        let ranges = (0..<5_000).reversed().map { NSRange(location: $0 * 4, length: 3) }
        XCTAssertEqual(words.joined(separator: " ").utf16.count, 19_999)
        XCTAssertEqual(SpellingRecognition.score(words: words, misspelled: ranges), 0)
        measure { _ = SpellingRecognition.score(words: words, misspelled: ranges) }
    }
}
