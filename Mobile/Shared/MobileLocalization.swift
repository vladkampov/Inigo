import Foundation
import InigoCore

private let mobileTranslations: [String: [String: String]] = {
    guard let url = Bundle.main.url(forResource: "Translations", withExtension: "json"), let data = try? Data(contentsOf: url),
          let result = try? JSONDecoder().decode([String: [String: String]].self, from: data) else { return [:] }
    return result
}()
func M(_ key: String) -> String { mobileTranslations[MobilePreferences.shared.language.rawValue]?[key] ?? key }
func MF(_ key: String, _ argument: String) -> String { String(format: M(key), locale: Locale(identifier: MobilePreferences.shared.language.rawValue), argument) }
