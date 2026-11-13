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
    lazy var automaticLayout = AutomaticLayoutRepairController(model: self)
    @Published var lastOperationDetails = ""
    var pickerOpen = false
    private(set) var isAutomaticOperation = false
    var permitsAutomaticOperation: Bool { !working && !pickerOpen && preferences.onboarding && !NSApp.isActive }
    private var layoutUndo: (source: String, target: String, caret: NSRange)?
    private var timing: OperationTiming?
    private var processing: ProcessingCategory = .customLocal
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
    private func beginTiming(_ category: ProcessingCategory? = nil) {
        timing = OperationTiming()
        if let category { processing = category }
        else if preferences.mode != "Local" { processing = .cloud }
        else { processing = .local(local.configuration) }
    }
    private func stage(_ stage: OperationStage, action: RewriteAction) {
        timing?.transition(stage)
        switch stage {
        case .load: message = "Loading model…"
        case .generate: message = processing.generationMessage(for: action)
        case .validate: message = "Checking the result…"
        case .insert: message = "Applying the result…"
        case .capture: break
        }
    }
    private func finishTiming(_ outcome: OperationOutcome) {
        guard var timing else { return }
        timing.finish(outcome)
        lastOperationDetails = OperationDetails(timing: timing, processing: processing).summary(version: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")
        self.timing = nil
    }
    func copyOperationDetails() {
        guard !lastOperationDetails.isEmpty else { return }
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(lastOperationDetails, forType: .string)
    }
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
        beginTiming()
        hudAnchor = editor.focusedFrame()
        do {
            let snapshot = try capturedSnapshot ?? editor.capture(exclusions:preferences.excludedApps, compatibilityPaste:preferences.compatibilityPaste)
            guard InvocationPolicy.allowsSource(snapshot.appID, ownAppID:Bundle.main.bundleIdentifier, exclusions:preferences.excludedApps), editor.unchanged(snapshot) else { throw CancellationError() }
            let protected = try ProtectedDraft(snapshot.draft)
            let language = Preferences.language(snapshot.draft)
            let request = RewriteRequest(draft:protected.masked,context:snapshot.context,style:action == .refine ? preferences.profile.preferences(for:language) : [],action:action)
            let mode = preferences.mode
            let runID = generation
            working = true; message = processing.generationMessage(for: action); showHUD?()
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
                    let output: String
                    if mode == "Local" {
                        output = try await self.local.rewrite(request) { [weak self] stage in
                            guard let self, self.generation == runID else { return }; self.stage(stage, action: action)
                        }
                    } else { self.stage(.generate, action: action); output = try await self.cloud.rewrite(request) }
                    try Task.checkCancellation()
                    guard self.generation == runID else { return }
                    guard InvocationPolicy.allowsSource(snapshot.appID, ownAppID: Bundle.main.bundleIdentifier, exclusions:self.preferences.excludedApps), self.preferences.mode == mode, self.editor.unchanged(snapshot) else { throw CancellationError() }
                    self.stage(.validate, action: action)
                    let result = try protected.restore(output)
                    self.monitor?.cancel(); self.monitor = nil
                    if result == snapshot.draft { self.finishTiming(.unchanged); self.message = "Already clear · no changes"; self.hudSucceeded?() }
                    else if snapshot.canReplace {
                        do {
                            self.stage(.insert, action: action)
                            let applied = try await self.editor.replace(snapshot,with:result, allowed: { InvocationPolicy.allowsSource(snapshot.appID, ownAppID: Bundle.main.bundleIdentifier, exclusions: self.preferences.excludedApps) })
                            guard self.generation == runID else { return }
                            self.undoSnapshot = applied.canReplace ? applied : nil; self.original = applied.canReplace ? snapshot.draft : ""; self.canUndo = applied.canReplace; self.message = action == .refine ? "Refined" : "Translated"
                            self.hudSucceeded?()
                            self.finishTiming(.replaced)
                            if action == .refine { self.observeRetention(snapshot:snapshot, result:result, language:language) } else { self.expireFallback() }
                        } catch {
                            guard self.generation == runID else { return }
                            if (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged == true { self.reports.capture(.replacementUnconfirmed) }
                            self.fallbackMayHaveChanged = (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged ?? false
                            self.fallback = result; self.message = error.localizedDescription; self.expireFallback()
                            self.finishTiming(self.fallbackMayHaveChanged ? .failed : .copyOnly)
                        }
                    } else { self.fallback = result; self.message = snapshot.fallbackReason ?? "Copy your refined text"; self.expireFallback(); self.finishTiming(.copyOnly) }
                } catch is CancellationError { guard self.generation == runID else { return }; self.finishTiming(.cancelled); self.message = "Cancelled · your draft is unchanged" }
                catch { guard self.generation == runID else { return }; self.finishTiming(.failed); if !Task.isCancelled { self.reports.capture(.rewriteFailed); self.message = error.localizedDescription } }
                guard self.generation == runID else { return }
                self.working = false; self.monitor?.cancel(); self.monitor = nil
            }
        } catch {
            if let source = try? editor.invocationSource(exclusions:preferences.excludedApps),
               let selection = editor.selectedReference(exclusions:preferences.excludedApps) {
                rewriteReference(selection,action:action,source:source)
            } else { finishTiming(.failed); message = error.localizedDescription; showHUD?() }
        }
    }
    func rewriteReference(_ text: String, action: RewriteAction, source: InvocationSource) {
        cancel(); clearResult(); hudAnchor = editor.focusedFrame()
        // This fallback runs the local engine regardless of the manual mode preference.
        beginTiming(.local(local.configuration))
        guard source.allowed(exclusions: preferences.excludedApps) else {
            finishTiming(.failed)
            message = preferences.excludedApps.contains(source.appID) ? "This app is excluded. Change Apps Inigo should ignore in Privacy settings." : "Focus an editable text field in another app."
            showHUD?(); return
        }
        guard !text.isEmpty, text.utf16.count <= 20_000 else { finishTiming(.failed); message = "Select up to 20,000 characters."; showHUD?(); return }
        working = true; message = "Working on your selection…"; showHUD?()
        let runID = generation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let protected = try ProtectedDraft(text)
                guard source.allowed(exclusions: preferences.excludedApps) else { throw CancellationError() }
                let output = try await local.rewrite(RewriteRequest(draft:protected.masked,action:action)) { [weak self] stage in
                    guard let self, self.generation == runID else { return }; self.stage(stage, action: action)
                }
                try Task.checkCancellation(); guard generation == runID else { return }
                guard source.allowed(exclusions: preferences.excludedApps) else { throw CancellationError() }
                fallback = try protected.restore(output); message = "Your selection is ready"; expireFallback()
                finishTiming(.copyOnly)
            } catch { guard generation == runID else { return }; finishTiming(error is CancellationError ? .cancelled : .failed); if !(error is CancellationError) { reports.capture(.rewriteFailed) }; message = error.localizedDescription }
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
        guard let snapshot = undoSnapshot, !working else { return }
        cancel(); retention?.cancel()
        let savedOriginal = original
        let layout = layoutUndo
        canUndo = false; working = true
        let runID = generation
        task = Task {
            do {
                _ = try await editor.replace(snapshot, with: savedOriginal, restoringSelection: layout?.caret)
                guard generation == runID else { return }
                if let layout {
                    if automaticLayout.catalog.selectedID == layout.target { automaticLayout.selectSource(layout.source) }
                    automaticLayout.suppress(snapshot, original: savedOriginal)
                }
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
    func cancel() { automaticLayout.cancelPending(); finishTiming(.cancelled); generation = UUID(); task?.cancel(); task = nil; monitor?.cancel(); monitor = nil; working = false; isAutomaticOperation = false }
    func clearResult() { retention?.cancel(); retention = nil; undoSnapshot = nil; layoutUndo = nil; original = ""; fallback = ""; fallbackMayHaveChanged = false; canUndo = false }
    func cancelAutomaticOperation() { if isAutomaticOperation { cancel() } }
    func clearAutomaticResult() { if layoutUndo != nil { clearResult() } }
    func applyLayoutRepair(_ snapshot: EditorSnapshot, candidate: LayoutRepairCandidate, sourceID: String) {
        guard permitsAutomaticOperation, automaticLayout.mayWrite(sourceID: sourceID), editor.unchanged(snapshot) else { return }
        cancel(); clearResult(); beginTiming(.layout)
        working = true; isAutomaticOperation = true
        let runID = generation
        timing?.transition(.insert)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let applied = try await editor.replace(snapshot, with: candidate.conversion.text,
                    restoringSelection: NSRange(location: candidate.conversion.caret, length: 0), allowed: {
                        self.generation == runID && self.automaticLayout.mayWrite(sourceID: sourceID)
                            && !self.preferences.excludedApps.contains(snapshot.appID)
                    })
                guard generation == runID else { return }
                isAutomaticOperation = false; working = false
                guard applied.canReplace else { throw AccessibilityEditor.ReplacementError.unconfirmed }
                undoSnapshot = applied; original = snapshot.draft; canUndo = true
                layoutUndo = (sourceID, candidate.sourceID, snapshot.selection)
                let switched = editor.unchanged(applied) && automaticLayout.mayWrite(sourceID: sourceID) && automaticLayout.selectSource(candidate.sourceID)
                message = switched ? "Layout corrected" : "Text corrected. Switch your keyboard layout to continue."
                finishTiming(.replaced); hudAnchor = editor.focusedFrame(); showHUD?(); hudSucceeded?(); expireFallback()
            } catch {
                let uncertain = (error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged == true
                if uncertain { automaticLayout.block(snapshot) }
                guard generation == runID else { return }
                if uncertain {
                    message = "Layout correction could not be confirmed. Check the original field."
                    hudAnchor = editor.focusedFrame(); showHUD?()
                }
                finishTiming(error is CancellationError ? .cancelled : .failed)
                working = false; isAutomaticOperation = false
            }
        }
    }
    func stop() { automaticLayout.stop(); cancel(); clearResult(); local.stop(); cloud.stop() }
}
