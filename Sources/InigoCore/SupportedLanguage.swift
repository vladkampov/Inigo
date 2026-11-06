import Foundation

public enum SupportedLanguage: String, CaseIterable, Codable, Sendable, Identifiable {
    case en, es, fr, de, pt, it, nl, pl, uk, tr, ar, fa, ur, hi, bn, ta, te, mr, id, vi, th, zh, ja, ko
    public var id: String { rawValue }
    public var englishName: String {
        switch self {
        case .en: return "English"; case .es: return "Spanish"; case .fr: return "French"
        case .de: return "German"; case .pt: return "Portuguese"; case .it: return "Italian"
        case .nl: return "Dutch"; case .pl: return "Polish"; case .uk: return "Ukrainian"
        case .tr: return "Turkish"; case .ar: return "Arabic"
        case .fa: return "Persian"; case .ur: return "Urdu"; case .hi: return "Hindi"
        case .bn: return "Bengali"; case .ta: return "Tamil"; case .te: return "Telugu"
        case .mr: return "Marathi"; case .id: return "Indonesian"; case .vi: return "Vietnamese"
        case .th: return "Thai"; case .zh: return "Chinese (Simplified)"; case .ja: return "Japanese"; case .ko: return "Korean"
        }
    }
    public var nativeName: String { Locale(identifier:rawValue).localizedString(forLanguageCode:rawValue)?.capitalized ?? englishName }
    public var isRTL: Bool { [.ar,.fa,.ur].contains(self) }
    public static func resolve(override: String, preferred: [String]) -> SupportedLanguage {
        if let value = Self(rawValue:override) { return value }
        for identifier in preferred {
            let base = identifier.replacingOccurrences(of:"_",with:"-").split(separator:"-").first.map(String.init) ?? identifier
            if let value = Self(rawValue:base) { return value }
        }
        return .en
    }
}
