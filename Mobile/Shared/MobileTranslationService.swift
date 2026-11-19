import Foundation
import NaturalLanguage
import Translation
import InigoCore

/// Translation uses Apple's downloaded traditional models, never the writing LLM.
enum MobileTranslationService {
    static func availability() -> LanguageAvailability {
        if #available(iOS 26.4, *) { return LanguageAvailability(preferredStrategy: .lowLatency) }
        return LanguageAvailability()
    }
    static func supportedTargets() async -> [SupportedLanguage] {
        let codes = Set(await availability().supportedLanguages.compactMap { $0.languageCode?.identifier })
        return SupportedLanguage.allCases.filter { codes.contains($0.rawValue) }
    }
    static func session(from: Locale.Language, to: Locale.Language) -> TranslationSession {
        if #available(iOS 26.4, *) { return TranslationSession(installedSource: from, target: to, preferredStrategy: .lowLatency) }
        return TranslationSession(installedSource: from, target: to)
    }
    @MainActor
    static func translate(_ text: String, to target: SupportedLanguage,
                          prepare: ((Locale.Language, Locale.Language) async throws -> Void)? = nil) async throws -> String {
        try Task.checkCancellation()
        guard let code = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue else {
            throw InigoError.message(M("Could not identify the source language. Add a little more text and try again."))
        }
        if code == target.rawValue { return text }
        let from = Locale.Language(identifier: code), to = Locale.Language(identifier: target.rawValue)
        let state = await availability().status(from: from, to: to)
        guard state != .unsupported else { throw InigoError.message(M("This language pair is not supported by on-device translation.")) }
        if state == .supported {
            guard let prepare else { throw InigoError.message(M("Download the translation languages in Inigo before translating offline.")) }
            try await prepare(from, to)
        }
        try Task.checkCancellation()
        let protected = try ProtectedDraft(text)
        let translator = session(from: from, to: to)
        let response = try await withTaskCancellationHandler {
            try await translator.translate(protected.masked)
        } onCancel: { translator.cancel() }
        try Task.checkCancellation()
        let output = try protected.restore(response.targetText)
        guard !TranslationQuality.wrongLanguage(output, target: target) else {
            throw InigoError.message(M("The model returned a different language than requested. Your text is unchanged. Try again."))
        }
        return output
    }
}
