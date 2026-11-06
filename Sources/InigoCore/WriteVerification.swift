import Foundation

public enum WriteObservation: Equatable, Sendable {
    case original, expected, different, unavailable
}
public enum WriteVerification: Equatable, Sendable {
    case confirmed, unconfirmed, interrupted

    /// A transport success is not proof of an editor mutation. Never retry the write.
    /// Only a matching readback confirms it; changed content stops observation immediately.
    public static func verify(
        attempts: Int = 12,
        read: () async -> WriteObservation,
        pause: () async throws -> Void = { try await Task.sleep(for: .milliseconds(50)) }
    ) async -> WriteVerification {
        for index in 0..<max(1, attempts) {
            if Task.isCancelled { return .interrupted }
            switch await read() {
            case .expected: return .confirmed
            case .different: return .interrupted
            case .original, .unavailable: break
            }
            if index < attempts - 1 {
                do { try await pause() } catch { return .interrupted }
            }
        }
        return .unconfirmed
    }
}

public enum EditorTextEquivalence {
    /// Editors may expose different newline encodings or decomposed Unicode.
    /// Do not ignore spaces, punctuation, or substantive user edits.
    public static func observation(current: String, original: String, expected: String, deletionIntermediate: String) -> WriteObservation {
        if matches(current,expected) { return .expected }
        if current == original { return .original }
        if current == deletionIntermediate { return .unavailable }
        return .different
    }
    public static func matches(_ actual: String, _ expected: String) -> Bool {
        func normalize(_ text: String) -> String {
            text.replacingOccurrences(of:"\r\n",with:"\n")
                .replacingOccurrences(of:"\r",with:"\n")
                .precomposedStringWithCanonicalMapping
        }
        return normalize(actual) == normalize(expected)
    }
}
