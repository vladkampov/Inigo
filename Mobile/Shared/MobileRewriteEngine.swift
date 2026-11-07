import Foundation
import FoundationModels
import NaturalLanguage
import InigoCore

@Generable
struct MobileRewriteResult {
    @Guide(description: "Only the edited or translated prose. No JSON wrapper, commentary or surrounding quotation marks.")
    var text: String
}

@MainActor
struct MobileRewriteEngine {
    func rewrite(_ source: String, action: RewriteAction) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw InigoError.message(M("On-device writing is unavailable. Check Apple Intelligence in Settings and allow its model to finish downloading. Your text is unchanged."))
        }
        let recognizer = NLLanguageRecognizer(); recognizer.processString(source)
        if let language = recognizer.dominantLanguage,
           !model.supportsLocale(Locale(identifier: language.rawValue)) {
            throw InigoError.message(M("Apple’s on-device model does not currently support this text’s language. Your text is unchanged."))
        }
        if case .translate(let language) = action,
           !model.supportsLocale(Locale(identifier: language.rawValue)) {
            throw InigoError.message(MF("Apple’s on-device model does not currently support translation into %@. Your text is unchanged.", language.nativeName))
        }
        let protected = try ProtectedDraft(source)
        let styleLanguage: String
        if case .translate(let target) = action { styleLanguage = target.rawValue }
        else { styleLanguage = recognizer.dominantLanguage?.rawValue ?? "und" }
        let style = MobilePreferences.shared.state.profile.preferences(for: styleLanguage)
        let request = RewriteRequest(draft: protected.masked, style: style, action: action)
        let session = LanguageModelSession(model: model, instructions: request.instructions + "\nPut the revised prose in the text field of the requested response structure.")
        try Task.checkCancellation()
        let response = try await session.respond(to: request.input, generating: MobileRewriteResult.self)
        try Task.checkCancellation()
        let output = try protected.restore(response.content.text)
        let target: SupportedLanguage?
        if case .translate(let language) = action { target = language }
        else { target = TranslationQuality.detectedLanguage(source) }
        if let target, TranslationQuality.wrongLanguage(output, target: target) {
            throw InigoError.message(M("The model returned a different language than requested. Your text is unchanged. Try again."))
        }
        return output
    }
}
