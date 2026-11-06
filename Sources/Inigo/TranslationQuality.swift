import Foundation
import NaturalLanguage
import InigoCore

enum TranslationQuality {
    static func detectedLanguage(_ text: String) -> SupportedLanguage? {
        guard text.unicodeScalars.filter({ CharacterSet.letters.contains($0) }).count >= 40 else { return nil }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(text)
        guard let (language,confidence) = recognizer.languageHypotheses(withMaximum:1).first, confidence >= 0.8 else { return nil }
        return SupportedLanguage(rawValue:language.rawValue.split(separator:"-").first.map(String.init) ?? language.rawValue)
    }
    static func wrongLanguage(_ text: String, target: SupportedLanguage) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letters >= 40 else { return false } // Short names, greetings and shared words are ambiguous.
        let recognizer = NLLanguageRecognizer(); recognizer.processString(text)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum:1).first, confidence >= 0.8 else { return false }
        let code = language.rawValue.split(separator:"-").first.map(String.init) ?? language.rawValue
        return code != target.rawValue
    }
}
