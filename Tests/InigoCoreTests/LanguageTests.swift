import XCTest
@testable import InigoCore

final class LanguageTests: XCTestCase {
    func testCatalogAndRequiredLanguages() {
        XCTAssertEqual(SupportedLanguage.allCases.count,24)
        XCTAssertNil(SupportedLanguage(rawValue:"ru"))
        XCTAssertEqual(SupportedLanguage.resolve(override:"ru",preferred:["en-US"]),.en)
        for code in ["en","pl","uk"] { XCTAssertNotNil(SupportedLanguage(rawValue:code)) }
    }
    func testSystemPreferenceOrderAndOverride() {
        XCTAssertEqual(SupportedLanguage.resolve(override:"system",preferred:["xx-ZZ","uk-UA","en-US"]),.uk)
        XCTAssertEqual(SupportedLanguage.resolve(override:"pl",preferred:["de-DE"]),.pl)
        XCTAssertEqual(SupportedLanguage.resolve(override:"system",preferred:["pt_BR"]),.pt)
        XCTAssertEqual(SupportedLanguage.resolve(override:"invalid",preferred:["xx"]),.en)
    }
    func testTranslationTargetsRoundTripAndRemainDistinctFromRefining() throws {
        for language in SupportedLanguage.allCases {
            let action = RewriteAction.translate(language)
            XCTAssertEqual(try JSONDecoder().decode(RewriteAction.self,from:JSONEncoder().encode(action)),action)
            XCTAssertTrue(action.instruction.contains(language.englishName))
            XCTAssertFalse(action.instruction.contains("Preserve the draft's original language"))
        }
        XCTAssertTrue(RewriteAction.refine.instruction.contains("original language"))
    }
    func testRTLIsExplicit() {
        XCTAssertTrue(SupportedLanguage.ar.isRTL)
        XCTAssertTrue(SupportedLanguage.fa.isRTL)
        XCTAssertTrue(SupportedLanguage.ur.isRTL)
        XCTAssertFalse(SupportedLanguage.uk.isRTL)
    }
}
