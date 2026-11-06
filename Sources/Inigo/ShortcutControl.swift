import SwiftUI
import AppKit
import Carbon

struct ShortcutControl: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    var translation = false
    var languagePicker = false
    private var conflict: Bool { languagePicker ? model.translationPickerShortcutConflict : translation ? model.translationShortcutConflict : model.shortcutConflict }
    private var key: UInt32 { languagePicker ? preferences.translationPickerShortcutKey : translation ? preferences.translationShortcutKey : preferences.shortcutKey }
    private var modifiers: UInt32 { languagePicker ? preferences.translationPickerShortcutModifiers : translation ? preferences.translationShortcutModifiers : preferences.shortcutModifiers }
    private func save(key: UInt32, modifiers: UInt32) {
        if languagePicker { preferences.translationPickerShortcutKey = key; preferences.translationPickerShortcutModifiers = modifiers }
        else if translation { preferences.translationShortcutKey = key; preferences.translationShortcutModifiers = modifiers }
        else { preferences.shortcutKey = key; preferences.shortcutModifiers = modifiers }
    }
    @State private var recording = false
    @State private var keyMonitor: Any?
    @State private var error = ""
    var body: some View {
        VStack(alignment:.leading,spacing:8) {
            HStack {
                VStack(alignment:.leading,spacing:4) {
                    Text(L(languagePicker ? "Choose translation language shortcut" : translation ? "Your translation shortcut" : "Your refine shortcut")).font(.headline)
                    Text(L("Click the shortcut to change it.")).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button(recording ? L("Press new shortcut…") : shortcutLabel) { recordShortcut() }
                    .font(.system(size:18,weight:.medium,design:.rounded)).keyboardShortcut(.none)
                    .accessibilityLabel(L(languagePicker ? "Change language picker shortcut, " : translation ? "Change translation shortcut, " : "Change refine shortcut, ") + shortcutLabel)
            }
            Text(L(recording ? "Hold Option, Control or Command and press a key. Escape cancels." : "Select text in your app, then press these keys together. ⌥ means Option.")).font(.caption).foregroundStyle(.secondary)
            if recording { Button(L("Cancel")) { finishRecording() }.buttonStyle(.borderless) }
            if !error.isEmpty { Text(L(error)).font(.caption).foregroundStyle(.red) }
            else if conflict {
                Text(L("Shortcut unavailable. Click to choose another.")).font(.caption).foregroundStyle(.red)
            }
        }.padding(14).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:12))
        .onDisappear { finishRecording() }
        .onReceive(NotificationCenter.default.publisher(for:NSApplication.didResignActiveNotification)) { _ in finishRecording() }
    }
    var shortcutLabel: String {
        let keys: [UInt32:String] = [0:"A",1:"S",2:"D",3:"F",4:"H",5:"G",6:"Z",7:"X",8:"C",9:"V",11:"B",12:"Q",13:"W",14:"E",15:"R",16:"Y",17:"T",18:"1",19:"2",20:"3",21:"4",22:"6",23:"5",24:"=",25:"9",26:"7",27:"−",28:"8",29:"0",30:"]",31:"O",32:"U",33:"[",34:"I",35:"P",36:"Return",37:"L",38:"J",39:"'",40:"K",41:";",42:"\\",43:",",44:"/",45:"N",46:"M",47:".",48:"Tab",49:"Space",50:"`",51:"Delete",123:"←",124:"→",125:"↓",126:"↑"]
        let m = modifiers
        return (m & UInt32(controlKey) != 0 ? "⌃" : "") + (m & UInt32(optionKey) != 0 ? "⌥" : "") + (m & UInt32(shiftKey) != 0 ? "⇧" : "") + (m & UInt32(cmdKey) != 0 ? "⌘" : "") + (keys[key] ?? "Key \(key)")
    }
    func recordShortcut() {
        guard !recording else { return }; recording = true; error = ""
        model.shortcut.suspend(); model.translationShortcut.suspend(); model.translationPickerShortcut.suspend()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching:.keyDown) { event in
            if event.keyCode == 53 { finishRecording(); return nil }
            let flags = event.modifierFlags
            guard flags.contains(.control) || flags.contains(.command) || flags.contains(.option) else { error = "Hold Option, Control or Command while pressing a key."; return nil }
            let oldKey = key
            let oldModifiers = modifiers
            let newModifiers = (flags.contains(.control) ? UInt32(controlKey) : 0) | (flags.contains(.option) ? UInt32(optionKey) : 0) | (flags.contains(.shift) ? UInt32(shiftKey) : 0) | (flags.contains(.command) ? UInt32(cmdKey) : 0)
            let shortcuts: [(Bool, UInt32, UInt32)] = [
                (!translation && !languagePicker, preferences.shortcutKey, preferences.shortcutModifiers),
                (translation && !languagePicker, preferences.translationShortcutKey, preferences.translationShortcutModifiers),
                (languagePicker, preferences.translationPickerShortcutKey, preferences.translationPickerShortcutModifiers)
            ]
            guard !shortcuts.contains(where: { !$0.0 && $0.1 == UInt32(event.keyCode) && $0.2 == newModifiers }) else {
                error = "Choose a different shortcut for each action."; return nil
            }
            save(key:UInt32(event.keyCode),modifiers:newModifiers)
            model.registerShortcut()
            if conflict {
                save(key:oldKey,modifiers:oldModifiers)
                model.registerShortcut(); error = "That shortcut is unavailable. Your previous shortcut is still active."
            } else { error = "" }
            finishRecording(); return nil
        }
    }
    func finishRecording() {
        guard recording else { return }
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }; keyMonitor = nil; recording = false
        model.registerShortcut()
    }
}
