import SwiftUI
import InigoCore

struct TranslationPicker: View {
    @ObservedObject var preferences: Preferences
    var hasSelection = false
    var choose: (SupportedLanguage) -> Void
    @State private var search = ""
    @State private var highlighted: SupportedLanguage?
    @FocusState private var searchFocused: Bool
    private var languages: [SupportedLanguage] {
        let recent = preferences.recentTranslationLanguages.compactMap(SupportedLanguage.init(rawValue:))
        let ordered = recent + SupportedLanguage.allCases.filter { !recent.contains($0) }
        return ordered.filter { search.isEmpty || $0.englishName.localizedCaseInsensitiveContains(search) || $0.nativeName.localizedCaseInsensitiveContains(search) || (Locale(identifier:preferences.resolvedLanguage.rawValue).localizedString(forLanguageCode:$0.rawValue) ?? "").localizedCaseInsensitiveContains(search) }
    }
    private func select(_ language: SupportedLanguage) {
        preferences.recentTranslationLanguages = Array(([language.rawValue] + preferences.recentTranslationLanguages.filter { $0 != language.rawValue }).prefix(5))
        choose(language)
    }
    private func move(_ delta: Int) {
        guard !languages.isEmpty else { return }
        let index = highlighted.flatMap { languages.firstIndex(of:$0) } ?? 0
        highlighted = languages[min(max(index + delta,0),languages.count - 1)]
    }
    private func submit() { if let language = highlighted ?? languages.first { select(language) } }

    var body: some View {
        VStack(alignment:.leading,spacing:16) {
            Text(L(hasSelection ? "Translate selection" : "Translate your next selection")).font(.title2.bold())
            Text(L(hasSelection ? "Choose the language for this translation." : "Choose a language, return to your draft, then press your refine shortcut. Only that invocation translates; later ones refine normally.")).foregroundStyle(.secondary)
            TextField(L("Search languages"),text:$search).textFieldStyle(.roundedBorder)
                .focused($searchFocused)
                .onSubmit { submit() }
                .onKeyPress(.downArrow) { move(1); return .handled }
                .onKeyPress(.upArrow) { move(-1); return .handled }
            ScrollViewReader { proxy in
            List {
                ForEach(languages) { language in
                    Button {
                        select(language)
                    } label: {
                        HStack {
                            Text(language.nativeName)
                            if preferences.recentTranslationLanguages.contains(language.rawValue) {
                                Image(systemName:"clock").foregroundStyle(.secondary).accessibilityLabel(L("Recently used"))
                            }
                            Spacer()
                            Text(Locale(identifier:preferences.resolvedLanguage.rawValue).localizedString(forLanguageCode:language.rawValue) ?? language.englishName).foregroundStyle(.secondary)
                            if preferences.translationLanguage == language.rawValue { Image(systemName:"checkmark") }
                        }.contentShape(Rectangle())
                    }.buttonStyle(.plain).padding(.vertical,5)
                        .listRowBackground(highlighted == language ? Color.accentColor.opacity(0.15) : Color.clear)
                        .id(language)
                }
            }.onChange(of:highlighted) { _, value in if let value { proxy.scrollTo(value) } }
            }
        }.onAppear { highlighted = languages.first; searchFocused = true }
        .onChange(of:search) { _, _ in highlighted = languages.first }
        .onExitCommand { NSApp.keyWindow?.close() }
        .padding(24).frame(width:520,height:510)
        .environment(\.layoutDirection,preferences.resolvedLanguage.isRTL ? .rightToLeft : .leftToRight)
    }
}
