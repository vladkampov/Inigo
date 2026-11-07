import Foundation
import FoundationModels
import InigoCore

/// Opt-in feasibility probe. No user draft, persistence, telemetry or cloud model.
@MainActor
final class ModelProbe {
    func run() async throws -> (String, Double) {
        let model = SystemLanguageModel.default
        guard model.availability == .available else { throw InigoError.message("Apple's on-device model is unavailable. Check device eligibility, Apple Intelligence and model download status.") }
        guard model.supportsLocale(Locale(identifier: "en")) else { throw InigoError.message("The probe language is unsupported by this model.") }
        let original = "We might finish by Friday, but the date is not confirmed. Could you shares an update?"
        let protected = try ProtectedDraft(original)
        let request = RewriteRequest(draft: protected.masked)
        let session = LanguageModelSession(model: model, instructions: request.instructions)
        let start = ContinuousClock.now
        let response = try await session.respond(to: request.input)
        try Task.checkCancellation()
        let result = try protected.restore(response.content)
        let elapsed = start.duration(to: .now).components
        return (result, Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
    }
}
