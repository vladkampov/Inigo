import SwiftUI
import AppKit
import Carbon
import InigoCore

struct BrandMark: View {
    var size: CGFloat = 56
    var body: some View {
        Image(nsImage:NSImage(contentsOf:Bundle.main.url(forResource:"Inigo",withExtension:"png")!) ?? NSImage())
            .resizable().interpolation(.high).frame(width:size,height:size).accessibilityLabel("Inigo")
    }
}
struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var local: LocalEngine
    @ObservedObject var cloud: CloudEngine
    @State private var section = "General"
    let sections = [("General","gearshape"),("Translation","character.bubble"),("Processing","square.3.layers.3d"),("Privacy","hand.raised"),("Writing Style","pencil"),("Support","heart")]
    var body: some View {
        HStack(spacing:0) {
            VStack(alignment:.leading,spacing:24) {
                HStack(spacing:12) { BrandMark(size:42); VStack(alignment:.leading,spacing:2) { Text(L("Inigo")).font(.title2.bold()); Text(L("Settings")).foregroundStyle(.secondary) } }.padding(.top,20).padding(.bottom,10)
                VStack(spacing:6) {
                    ForEach(sections,id:\.0) { name,icon in
                        Button { section = name } label: {
                            Label(L(name),systemImage:icon).font(.system(size:14,weight:section == name ? .medium : .regular)).frame(maxWidth:.infinity,alignment:.leading).padding(.horizontal,12).padding(.vertical,11)
                                .background(section == name ? Color.blue.opacity(0.16) : .clear,in:RoundedRectangle(cornerRadius:8))
                        }.buttonStyle(.plain).accessibilityAddTraits(section == name ? .isSelected : [])
                    }
                }
                Spacer()
                Label(L("Made for your words"),systemImage:"lock.shield").font(.caption).foregroundStyle(.secondary).padding(.bottom,16)
            }.padding(.horizontal,16).frame(width:190).background(.thinMaterial)
            Divider()
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    Text(L(section)).font(.system(size:29,weight:.bold)).padding(.top,12)
                    switch section {
                    case "General": general
                    case "Privacy": privacy
                    case "Writing Style": style
                    case "Support": support
                    case "Translation": translation
                    default: processing
                    }
                    Spacer(minLength:20)
                }.padding(30).frame(maxWidth:.infinity,alignment:.leading)
            }.background(Color(nsColor:.windowBackgroundColor))
        }.frame(width:790,height:570)
        .task { if preferences.mode == "Local" { await local.prepareIfNeeded() } }
        .onChange(of:local.ready) { _, available in if available && preferences.mode == "Local" { Task { await local.prepareIfNeeded() } } }

    }
    var processing: some View { ModelSettings(model:model,local:local) }
    var general: some View {
        VStack(alignment:.leading,spacing:24) {
            Text(L("Write in your app. Press your shortcut. Keep going.")).foregroundStyle(.secondary)
            Picker(L("Interface language"),selection:$preferences.interfaceLanguage) {
                Text(L("Follow macOS")).tag("system")
                ForEach(SupportedLanguage.allCases) { language in Text(language.nativeName).tag(language.rawValue) }
            }
            Text(L("Changes menus and settings only. Your writing keeps its original language.")).font(.caption).foregroundStyle(.secondary)
            LoginItemSettings(loginItem: model.loginItem)
            ShortcutControl(model:model, preferences:preferences)
            Text(L("Inigo improves clarity and tone while keeping your language and meaning. It never sends the message for you.")).foregroundStyle(.secondary)
            Divider()
            UpdateSettings(updates:model.updates)
            Divider()
            Text(L("Want to try it again?")).font(.headline)
            Text(L("The guided setup checks text access and lets you refine a sample message here in Inigo.")).foregroundStyle(.secondary)
            Button(L("Open guided setup")) { preferences.onboarding = false }.buttonStyle(.bordered)
            DisclosureGroup(L("Troubleshooting text access")) {
                Text(L("If rewriting stops working after an update, remove the old Inigo entry in macOS Accessibility and add the current app again.")).font(.callout).foregroundStyle(.secondary).padding(.vertical,8)
                Button(L("Open Accessibility settings")) { AccessibilityEditor.requestPermission(); NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }
            }
        }
    }
    var translation: some View {
        VStack(alignment:.leading,spacing:22) {
            Text(L("Understand a message. Write back with confidence.")).foregroundStyle(.secondary)
            Picker(L("Default translation language"),selection:$preferences.translationLanguage) {
                ForEach(SupportedLanguage.allCases) { language in Text(language.nativeName).tag(language.rawValue) }
            }
            ShortcutControl(model:model,preferences:preferences,translation:true)
            Text(L("Translates immediately into your default language.")).font(.caption).foregroundStyle(.secondary)
            ShortcutControl(model:model,preferences:preferences,languagePicker:true)
            Text(L("Opens a language picker for your selection. Search, use the arrow keys, then press Return.")).font(.caption).foregroundStyle(.secondary)
            Text(L("In a supported text field, Inigo replaces your selection. On a page or document you are reading, it shows a translation you can copy.")).foregroundStyle(.secondary)
            Text(L("Choose another language anytime from Translate next selection in the menu bar.")).font(.callout).foregroundStyle(.secondary)
        }
    }
    var support: some View {
        VStack(alignment:.leading,spacing:22) {
            BrandMark(size:64)
            Text(L("A small app that just does the work.")).font(.title2.bold())
            Text(L("Inigo helps you write clearly without taking you out of your flow. It runs on your Mac, keeps things simple, and stays out of the way.")).foregroundStyle(.secondary)
            Text(L("If Inigo makes your day a little easier, you can support its development or help others discover it.")).foregroundStyle(.secondary)
            Button(L("Buy me a coffee")) { if let url = SupportLinks.coffee { NSWorkspace.shared.open(url) } }.disabled(SupportLinks.coffee == nil)
            Button(L("Star on GitHub")) { if let url = SupportLinks.repository { NSWorkspace.shared.open(url) } }.disabled(SupportLinks.repository == nil)
            Divider()
            Text(L("Help make Inigo better")).font(.headline)
            Text(L("Ideas, bug reports, translations and code contributions are welcome. Every contribution helps keep Inigo small and useful.")).foregroundStyle(.secondary)
            ForEach(["Request a feature", "Report a bug", "Share feedback", "Contribute on GitHub"],id:\.self) { title in
                Button(L(title)) {
                    if let url = title == "Contribute on GitHub" ? SupportLinks.repository : SupportLinks.issue(title) { NSWorkspace.shared.open(url) }
                }.disabled(SupportLinks.repository == nil)
            }
            if SupportLinks.coffee == nil { Text(L("Coffee support is coming soon.")).font(.caption).foregroundStyle(.secondary) }
        }
    }
    var privacy: some View {
        VStack(alignment:.leading,spacing:18) {
            Text(L("Your writing belongs to you.")).font(.title3.bold())
            ForEach(["Context is read only when you invoke Inigo.","No screenshots, OCR, or clipboard monitoring.","Drafts and undo data expire from memory after two minutes.","No conversation history, analytics, or profile sync."],id:\.self) { Label(L($0),systemImage:"checkmark.shield").foregroundStyle(.secondary) }
            Divider()
            ErrorReportSettings(reports:model.reports)
            Divider()
            Toggle(L("Use Paste in editors that need it"), isOn:$preferences.compatibilityPaste)
            Text(L("For editors such as Codex, briefly use the clipboard to paste your rewrite, then restore it. Clipboard managers may retain the temporary text. New clipboard content you copy is never overwritten.")).font(.caption).foregroundStyle(.secondary)
            Divider()
            Text(L("Apps Inigo should ignore")).font(.headline)
            ForEach(preferences.excludedApps.sorted(), id: \.self) { identifier in
                HStack {
                    Text(NSWorkspace.shared.urlForApplication(withBundleIdentifier:identifier)?.deletingPathExtension().lastPathComponent ?? identifier).lineLimit(1)
                    Spacer()
                    Button(L("Remove")) { preferences.exclusions = preferences.excludedApps.subtracting([identifier]).sorted().joined(separator:"\n") }.buttonStyle(.borderless)
                }
            }
            Button(L("Add an app…")) {
                let picker = NSOpenPanel()
                picker.title = L("Choose an app Inigo should ignore")
                picker.directoryURL = URL(fileURLWithPath:"/Applications")
                picker.canChooseDirectories = false; picker.allowsMultipleSelection = false
                picker.begin { result in
                    guard result == .OK, let url = picker.url, url.pathExtension == "app", let identifier = Bundle(url:url)?.bundleIdentifier else { return }
                    preferences.exclusions = preferences.excludedApps.union([identifier]).sorted().joined(separator:"\n")
                }
            }
            Text(L("Password fields are always excluded. In browsers, select text first. Private windows are allowed; surrounding browser context is not used.")).font(.caption).foregroundStyle(.secondary)
            DisclosureGroup(L("Advanced: excluded app identifiers")) {
            Text(L("One bundle identifier per line, such as com.apple.Notes.")).font(.caption).foregroundStyle(.secondary)
            TextEditor(text:$preferences.exclusions).font(.system(.body,design:.monospaced)).frame(height:90).padding(6).background(.background,in:RoundedRectangle(cornerRadius:8))
            }
            Button(L("Clear current rewrite and Undo")) { model.cancel(); model.clearResult() }
        }
    }
    var style: some View {
        VStack(alignment:.leading,spacing:20) {
            Text(L("Sound like yourself, only clearer.")).foregroundStyle(.secondary)
            Toggle(L("Learn from rewrites I keep"),isOn:$preferences.learning)
            Text(L("Inigo looks for repeated style patterns in unchanged rewrites. Keeping a rewrite is only a weak signal. Turn this off to pause learning; existing preferences remain. Only style preferences are saved, separately for each language.")).font(.callout).foregroundStyle(.secondary)
            Divider()
            Text(L("Inigo keeps the language you write in. Results vary by language—review the rewrite before sending.")).font(.callout).foregroundStyle(.secondary)
            if preferences.profile.evidence.isEmpty {
                Text(L("No preferences learned yet. Languages appear here as Inigo learns from your rewrites.")).foregroundStyle(.secondary)
            }
            ForEach(preferences.profile.evidence.keys.sorted(),id:\.self) { code in
                let name = Locale(identifier:preferences.resolvedLanguage.rawValue).localizedString(forLanguageCode:code) ?? code
                VStack(alignment:.leading,spacing:6) { Text(name).font(.headline); let entries = preferences.profile.preferences(for:code); Text(entries.isEmpty ? L("No preferences learned yet.") : entries.map { L($0) }.joined(separator:"\n")).foregroundStyle(.secondary).font(.callout) }
            }
            Button(L("Reset learned preferences"),role:.destructive) { preferences.profile = StyleProfile() }
        }
    }
}

struct HUDView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var model: AppModel
    init(model: AppModel, close: @escaping () -> Void) { self.model = model; self.preferences = model.preferences; self.close = close }
    var close: () -> Void
    var body: some View {
        VStack(alignment:.leading,spacing:14) {
            HStack(spacing:8) {
                if model.working { ProgressView().controlSize(.small) } else if model.canUndo { Image(systemName:"checkmark.circle.fill").foregroundStyle(.green) } else { BrandMark(size:22) }
                Text(L(model.message)).font(.system(size:12,weight:.medium)).fixedSize(horizontal:false,vertical:true)
                Spacer(minLength:4)
                if model.canUndo { Button(L("Undo")) { model.undo() }.buttonStyle(.borderless).tint(.blue) }
                Button { model.cancel(); model.clearResult(); close() } label: { Image(systemName:"xmark").font(.caption) }.buttonStyle(.plain).accessibilityLabel(L("Dismiss"))
            }
            if !model.fallback.isEmpty {
                ScrollView { Text(model.fallback).textSelection(.enabled).font(.system(size:14)).frame(maxWidth:.infinity,alignment:.leading) }.frame(maxHeight:180)
                HStack { Text(L(model.fallbackMayHaveChanged ? "Check the original field" : "Original left intact")).font(.caption).foregroundStyle(.secondary); Spacer(); Button(L("Copy")) { model.copy() }.buttonStyle(.borderedProminent) }
            }
        }.environment(\.layoutDirection,preferences.resolvedLanguage.isRTL ? .rightToLeft : .leftToRight).padding(model.fallback.isEmpty ? 12 : 16).frame(width:model.fallback.isEmpty ? 300 : 400).background(.regularMaterial,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(.white.opacity(0.15)))
    }
}
