import Foundation
import FoundationModels
import NaturalLanguage
import InigoCore

@MainActor
struct MobileRewriteEngine {
    func rewrite(_ source: String, action: RewriteAction) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw InigoError.message("On-device writing is unavailable. Check Apple Intelligence in Settings and allow its model to finish downloading. Your text is unchanged.")
        }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(source)
        if let language = recognizer.dominantLanguage,
           !model.supportsLocale(Locale(identifier: language.rawValue)) {
            throw InigoError.message("Apple’s on-device model does not currently support this text’s language. Your text is unchanged.")
        }
        if case .translate(let language) = action,
           !model.supportsLocale(Locale(identifier: language.rawValue)) {
            throw InigoError.message("Apple’s on-device model does not currently support translation into \(language.englishName). Your text is unchanged.")
        }
        let protected = try ProtectedDraft(source)
        let request = RewriteRequest(draft: protected.masked, action: action)
        let session = LanguageModelSession(model: model, instructions: request.instructions)
        try Task.checkCancellation()
        let response = try await session.respond(to: request.input)
        try Task.checkCancellation()
        let output = try protected.restore(response.content)
        let target: SupportedLanguage?
        if case .translate(let language) = action { target = language }
        else { target = TranslationQuality.detectedLanguage(source) }
        if let target, TranslationQuality.wrongLanguage(output, target: target) {
            throw InigoError.message("The model returned a different language than requested. Your text is unchanged. Try again.")
        }
        return output
    }
}
