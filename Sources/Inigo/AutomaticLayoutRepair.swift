import AppKit
import ApplicationServices
import Carbon
import Combine
import CryptoKit
import InigoCore

enum AutomaticRepairEvent {
    case keyDown(key: Int64, flags: CGEventFlags, synthetic: Bool)
    case pointerDown, focusChanged, selectionChanged, activationChanged, listeningStopped, permissionsChanged
}

@MainActor
protocol AutomaticRepairEnvironment: AnyObject {
    var preferences: Preferences { get }
    var permitsOperation: Bool { get }
    var isWriting: Bool { get }
    var permissionsGranted: Bool { get }
    var selectedSourceID: String? { get }
    var onSourceChange: (() -> Void)? { get set }
    func language(for sourceID: String) -> String?
    func targets(from sourceID: String) -> [LayoutDetectionTarget]
    func selectSource(_ id: String) -> Bool
    func focus() -> EditorFocus?
    func capture() -> EditorSnapshot?
    func unchanged(_ snapshot: EditorSnapshot) -> Bool
    func apply(_ snapshot: EditorSnapshot, candidate: LayoutRepairCandidate, sourceID: String)
    func cancelOperation()
    func clearResult()
    func requestPermissions()
    func startEvents(_ receive: @escaping (AutomaticRepairEvent) -> Void) -> Bool
    func observeFocus(_ focus: EditorFocus?)
    func stopEvents()
}

@MainActor
struct AutomaticRepairClock {
    var now: () -> Date
    var sleep: (Duration) async throws -> Void
    static var system: Self { Self(now: Date.init, sleep: { try await Task.sleep(for: $0) }) }
}

struct LayoutUndoState {
    let originalSourceID: String
    let selectedSourceID: String
    let sourceRevision: UInt64?
    let caret: NSRange

    func sourceToRestore(currentID: String?, revision: UInt64) -> String? {
        guard let sourceRevision, sourceRevision == revision, currentID == selectedSourceID,
              selectedSourceID != originalSourceID else { return nil }
        return originalSourceID
    }
}

@MainActor
final class SystemAutomaticRepairEnvironment: AutomaticRepairEnvironment {
    let preferences: Preferences
    private weak var model: AppModel?
    private let catalog: InputSourceCatalog
    var onSourceChange: (() -> Void)?
    private var receive: ((AutomaticRepairEvent) -> Void)?
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var activation: NSObjectProtocol?
    private var observer: AXObserver?

    init(model: AppModel) {
        self.model = model; preferences = model.preferences; catalog = model.inputSources
        catalog.onChange = { [weak self] in self?.onSourceChange?() }
    }
    var permitsOperation: Bool { model?.permitsAutomaticOperation == true }
    var isWriting: Bool { model?.isAutomaticOperation == true }
    var permissionsGranted: Bool { AXIsProcessTrusted() && CGPreflightListenEventAccess() && !IsSecureEventInputEnabled() }
    var selectedSourceID: String? { catalog.selectedID }
    func language(for sourceID: String) -> String? { catalog.sources.first { $0.id == sourceID && $0.supported }?.language }
    func targets(from sourceID: String) -> [LayoutDetectionTarget] {
        guard let source = catalog.sources.first(where: { $0.id == sourceID && $0.supported }) else { return [] }
        return catalog.sources.filter { $0.id != sourceID && $0.supported }.compactMap { target in
            guard let language = target.language else { return nil }
            return LayoutDetectionTarget(id: target.id, language: language, mapping: catalog.mapping(from: source, to: target))
        }
    }
    func selectSource(_ id: String) -> Bool { catalog.select(id) }
    func focus() -> EditorFocus? { model?.editor.automaticFocus(exclusions: preferences.excludedApps) }
    func capture() -> EditorSnapshot? { model?.editor.captureForLayoutRepair(exclusions: preferences.excludedApps) }
    func unchanged(_ snapshot: EditorSnapshot) -> Bool { model?.editor.unchanged(snapshot) == true }
    func apply(_ snapshot: EditorSnapshot, candidate: LayoutRepairCandidate, sourceID: String) { model?.applyLayoutRepair(snapshot, candidate: candidate, sourceID: sourceID) }
    func cancelOperation() { model?.cancelAutomaticOperation() }
    func clearResult() { model?.clearAutomaticResult() }
    func requestPermissions() {
        if !AXIsProcessTrusted() { AccessibilityEditor.requestPermission() }
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
    }
    func startEvents(_ receive: @escaping (AutomaticRepairEvent) -> Void) -> Bool {
        self.receive = receive
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.rightMouseDown.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .tailAppendEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            MainActor.assumeIsolated {
                let environment = Unmanaged<SystemAutomaticRepairEnvironment>.fromOpaque(pointer).takeUnretainedValue()
                switch type {
                case .tapDisabledByTimeout, .tapDisabledByUserInput: environment.receive?(.listeningStopped)
                case .keyDown:
                    // Only timing/key metadata is used; never extract Unicode keystroke text.
                    environment.receive?(.keyDown(key: event.getIntegerValueField(.keyboardEventKeycode), flags: event.flags,
                        synthetic: event.getIntegerValueField(.eventSourceUnixProcessID) == Int64(getpid())))
                default: environment.receive?(.pointerDown)
                }
            }
            return Unmanaged.passUnretained(event)
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { self.receive = nil; return false }
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource { CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        CGEvent.tapEnable(tap: tap, enable: true)
        activation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.receive?(.activationChanged) }
        }
        return true
    }
    func observeFocus(_ focus: EditorFocus?) {
        if let observer { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes) }
        observer = nil
        guard let focus else { return }
        var created: AXObserver?
        guard AXObserverCreate(focus.pid, { _, _, notification, pointer in
            guard let pointer else { return }
            MainActor.assumeIsolated {
                let environment = Unmanaged<SystemAutomaticRepairEnvironment>.fromOpaque(pointer).takeUnretainedValue()
                environment.receive?(notification as String == kAXFocusedUIElementChangedNotification ? .focusChanged : .selectionChanged)
            }
        }, &created) == .success, let created else { return }
        observer = created
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, AXUIElementCreateApplication(focus.pid), kAXFocusedUIElementChangedNotification as CFString, pointer)
        AXObserverAddNotification(created, focus.element, kAXSelectedTextChangedNotification as CFString, pointer)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
    }
    func stopEvents() {
        observeFocus(nil)
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        if let activation { NSWorkspace.shared.notificationCenter.removeObserver(activation) }
        tap = nil; runLoopSource = nil; activation = nil; receive = nil
    }
}

@MainActor
final class AutomaticLayoutRepairController: ObservableObject {
    @Published private(set) var status = "Automatic repair is off"
    @Published private(set) var paused: Bool
    private let environment: any AutomaticRepairEnvironment
    private let recognizer: any LayoutRecognizing
    private let clock: AutomaticRepairClock
    private var subscriptions: Set<AnyCancellable> = []
    private var started = false
    private var listening = false
    private var observedFocus: EditorFocus?
    private var pending: Task<Void, Never>?
    private var revision = UUID()
    private var blockedFocus: EditorFocus?
    private var suppression: (focus: EditorFocus, digest: SHA256.Digest, until: Date)?
    private var lastKey = Date.distantPast
    private var expectedSourceChange: String?
    private(set) var sourceRevision: UInt64 = 0
    var selectedSourceID: String? { environment.selectedSourceID }

    init(environment: any AutomaticRepairEnvironment, recognizer: any LayoutRecognizing, clock: AutomaticRepairClock) {
        self.environment = environment; self.recognizer = recognizer; self.clock = clock
        paused = environment.preferences.automaticLayoutRepairPaused
        environment.onSourceChange = { [weak self] in self?.sourceChanged() }
    }
    convenience init(model: AppModel) {
        self.init(environment: SystemAutomaticRepairEnvironment(model: model), recognizer: SystemLayoutRecognizer(), clock: .system)
    }
    private func sourceChanged() {
        let ownChange = expectedSourceChange != nil && expectedSourceChange == selectedSourceID
        expectedSourceChange = nil; invalidate()
        if !ownChange { sourceRevision &+= 1; suppression = nil }
    }
    @discardableResult func selectSource(_ id: String) -> Bool {
        expectedSourceChange = id
        let selected = environment.selectSource(id)
        if !selected { expectedSourceChange = nil }
        return selected
    }
    func undoState(sourceID: String, targetID: String, switched: Bool, caret: NSRange) -> LayoutUndoState {
        LayoutUndoState(originalSourceID: sourceID, selectedSourceID: switched ? targetID : sourceID,
                        sourceRevision: switched ? sourceRevision : nil, caret: caret)
    }
    func restoreSource(for undo: LayoutUndoState) {
        if let source = undo.sourceToRestore(currentID: selectedSourceID, revision: sourceRevision) { selectSource(source) }
    }
    func start() {
        guard !started else { return }; started = true
        environment.preferences.$automaticLayoutRepair.dropFirst().sink { [weak self] _ in
            Task { @MainActor in guard let self, self.started else { return }; self.refresh() }
        }.store(in: &subscriptions)
        environment.preferences.$exclusions.dropFirst().sink { [weak self] _ in
            Task { @MainActor in guard let self, self.started else { return }; self.invalidate(); self.refreshFocus() }
        }.store(in: &subscriptions)
        refresh()
    }
    func requestEnable() {
        environment.preferences.automaticLayoutRepair = true; environment.requestPermissions()
        paused = false; environment.preferences.automaticLayoutRepairPaused = false; refresh()
    }
    func togglePaused() {
        paused.toggle(); environment.preferences.automaticLayoutRepairPaused = paused; refresh()
    }
    func refresh() {
        stopListening()
        guard environment.preferences.automaticLayoutRepair else { environment.clearResult(); status = "Automatic repair is off"; return }
        guard !paused else { status = "Automatic repair is paused"; return }
        guard environment.permissionsGranted else { status = "Automatic repair needs Accessibility and keyboard listening access"; return }
        listening = environment.startEvents { [weak self] in self?.receive($0) }
        guard listening else { status = "Keyboard listening is unavailable. Try enabling automatic repair again."; return }
        status = "Automatic repair is ready"; refreshFocus()
    }
    private func stopListening() {
        invalidate(); environment.stopEvents(); listening = false; observedFocus = nil
        suppression = nil; blockedFocus = nil; sourceRevision &+= 1
    }
    func stop() { stopListening(); subscriptions.removeAll(); started = false }
    func cancelPending() { revision = UUID(); pending?.cancel(); pending = nil }
    private func invalidate() { cancelPending(); environment.cancelOperation() }
    private func refreshFocus() {
        let focus = environment.focus()
        guard focus != observedFocus else { return }
        observedFocus = focus; blockedFocus = nil; suppression = nil
        environment.observeFocus(listening ? focus : nil)
    }
    private func receive(_ event: AutomaticRepairEvent) {
        switch event {
        case .keyDown(_, _, true): return
        case .listeningStopped:
            paused = true; environment.preferences.automaticLayoutRepairPaused = true; stopListening()
            status = "Keyboard listening stopped. Resume automatic repair to retry."; return
        case .permissionsChanged:
            invalidate()
            if !environment.permissionsGranted {
                stopListening(); status = "Automatic repair needs Accessibility and keyboard listening access"
            }
            return
        case .focusChanged, .activationChanged: invalidate(); refreshFocus(); return
        case .selectionChanged:
            if !environment.isWriting, clock.now().timeIntervalSince(lastKey) > 0.15 { invalidate() }
            return
        case .pointerDown: invalidate(); refreshFocus(); return
        case .keyDown(let key, let flags, _):
            invalidate(); refreshFocus()
            guard !flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate),
                  ![36, 48, 53, 76, 115, 116, 117, 119, 121, 123, 124, 125, 126].contains(key),
                  let focus = observedFocus, focus != blockedFocus, let sourceID = selectedSourceID,
                  canRun(sourceID: sourceID, focus: focus) else { return }
            lastKey = clock.now()
            schedule(sourceID: sourceID, focus: focus)
        }
    }
    private func canRun(sourceID: String, focus: EditorFocus) -> Bool {
        mayWrite(sourceID: sourceID) && environment.permitsOperation && environment.focus() == focus
    }
    private func schedule(sourceID: String, focus: EditorFocus) {
        let token = revision
        pending = Task { [weak self] in
            guard let self else { return }
            do { try await clock.sleep(.milliseconds(LayoutRepairPolicy.idleMilliseconds)) } catch { return }
            guard revision == token, !Task.isCancelled, canRun(sourceID: sourceID, focus: focus),
                  let snapshot = environment.capture(), let language = environment.language(for: sourceID) else { return }
            if let suppression, suppression.focus == focus, suppression.until > clock.now(),
               suppression.digest == SHA256.hash(data: Data(snapshot.draft.utf8)) { return }
            let deadline = clock.now().addingTimeInterval(10)
            let winner = await LayoutRepairDetector.detect(snapshot.draft, caret: snapshot.selection.location, language: language,
                targets: environment.targets(from: sourceID), recognizer: recognizer, isCurrent: {
                    self.revision == token && self.clock.now() < deadline && self.canRun(sourceID: sourceID, focus: focus)
                })
            guard revision == token, !Task.isCancelled, let winner, canRun(sourceID: sourceID, focus: focus),
                  environment.unchanged(snapshot) else { return }
            environment.apply(snapshot, candidate: winner, sourceID: sourceID)
        }
    }
    func mayWrite(sourceID: String) -> Bool {
        environment.preferences.automaticLayoutRepair && !paused && listening && environment.permissionsGranted && selectedSourceID == sourceID
    }
    func block(_ snapshot: EditorSnapshot) { blockedFocus = EditorFocus(element: snapshot.element, pid: snapshot.pid) }
    func suppress(_ snapshot: EditorSnapshot, original: String) {
        suppression = (EditorFocus(element: snapshot.element, pid: snapshot.pid), SHA256.hash(data: Data(original.utf8)), clock.now().addingTimeInterval(120))
    }
    func exclude(_ appID: String) {
        environment.preferences.exclusions = environment.preferences.excludedApps.union([appID]).sorted().joined(separator: "\n")
        invalidate()
    }
}
