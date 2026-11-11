import SwiftUI
import AppKit
import InigoCore

@MainActor
final class AppModel: ObservableObject {
    let reports = ErrorReports()
    let updates = UpdateManager()
    let loginItem = LoginItemManager()
    let preferences = Preferences()
    let local = LocalEngine()
    let cloud = CloudEngine()
    let editor = AccessibilityEditor()
    let shortcut = GlobalShortcut()
    let translationPickerShortcut = GlobalShortcut(identifier:3)
    @Published var translationPickerShortcutConflict = false
    var showTranslationPicker: (() -> Void)?
    let translationShortcut = GlobalShortcut(identifier:2)
    @Published var translationShortcutConflict = false
    @Published var message = "Ready when you are"
    @Published var working = false
    @Published var fallback = ""
    @Published var canUndo = false
    @Published var fallbackMayHaveChanged = false
    @Published var shortcutConflict = false
    var showSettings: (() -> Void)?
    var pendingTranslation: SupportedLanguage?
    var onboardingRefine: (() -> Void)?
    var hudAnchor: NSRect?
    var hudSucceeded: (() -> Void)?
    var showHUD: (() -> Void)?
    private var generation = UUID()
    private var task: Task<Void,Never>?
    private var monitor: Task<Void,Never>?
    private var retention: Task<Void,Never>?
    private var undoSnapshot: EditorSnapshot?
    private var original = ""
    init() { shortcut.onPress = { [weak self] in if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier, let practice = self?.onboardingRefine { practice() } else { self?.refine() } }; translationShortcut.onPress = { [weak self] in guard let self else { return }; self.refine(action:.translate(SupportedLanguage(rawValue:self.preferences.translationLanguage) ?? .en)) }; translationPickerShortcut.onPress = { [weak self] in self?.showTranslationPicker?() }; registerShortcut() }
    func registerShortcut() {
        shortcut.suspend(); translationShortcut.suspend(); translationPickerShortcut.suspend()
        shortcutConflict = !shortcut.register(key: preferences.shortcutKey, modifiers: preferences.shortcutModifiers)
        translationShortcutConflict = !translationShortcut.register(key:preferences.translationShortcutKey,modifiers:preferences.translationShortcutModifiers)
        translationPickerShortcutConflict = !translationPickerShortcut.register(key:preferences.translationPickerShortcutKey,modifiers:preferences.translationPickerShortcutModifiers)
    }
    func refine(action: RewriteAction = .refine, capturedSnapshot: EditorSnapshot? = nil) {
        let action = action == .refine ? (pendingTranslation.map(RewriteAction.translate) ?? action) : action
        pendingTranslation = nil
        cancel(); clearResult()
        hudAnchor = editor.focusedFrame()
        do {
            let snapshot = try capturedSnapshot ?? editor.capture(exclusions:preferences.excludedApps, compatibilityPaste:preferences.compatibilityPaste)
            guard InvocationPolicy.allowsSource(snapshot.appID, ownAppID:Bundle.main.bundleIdentifier, exclusions:preferences.excludedApps), editor.unchanged(snapshot) else { throw CancellationError() }
            let protected = try ProtectedDraft(snapshot.draft)
            let language = Preferences.language(snapshot.draft)
            let request = RewriteRequest(draft:protected.masked,context:snapshot.context,style:action == .refine ? preferences.profile.preferences(for:language) : [],action:action)
            let mode = preferences.mode
            let runID = generation
            working = true; message = action != .refine ? "Working on your selection…" : (mode == "Local" ? "Refining on your Mac…" : "Refining with ChatGPT…"); showHUD?()
            monitor = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for:.milliseconds(150))
                    guard !Task.isCancelled, let self else { return }
                    if !self.editor.unchanged(snapshot) { self.cancel(); self.message = "Cancelled · your draft changed"; return }
                }
            }
            task = Task { [weak self] in
                guard let self else { return }
                do {
                    let output = try await (mode == "Local" ? self.local.rewrite(request) : self.cloud.rewrite(request))
                    try Task.checkCancellation()
                    guard self.generation == runID else { return }
                    guard InvocationPolicy.allowsSource(snapshot.appID, ownAppID: Bundle.main.bundleIdentifier, exclusions:self.preferences.excludedApps), self.preferences.mode == mode, self.editor.unchanged(snapshot) else { throw CancellationError() }
                    let result = try protected.restore(output)
                    self.monitor?.cancel(); self.monitor = nil
                    if result == snapshot.draft { self.message = "Already clear · no changes"; self.hudSucceeded?() }
                    else if snapshot.canReplace {
                        do {
                            let applied = try await self.editor.replace(snapshot,with:result)
                            guard self.generation == runID else { return }
                            self.undoSnapshot = applied.canReplace ? applied : nil; self.original = applied.canReplace ? snapshot.draft : ""; self.canUndo = applied.canReplace; self.message = action == .refine ? "Refined" : "Translated"
                            self.hudSucceeded?()
                            if action == .refine { self.observeRetention(snapshot:snapshot, result:result, language:language) } else { self.expireFallback() }
                        } catch {
                            guard self.generation == runID else { return }
                            if (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged == true { self.reports.capture(.replacementUnconfirmed) }
                            self.fallbackMayHaveChanged = (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged ?? false
                            self.fallback = result; self.message = error.localizedDescription; self.expireFallback()
                        }
                    } else { self.fallback = result; self.message = snapshot.fallbackReason ?? "Copy your refined text"; self.expireFallback() }
                } catch is CancellationError { guard self.generation == runID else { return }; self.message = "Cancelled · your draft is unchanged" }
                catch { guard self.generation == runID else { return }; if !Task.isCancelled { self.reports.capture(.rewriteFailed); self.message = error.localizedDescription } }
                guard self.generation == runID else { return }
                self.working = false; self.monitor?.cancel(); self.monitor = nil
            }
        } catch {
            if let source = try? editor.invocationSource(exclusions:preferences.excludedApps),
               let selection = editor.selectedReference(exclusions:preferences.excludedApps) {
                rewriteReference(selection,action:action,source:source)
            } else { message = error.localizedDescription; showHUD?() }
        }
    }
    func rewriteReference(_ text: String, action: RewriteAction, source: InvocationSource) {
        cancel(); clearResult(); hudAnchor = editor.focusedFrame()
        guard source.allowed(exclusions: preferences.excludedApps) else {
            message = "This app is excluded, or no editable field is focused."; showHUD?(); return
        }
        guard !text.isEmpty, text.utf16.count <= 20_000 else { message = "Select up to 20,000 characters."; showHUD?(); return }
        working = true; message = "Working on your selection…"; showHUD?()
        let runID = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let protected = try ProtectedDraft(text)
                guard source.allowed(exclusions: preferences.excludedApps) else { throw CancellationError() }
                let output = try await local.rewrite(RewriteRequest(draft:protected.masked,action:action))
                try Task.checkCancellation(); guard generation == runID else { return }
                guard source.allowed(exclusions: preferences.excludedApps) else { throw CancellationError() }
                fallback = try protected.restore(output); message = "Your selection is ready"; expireFallback()
            } catch { guard generation == runID else { return }; if !(error is CancellationError) { reports.capture(.rewriteFailed) }; message = error.localizedDescription }
            working = false
        }
    }
    private func observeRetention(snapshot: EditorSnapshot, result: String, language: String) {
        retention = Task { [weak self] in
            try? await Task.sleep(for:.seconds(20)); guard !Task.isCancelled, let self else { return }
            // Only an unchanged, still-focused result is weak evidence. No background reading after this check.
            if let undo = self.undoSnapshot, self.preferences.learning, self.editor.unchanged(undo,selection:false) {
                self.preferences.profile.observe(original:snapshot.draft, revision:result, language:language)
            }
            try? await Task.sleep(for:.seconds(100)); guard !Task.isCancelled else { return }; self.clearResult()
        }
    }
    private func expireFallback() {
        retention = Task { [weak self] in try? await Task.sleep(for:.seconds(120)); guard !Task.isCancelled else { return }; self?.clearResult() }
    }
    func undo() {
        retention?.cancel()
        guard let snapshot = undoSnapshot, !working else { return }
        let savedOriginal = original
        canUndo = false; working = true
        let runID = generation
        task = Task {
            do {
                _ = try await editor.replace(snapshot, with: savedOriginal)
                guard generation == runID else { return }
                message = "Original restored"; hudSucceeded?()
            } catch {
                guard generation == runID else { return }
                message = (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged == true
                    ? "Undo could not be confirmed. Check the original field."
                    : "Undo unavailable · the field changed. Your newer writing is untouched."
            }
            working = false; clearResult()
        }
    }
    func copy() { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(fallback,forType:.string); message = "Copied · paste it where you need it"; clearResult(); hudSucceeded?() }
    func cancel() { generation = UUID(); task?.cancel(); task = nil; monitor?.cancel(); monitor = nil; working = false }
    func clearResult() { retention?.cancel(); retention = nil; undoSnapshot = nil; original = ""; fallback = ""; fallbackMayHaveChanged = false; canUndo = false }
    func stop() { cancel(); clearResult(); local.stop(); cloud.stop() }
}
