import Foundation
import InigoCore

extension Notification.Name { static let inigoLanguageChanged = Notification.Name("inigoLanguageChanged") }
func interfaceLanguage() -> SupportedLanguage {
    SupportedLanguage.resolve(override:UserDefaults.standard.string(forKey:"interfaceLanguage") ?? "system",preferred:Locale.preferredLanguages)
}
private let translations: [String:[String:String]] = {
    guard let url = Bundle.main.url(forResource:"Translations",withExtension:"json"), let data = try? Data(contentsOf:url),
          let result = try? JSONDecoder().decode([String:[String:String]].self,from:data) else { return [:] }
    return result
}()
func L(_ text: String) -> String { translations[interfaceLanguage().rawValue]?[text] ?? text }
