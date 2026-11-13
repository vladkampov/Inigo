import AppKit
import ApplicationServices
import Carbon
import Combine
import CryptoKit
import InigoCore

@MainActor
final class AutomaticLayoutRepairController: ObservableObject {
    let catalog = InputSourceCatalog()
    @Published private(set) var status = "Automatic repair is off"
    @Published private(set) var paused = false
    private weak var model: AppModel?
    private let recognizer: LayoutRecognizing
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var subscriptions: Set<AnyCancellable> = []
    private var activation: NSObjectProtocol?
    private var observer: AXObserver?
    private var observedFocus: EditorFocus?
    private var pending: Task<Void, Never>?
    private var revision = UUID()
    private var blockedFocus: EditorFocus?
    private var suppression: (focus: EditorFocus, digest: SHA256.Digest, until: Date)?
    private var lastKey = Date.distantPast
    private var expectedSourceChange: String?

    init(model: AppModel, recognizer: LayoutRecognizing? = nil) {
        self.model = model; self.recognizer = recognizer ?? SystemLayoutRecognizer()
        paused = model.preferences.automaticLayoutRepairPaused
        catalog.onChange = { [weak self] in
            guard let self else { return }
            let ownChange = self.expectedSourceChange == self.catalog.selectedID
            self.expectedSourceChange = nil; self.invalidate()
            if !ownChange { self.suppression = nil }
        }
    }
    @discardableResult func selectSource(_ id: String) -> Bool {
        expectedSourceChange = id
        let selected = catalog.select(id)
        if !selected { expectedSourceChange = nil }
        return selected
    }
    func start() {
        guard subscriptions.isEmpty, let model else { return }
        model.preferences.$automaticLayoutRepair.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }.store(in: &subscriptions)
        model.preferences.$exclusions.dropFirst().sink { [weak self] _ in
            Task { @MainActor in self?.invalidate(); self?.refreshFocus() }
        }.store(in: &subscriptions)
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.invalidate(); self?.refreshFocus() }
        }
        refresh()
    }
    func requestEnable() {
        guard let model else { return }
        model.preferences.automaticLayoutRepair = true
        if !AXIsProcessTrusted() { AccessibilityEditor.requestPermission() }
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        paused = false; model.preferences.automaticLayoutRepairPaused = false; refresh()
    }
    func togglePaused() { paused.toggle(); model?.preferences.automaticLayoutRepairPaused = paused; refresh() }
    func refresh() {
        stopListening()
        guard let model, model.preferences.automaticLayoutRepair else { model?.clearAutomaticResult(); status = "Automatic repair is off"; return }
        guard !paused else { status = "Automatic repair is paused"; return }
        guard AXIsProcessTrusted(), CGPreflightListenEventAccess() else { status = "Automatic repair needs Accessibility and keyboard listening access"; return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<AutomaticLayoutRepairController>.fromOpaque(pointer).takeUnretainedValue()
            MainActor.assumeIsolated {
                // No Unicode strings are extracted from events or retained.
                controller.receive(type: type, key: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags,
                                   synthetic: event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(getpid()))
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { status = "Keyboard listening is unavailable. Try enabling automatic repair again."; return }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        status = "Automatic repair is ready"; refreshFocus()
    }
    private func stopListening() {
        invalidate(); removeObserver(); suppression = nil; blockedFocus = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil; runLoopSource = nil
    }
    func stop() {
        stopListening(); subscriptions.removeAll()
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }; activation = nil
    }
    /// Called before manual operations as well as from input/focus notifications.
    func cancelPending() { revision = UUID(); pending?.cancel(); pending = nil }
    private func invalidate() { cancelPending(); model?.cancelAutomaticOperation() }
    private func removeObserver() {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil; observedFocus = nil
    }
    private func refreshFocus() {
        guard let model else { return }
        let focus = model.editor.automaticFocus(exclusions: model.preferences.excludedApps)
        guard focus != observedFocus else { return }
        removeObserver(); blockedFocus = nil; suppression = nil
        guard tap != nil, let focus else { return }
        observedFocus = focus
        var created: AXObserver?
        guard AXObserverCreate(focus.pid, { _, _, notification, pointer in
            guard let pointer else { return }
            MainActor.assumeIsolated {
                let controller = Unmanaged<AutomaticLayoutRepairController>.fromOpaque(pointer).takeUnretainedValue()
                if notification as String == kAXFocusedUIElementChangedNotification {
                    controller.invalidate(); controller.refreshFocus()
                } else if !controller.isWriting, Date().timeIntervalSince(controller.lastKey) > 0.15 {
                    controller.invalidate()
                }
            }
        }, &created) == .success, let created else { return }
        observer = created
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, AXUIElementCreateApplication(focus.pid), kAXFocusedUIElementChangedNotification as CFString, pointer)
        AXObserverAddNotification(created, focus.element, kAXSelectedTextChangedNotification as CFString, pointer)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }
    private var isWriting: Bool { model?.isAutomaticOperation == true }
    private func receive(type: CGEventType, key: Int64, flags: CGEventFlags, synthetic: Bool) {
        guard !synthetic else { return }
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            paused = true; model?.preferences.automaticLayoutRepairPaused = true; stopListening(); status = "Keyboard listening stopped. Resume automatic repair to retry."; return
        }
        invalidate(); refreshFocus()
        guard type == .keyDown, !flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate),
              ![36, 48, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(key),
              let model, model.preferences.automaticLayoutRepair, !paused, model.permitsAutomaticOperation,
              let focus = observedFocus, focus != blockedFocus, let sourceID = catalog.selectedID else { return }
        lastKey = Date()
        let token = revision
        pending = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(LayoutRepairPolicy.idleMilliseconds)) } catch { return }
            guard let self, self.revision == token, !Task.isCancelled, model.permitsAutomaticOperation,
                  AXIsProcessTrusted(), CGPreflightListenEventAccess(), self.catalog.selectedID == sourceID,
                  model.editor.automaticFocus(exclusions: model.preferences.excludedApps) == focus,
                  let snapshot = model.editor.captureForLayoutRepair(exclusions: model.preferences.excludedApps),
                  let source = self.catalog.sources.first(where: { $0.id == sourceID && $0.supported }), let language = source.language else { return }
            if let suppression = self.suppression, suppression.focus == focus, suppression.until > Date(), suppression.digest == SHA256.hash(data: Data(snapshot.draft.utf8)) { return }
            let targets = self.catalog.sources.filter { $0.id != sourceID && $0.supported }.compactMap { target -> LayoutDetectionTarget? in
                guard let language = target.language else { return nil }
                return LayoutDetectionTarget(id: target.id, language: language, mapping: self.catalog.mapping(from: source, to: target))
            }
            let deadline = Date().addingTimeInterval(10)
            let winner = await LayoutRepairDetector.detect(snapshot.draft, caret: snapshot.selection.location, language: language, targets: targets,
                recognizer: self.recognizer, isCurrent: { self.revision == token && Date() < deadline })
            guard self.revision == token, !Task.isCancelled,
                  let winner,
                  self.catalog.selectedID == sourceID, model.permitsAutomaticOperation, model.editor.unchanged(snapshot) else { return }
            model.applyLayoutRepair(snapshot, candidate: winner, sourceID: sourceID)
        }
    }
    func mayWrite(sourceID: String) -> Bool {
        guard let model else { return false }
        return model.preferences.automaticLayoutRepair && !paused && tap != nil && AXIsProcessTrusted()
            && CGPreflightListenEventAccess() && !IsSecureEventInputEnabled() && catalog.selectedID == sourceID
    }
    func block(_ snapshot: EditorSnapshot) { blockedFocus = EditorFocus(element: snapshot.element, pid: snapshot.pid) }
    func suppress(_ snapshot: EditorSnapshot, original: String) {
        suppression = (EditorFocus(element: snapshot.element, pid: snapshot.pid), SHA256.hash(data: Data(original.utf8)), Date().addingTimeInterval(120))
    }
    func exclude(_ appID: String) {
        guard let model else { return }
        model.preferences.exclusions = model.preferences.excludedApps.union([appID]).sorted().joined(separator: "\n")
        invalidate()
    }
}
