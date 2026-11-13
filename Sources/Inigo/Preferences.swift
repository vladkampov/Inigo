import Foundation
import Combine
import NaturalLanguage
import InigoCore

@MainActor
final class Preferences: ObservableObject {
    @Published var automaticLayoutRepair: Bool { didSet { defaults.set(automaticLayoutRepair, forKey: "automaticLayoutRepair") } }
    @Published var automaticLayoutRepairPaused: Bool { didSet { defaults.set(automaticLayoutRepairPaused, forKey: "automaticLayoutRepairPaused") } }
    @Published var interfaceLanguage: String { didSet { defaults.set(interfaceLanguage,forKey:"interfaceLanguage"); NotificationCenter.default.post(name:.inigoLanguageChanged,object:nil) } }
    @Published var translationLanguage: String { didSet { defaults.set(translationLanguage,forKey:"translationLanguage") } }
    var resolvedLanguage: SupportedLanguage { SupportedLanguage.resolve(override:interfaceLanguage, preferred:Locale.preferredLanguages) }
    @Published var compatibilityPaste: Bool { didSet { defaults.set(compatibilityPaste, forKey: "compatibilityPaste") } }
    @Published var mode: String { didSet { defaults.set(mode, forKey: "processing") } }
    @Published var learning: Bool { didSet { defaults.set(learning, forKey: "learning") } }
    @Published var exclusions: String { didSet { defaults.set(exclusions, forKey: "exclusions") } }
    @Published var translationPickerShortcutKey: UInt32 { didSet { defaults.set(Int(translationPickerShortcutKey),forKey:"translationPickerShortcutKey") } }
    @Published var translationPickerShortcutModifiers: UInt32 { didSet { defaults.set(Int(translationPickerShortcutModifiers),forKey:"translationPickerShortcutModifiers") } }
    @Published var recentTranslationLanguages: [String] { didSet { defaults.set(recentTranslationLanguages,forKey:"recentTranslationLanguages") } }
    @Published var translationShortcutKey: UInt32 { didSet { defaults.set(Int(translationShortcutKey),forKey:"translationShortcutKey") } }
    @Published var translationShortcutModifiers: UInt32 { didSet { defaults.set(Int(translationShortcutModifiers),forKey:"translationShortcutModifiers") } }
    @Published var shortcutKey: UInt32 { didSet { defaults.set(Int(shortcutKey), forKey: "shortcutKey") } }
    @Published var shortcutModifiers: UInt32 { didSet { defaults.set(Int(shortcutModifiers), forKey: "shortcutModifiers") } }
    @Published var onboarding: Bool { didSet { defaults.set(onboarding, forKey: "onboarding") } }
    @Published var profile: StyleProfile { didSet { if let data = try? JSONEncoder().encode(profile) { defaults.set(data, forKey: "styleProfile") } } }
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let d = defaults
        automaticLayoutRepair = d.bool(forKey: "automaticLayoutRepair")
        automaticLayoutRepairPaused = d.bool(forKey: "automaticLayoutRepairPaused")
        let savedInterface = d.string(forKey:"interfaceLanguage") ?? "system"
        interfaceLanguage = SupportedLanguage(rawValue:savedInterface) == nil ? "system" : savedInterface
        translationLanguage = SupportedLanguage(rawValue:d.string(forKey:"translationLanguage") ?? "en")?.rawValue ?? "en"
        compatibilityPaste = d.object(forKey: "compatibilityPaste") as? Bool ?? true
        mode = "Local" // Cloud is hidden in this personal release; retained code is inactive.
        learning = d.object(forKey: "learning") as? Bool ?? true
        exclusions = d.string(forKey: "exclusions") ?? "com.1password.1password\ncom.apple.keychainaccess"
        translationPickerShortcutKey = UInt32(d.object(forKey:"translationPickerShortcutKey") as? Int ?? 34)
        translationPickerShortcutModifiers = UInt32(d.object(forKey:"translationPickerShortcutModifiers") as? Int ?? 2304)
        recentTranslationLanguages = Array((d.stringArray(forKey:"recentTranslationLanguages") ?? []).filter { SupportedLanguage(rawValue:$0) != nil }.prefix(5))
        translationShortcutKey = UInt32(d.object(forKey:"translationShortcutKey") as? Int ?? 34)
        translationShortcutModifiers = UInt32(d.object(forKey:"translationShortcutModifiers") as? Int ?? 2560)
        shortcutKey = UInt32(d.object(forKey: "shortcutKey") as? Int ?? 34)
        shortcutModifiers = UInt32(d.object(forKey: "shortcutModifiers") as? Int ?? 2048)
        onboarding = d.bool(forKey: "onboarding")
        profile = d.data(forKey: "styleProfile").flatMap { try? JSONDecoder().decode(StyleProfile.self, from: $0) } ?? StyleProfile()
    }
    var excludedApps: Set<String> { Set(exclusions.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }) }
    static func language(_ text: String) -> String { NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "und" }
}
