import SwiftUI
import AppKit
import Combine
import InigoCore

final class ResultPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@main
enum InigoApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuItemValidation {
    let model = AppModel()
    private var restoringTranslation = false
    private var translationExpiry: Task<Void,Never>?
    private var translationWindow: NSWindow?
    private var languageChanges: AnyCancellable?
    private var item: NSStatusItem!
    private var settings: NSWindow?
    private var hud: NSPanel?
    private var hudDismissal: Task<Void, Never>?
    private var hudChanges: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        model.updates.start()
        model.showTranslationPicker = { [weak self] in self?.openTranslation() }
        model.registerShortcut()
        item = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
        let menuIcon = NSImage(contentsOf:Bundle.main.url(forResource:"InigoMenu",withExtension:"png")!)
        menuIcon?.isTemplate = true; menuIcon?.size = NSSize(width:18,height:18)
        item.button?.image = menuIcon; item.button?.setAccessibilityLabel("Inigo")
        if let url = Bundle.main.url(forResource:"Inigo",withExtension:"png") { NSApp.applicationIconImage = NSImage(contentsOf:url) }
        rebuildMenu()
        languageChanges = NotificationCenter.default.publisher(for:.inigoLanguageChanged).sink { [weak self] _ in
            Task { @MainActor in self?.rebuildMenu() }
        }
        hudChanges = model.objectWillChange.sink { [weak self] _ in DispatchQueue.main.async { self?.resizeHUD() } }
        model.showSettings = { [weak self] in self?.openSettings() }; model.showHUD = { [weak self] in self?.presentHUD() }
        model.hudSucceeded = { [weak self] in self?.scheduleHUDDismissal() }
        if !model.preferences.onboarding || CommandLine.arguments.contains("--settings") { openSettings() }
    }
    private func rebuildMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title:"Inigo",action:nil,keyEquivalent:""))
        let settingsItem = NSMenuItem(title:L("Settings…"),action:#selector(openSettings),keyEquivalent:","); settingsItem.target = self; menu.addItem(settingsItem)
        let update = NSMenuItem(title:L("Check for Updates…"),action:#selector(checkForUpdates),keyEquivalent:"")
        update.target = self; menu.addItem(update)
        menu.addItem(NSMenuItem.separator())
        let translation = NSMenuItem(title:L("Translate next selection…"),action:#selector(openTranslation),keyEquivalent:"")
        translation.target = self; menu.addItem(translation)
        menu.addItem(NSMenuItem.separator())
        let help = NSMenuItem(title:L("Help & Feedback"),action:nil,keyEquivalent:"")
        let helpMenu = NSMenu(); helpMenu.autoenablesItems = false
        for title in ["Request a feature", "Report a bug", "Share feedback", "Contribute on GitHub"] {
            let entry = NSMenuItem(title:L(title),action:#selector(openSupportLink(_:)),keyEquivalent:"")
            entry.target = self; entry.representedObject = title; entry.isEnabled = SupportLinks.repository != nil
            helpMenu.addItem(entry)
        }
        if SupportLinks.repository == nil { let note = NSMenuItem(title:L("GitHub links are coming soon."),action:nil,keyEquivalent:""); note.isEnabled = false; helpMenu.addItem(note) }
        help.submenu = helpMenu; menu.addItem(help)
        let quit = NSMenuItem(title:L("Quit Inigo"),action:#selector(quitApp),keyEquivalent:"q"); quit.target = self; menu.addItem(quit); item.menu = menu
        let main = NSMenu()
        let applicationMenu = NSMenuItem(); applicationMenu.submenu = menu.copy() as? NSMenu; main.addItem(applicationMenu)
        let editItem = NSMenuItem(title:L("Edit"),action:nil,keyEquivalent:""); let edit = NSMenu(title:L("Edit"))
        for (title, action, key) in [("Undo","undo:","z"),("Cut","cut:","x"),("Copy","copy:","c"),("Paste","paste:","v"),("Select All","selectAll:","a")] { edit.addItem(NSMenuItem(title:L(title),action:NSSelectorFromString(action),keyEquivalent:key)) }
        editItem.submenu = edit; main.addItem(editItem); NSApp.mainMenu = main
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard translationWindow == nil, !restoringTranslation else { return false }
        openSettings(); return true
    }
    @objc func openSettings() {
        if settings == nil {
            let window = NSWindow(contentRect:NSRect(x:0,y:0,width:790,height:570),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
            window.title = "Inigo"; window.titlebarAppearsTransparent = true; window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: RootSettings(model:model,preferences:model.preferences))
            window.delegate = self
            window.center(); settings = window
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps:true); settings?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === translationWindow { translationExpiry?.cancel(); translationExpiry = nil; window.contentView = nil; translationWindow = nil }
        if let window = notification.object as? NSWindow, window === settings { NSApp.setActivationPolicy(.accessory) }
    }
    private func resizeHUD() {
        if let view = hud?.contentView { hud?.setContentSize(view.fittingSize) }
        positionHUD()
    }
    private func positionHUD() {
        guard let hud else { return }
        let anchor = model.hudAnchor
        let screen = NSScreen.screens.first { screen in anchor.map { screen.frame.intersects($0) } ?? false } ?? NSScreen.main
        guard let bounds = screen?.visibleFrame.insetBy(dx:12, dy:12) else { return }
        let size = hud.frame.size
        var x = anchor?.minX ?? (bounds.maxX - size.width)
        var y = anchor.map { $0.minY - size.height - 8 } ?? (bounds.maxY - size.height)
        if y < bounds.minY, let anchor { y = anchor.maxY + 8 }
        x = max(bounds.minX, min(x, bounds.maxX - size.width))
        y = max(bounds.minY, min(y, bounds.maxY - size.height))
        hud.setFrameOrigin(NSPoint(x:x, y:y))
    }
    private func scheduleHUDDismissal() {
        hudDismissal?.cancel()
        hudDismissal = Task { [weak self] in
            try? await Task.sleep(for:.seconds(3))
            guard !Task.isCancelled else { return }
            guard let self, !self.model.working, self.model.fallback.isEmpty,
                  ["Refined", "Translated", "Already clear · no changes", "Original restored", "Copied · paste it where you need it"].contains(self.model.message) else { return }
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                // Smoothstep easing; cancellation prevents an old fade hiding a new invocation.
                for step in 1...15 {
                    try? await Task.sleep(for:.milliseconds(16))
                    guard !Task.isCancelled else { return }
                    let progress = Double(step) / 15
                    self.hud?.alphaValue = 1 - progress * progress * (3 - 2 * progress)
                }
            }
            self.hud?.orderOut(nil)
            self.hud?.alphaValue = 1
        }
    }
    private func presentHUD() {
        hudDismissal?.cancel()
        if hud == nil {
            let panel = ResultPanel(contentRect:NSRect(x:0,y:0,width:436,height:95),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
            panel.becomesKeyOnlyIfNeeded = true; panel.isFloatingPanel = true; panel.level = .floating; panel.hidesOnDeactivate = false; panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]
            panel.contentView = NSHostingView(rootView:HUDView(model:model,close:{ [weak self] in self?.hud?.orderOut(nil) }))
            hud = panel
        }
        hud?.alphaValue = 1
        resizeHUD(); hud?.orderFrontRegardless()
    }
    @objc func refineService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let source = try? model.editor.invocationSource(exclusions: model.preferences.excludedApps) else {
            error.pointee = L("This app is excluded, or no editable field is focused.") as NSString; return
        }
        guard let text = pasteboard.string(forType:.string), text.utf16.count <= 20_000 else { error.pointee = L("Select up to 20,000 characters.") as NSString; return }
        if let snapshot = try? model.editor.capture(exclusions:model.preferences.excludedApps,compatibilityPaste:model.preferences.compatibilityPaste), snapshot.pid == source.pid, snapshot.appID == source.appID, snapshot.draft == text, snapshot.canReplace {
            model.refine()
        } else { model.rewriteReference(text,action:.refine,source:source) }
    }
    @objc func translateService(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let source = try? model.editor.invocationSource(exclusions: model.preferences.excludedApps) else {
            error.pointee = L("This app is excluded, or no editable field is focused.") as NSString; return
        }
        guard let text = pasteboard.string(forType:.string), text.utf16.count <= 20_000 else { error.pointee = L("Select up to 20,000 characters.") as NSString; return }
        showTranslation(text:text, snapshot:try? model.editor.capture(exclusions:model.preferences.excludedApps,compatibilityPaste:model.preferences.compatibilityPaste),source:source)
    }
    @objc func openTranslation() {
        showTranslation(text:model.editor.selectedReference(exclusions:model.preferences.excludedApps),snapshot:try? model.editor.capture(exclusions:model.preferences.excludedApps,compatibilityPaste:model.preferences.compatibilityPaste),source:try? model.editor.invocationSource(exclusions:model.preferences.excludedApps))
    }
    private func showTranslation(text: String?, snapshot: EditorSnapshot?, source: InvocationSource?) {
        translationWindow?.close()
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:520,height:510),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        window.title = L("Translate"); window.isReleasedWhenClosed = false; window.delegate = self
        window.contentView = NSHostingView(rootView:TranslationPicker(preferences:model.preferences,hasSelection:text != nil || snapshot != nil) { [weak self] language in
            guard let self else { return }
            self.restoringTranslation = true
            self.translationWindow?.close()
            guard let source, source.allowed(exclusions:self.model.preferences.excludedApps) else {
                self.restoringTranslation = false
                if text == nil && snapshot == nil { self.model.pendingTranslation = language }
                return
            }
            NSRunningApplication(processIdentifier:source.pid)?.activate()
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer { self.restoringTranslation = false }
                // Closing the picker must precede focus restoration. Never recapture a different field.
                try? await Task.sleep(for:.milliseconds(300))
                guard source.allowed(exclusions:self.model.preferences.excludedApps) else { return }
                if let snapshot, snapshot.pid == source.pid, snapshot.appID == source.appID,
                   snapshot.canReplace, text == nil || text == snapshot.draft,
                   self.model.editor.unchanged(snapshot) {
                    self.model.refine(action:.translate(language),capturedSnapshot:snapshot)
                } else if let captured = text ?? snapshot?.draft {
                    self.model.rewriteReference(captured,action:.translate(language),source:source)
                } else { self.model.pendingTranslation = language }
            }
        })
        window.center(); translationWindow = window
        translationExpiry = Task { [weak self] in
            try? await Task.sleep(for:.seconds(120))
            guard !Task.isCancelled else { return }; self?.translationWindow?.close()
        }
        NSApp.activate(ignoringOtherApps:true); window.makeKeyAndOrderFront(nil)
    }
    @objc func openSupportLink(_ sender: NSMenuItem) {
        guard let title = sender.representedObject as? String,
              let url = title == "Contribute on GitHub" ? SupportLinks.repository : SupportLinks.issue(title) else { return }
        NSWorkspace.shared.open(url)
    }
    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(checkForUpdates) { return model.updates.canCheck }
        return true
    }
    @objc func checkForUpdates() { model.updates.check() }
    @objc func quitApp() { model.stop(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}
struct RootSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    var body: some View {
        Group {
        if preferences.onboarding { SettingsView(model:model,preferences:preferences,local:model.local,cloud:model.cloud) }
        else { OnboardingView(model:model, preferences:preferences, local:model.local) }
        }.environment(\.locale,Locale(identifier:preferences.resolvedLanguage.rawValue))
         .environment(\.layoutDirection,preferences.resolvedLanguage.isRTL ? .rightToLeft : .leftToRight)
         .id(preferences.interfaceLanguage)
    }
}
