import Foundation

/// Regex matches and characters/words are ordered, so each span is visited once.
private struct ProtectedRangeCursor {
    let ranges: [NSRange]
    private var index = 0
    init(_ ranges: [NSRange]) { self.ranges = ranges }
    mutating func intersects(_ range: NSRange) -> Bool {
        while index < ranges.count, NSMaxRange(ranges[index]) <= range.location { index += 1 }
        return index < ranges.count && NSIntersectionRange(ranges[index], range).length > 0
    }
}

/// A layout map contains only unambiguous, reversible single-character keys.
public struct LayoutConversion: Sendable, Equatable {
    public let text: String
    public let caret: Int
    public init?(_ original: String, caret: Int, mapping: [Character: Character]) {
        guard TextSafety.valid(NSRange(location: caret, length: 0), in: original) else { return nil }
        var protected = ProtectedRangeCursor(Self.protectedRanges(original))
        var output = "", offset = 0, newCaret = 0
        for character in original {
            let length = String(character).utf16.count
            let preserved = protected.intersects(NSRange(location: offset, length: length))
                || character.unicodeScalars.allSatisfy { CharacterSet.whitespacesAndNewlines.contains($0) }
                || character.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.value > 0xFFFF }
            let replacement: Character
            if preserved { replacement = character }
            else if let mapped = mapping[character] { replacement = mapped }
            else { return nil }
            if caret >= offset + length { newCaret += String(replacement).utf16.count }
            else if caret > offset {
                guard replacement == character else { return nil }
                newCaret += caret - offset
            }
            output.append(replacement); offset += length
        }
        guard output != original else { return nil }
        text = output; self.caret = newCaret
    }

    private static let protectedPattern = try! NSRegularExpression(pattern: #"(?i:https?)://[^\s<>]+|[\p{L}\p{N}._%+-]+@[\p{L}\p{N}.-]+\.[\p{L}]{2,}|<[@#][^>]+>|(?<!\w)[@#][\p{L}\p{N}_][\p{L}\p{N}_.-]*|`[^`]*`"#)
    private static let wordPattern = try! NSRegularExpression(pattern: #"[\p{L}\p{M}]+(?:['’][\p{L}\p{M}]+)*"#)
    public static func protectedRanges(_ text: String) -> [NSRange] {
        protectedPattern.matches(in: text, range: NSRange(location: 0, length: text.utf16.count)).map(\.range)
    }

    public static func proseWords(_ text: String) -> [String] {
        let ns = text as NSString
        var protected = ProtectedRangeCursor(protectedRanges(text)), words: [String] = []
        for match in wordPattern.matches(in: text, range: NSRange(location: 0, length: ns.length)) where !protected.intersects(match.range) {
            words.append(ns.substring(with: match.range))
        }
        return words
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
