import Foundation

/// A layout map contains only unambiguous, reversible single-character keys.
public struct LayoutConversion: Sendable, Equatable {
    public let text: String
    public let caret: Int
    public init?(_ original: String, caret: Int, mapping: [Character: Character]) {
        guard TextSafety.valid(NSRange(location: caret, length: 0), in: original) else { return nil }
        let protected = Self.protectedRanges(original)
        var output = "", offset = 0, newCaret = 0
        for character in original {
            let length = String(character).utf16.count
            let preserved = protected.contains { NSLocationInRange(offset, $0) }
                || character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
                || character.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value > 0xFFFF }
            let replacement: Character
            if preserved { replacement = character }
            else if let mapped = mapping[character] { replacement = mapped }
            else { return nil }
            if offset < caret { newCaret += String(replacement).utf16.count }
            output.append(replacement); offset += length
        }
        guard output != original else { return nil }
        text = output; self.caret = newCaret
    }

    public static func protectedRanges(_ text: String) -> [NSRange] {
        let regex = try! NSRegularExpression(pattern: #"https?://[^\s<>]+|[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}|<[@#][^>]+>|(?<!\w)[@#][\p{L}\p{N}_][\p{L}\p{N}_.-]*|`[^`]*`"#)
        return regex.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)).map(\.range)
    }

    public static func proseWords(_ text: String) -> [String] {
        let ns = text as NSString, protected = protectedRanges(text)
        let regex = try! NSRegularExpression(pattern: #"[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*"#)
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .filter { word in !protected.contains { NSIntersectionRange(word.range, $0).length > 0 } }
            .map { ns.substring(with: $0.range) }
    }
}

public struct LayoutRepairCandidate: Sendable {
    public let sourceID: String
    public let conversion: LayoutConversion
    public let recognition: Double
    public init(sourceID: String, conversion: LayoutConversion, recognition: Double) {
        self.sourceID = sourceID; self.conversion = conversion; self.recognition = recognition
    }
}

public enum LayoutRepairPolicy {
    public static let maximumLength = 20_000
    public static let idleMilliseconds = 800
    public static func winner(original: String, recognition: Double?, candidates: [LayoutRepairCandidate]) -> LayoutRepairCandidate? {
        guard original.utf16.count <= maximumLength,
              LayoutConversion.proseWords(original).joined().unicodeScalars.filter({ CharacterSet.letters.contains($0) }).count >= 6,
              let recognition, recognition.isFinite, (0...0.2).contains(recognition) else { return nil }
        // Equivalent layouts producing the same text are one candidate, not competing evidence.
        let ranked = Dictionary(grouping: candidates.filter { $0.recognition.isFinite && (0...1).contains($0.recognition) }, by: { $0.conversion.text })
            .compactMap { $0.value.sorted { $0.recognition == $1.recognition ? $0.sourceID < $1.sourceID : $0.recognition > $1.recognition }.first }
            .sorted { $0.recognition > $1.recognition }
        guard let best = ranked.first, best.recognition >= 0.9,
              ranked.count == 1 || best.recognition - ranked[1].recognition >= 0.25 else { return nil }
        return best
    }
}
