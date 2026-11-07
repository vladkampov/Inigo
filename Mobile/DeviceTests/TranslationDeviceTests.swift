import XCTest
import Translation
import InigoCore
@testable import InigoMobile

final class TranslationDeviceTests: XCTestCase {
    @MainActor
    func testNativeTranslationCoverageAndInstalledPairs() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Native translation models require a physical iPhone")
        #else
        let availability: LanguageAvailability
        if #available(iOS 26.4, *) { availability = LanguageAvailability(preferredStrategy: .lowLatency) }
        else { availability = LanguageAvailability() }
        let supported = await availability.supportedLanguages
        let codes = Set(supported.compactMap { $0.languageCode?.identifier })
        print("INIGO_TRANSLATION_COVERAGE " + SupportedLanguage.allCases.map { "\($0.rawValue)=\(codes.contains($0.rawValue))" }.joined(separator: ","))
        var fixtures = [
            ("en", "uk", "We might finish by Friday, but the date is not confirmed."),
            ("en", "pl", "Please send the form by 12 November. The fee is 25 EUR."),
            ("uk", "en", "Можливо, ми завершимо роботу до п’ятниці, але дату ще не підтверджено."),
            ("pl", "en", "Czy możesz przesłać aktualizację? Termin nie został jeszcze potwierdzony."),
            ("uk", "pl", "Будь ласка, надішліть форму до 12 листопада. Оплата становить 25 EUR."),
            ("pl", "uk", "Możemy zakończyć do piątku, ale potrzebujemy jeszcze potwierdzenia.")
        ]
        fixtures += SupportedLanguage.allCases.filter { !["en", "uk", "pl"].contains($0.rawValue) }.map {
            ("en", $0.rawValue, "We might finish by Friday, but the date is not confirmed. The fee is 25 EUR.")
        }
        fixtures += [("en", "uk", "Please ask @alex to review https://example.com/spec?id=7. We might finish by Friday."),
                     ("en", "pl", "Please ask @alex to review https://example.com/spec?id=7. We might finish by Friday.")]
        var results: [[String: String]] = []
        for (source, target, text) in fixtures {
            let from = Locale.Language(identifier: source), to = Locale.Language(identifier: target)
            let state = await availability.status(from: from, to: to)
            var row = ["source":source,"target":target,"status":String(describing:state)]
            if state == .installed {
                let session: TranslationSession
                if #available(iOS 26.4, *) { session = TranslationSession(installedSource: from, target: to, preferredStrategy: .lowLatency) }
                else { session = TranslationSession(installedSource: from, target: to) }
                let start = Date()
                do {
                    let response = try await session.translate(text)
                    let warmStart = Date()
                    let warmResponse = try await session.translate(text)
                    row["warmSeconds"] = String(format: "%.3f", Date().timeIntervalSince(warmStart))
                    XCTAssertFalse(warmResponse.targetText.isEmpty)
                    row["seconds"] = String(format: "%.3f", warmStart.timeIntervalSince(start))
                    row["input"] = text; row["output"] = response.targetText
                    XCTAssertFalse(response.targetText.isEmpty)
                    if let language = SupportedLanguage(rawValue: target) { XCTAssertFalse(TranslationQuality.wrongLanguage(response.targetText, target: language)) }
                    if text.contains("@alex"), let language = SupportedLanguage(rawValue: target) {
                        let protectedResult = try await MobileTranslationService.translate(text, to: language)
                        row["protectedOutput"] = protectedResult
                        XCTAssertTrue(protectedResult.contains("@alex"))
                        XCTAssertTrue(protectedResult.contains("https://example.com/spec?id=7"))
                    }
                } catch { row["error"] = String(describing: error); XCTFail("Installed pair failed: \(source)-\(target): \(error)") }
            }
            results.append(row)
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted,.sortedKeys])
        print("INIGO_TRANSLATION_RESULTS " + String(decoding: data, as: UTF8.self))
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "native-translation-device-results"; attachment.lifetime = .keepAlways; add(attachment)
        #endif
    }
}
