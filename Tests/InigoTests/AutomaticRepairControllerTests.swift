import XCTest
import AppKit
import Carbon
import InigoCore
@testable import Inigo

@MainActor
private final class ManualRepairClock {
    var date = Date(timeIntervalSince1970: 1000)
    var sleepers: [CheckedContinuation<Void, Error>] = []
    var clock: AutomaticRepairClock {
        AutomaticRepairClock(now: { self.date }, sleep: { _ in
            try await withCheckedThrowingContinuation { self.sleepers.append($0) }
        })
    }
    func advanceFirst() {
        date.addTimeInterval(0.8)
        if !sleepers.isEmpty { sleepers.removeFirst().resume() }
    }
    func finish() { let pending = sleepers; sleepers = []; for item in pending { item.resume() } }
}

@MainActor
private final class SuspendedRepairRecognizer: LayoutRecognizing {
    var suspendNext = false
    var calls = 0
    var waiting: CheckedContinuation<Void, Never>?
    func recognition(_ text: String, language: String) async -> Double? {
        calls += 1
        if suspendNext {
            suspendNext = false
            await withCheckedContinuation { waiting = $0 }
        }
        return language == "en" ? 0 : 1
    }
    func resume() { waiting?.resume(); waiting = nil }
}

@MainActor
private final class FakeRepairEnvironment: AutomaticRepairEnvironment {
    let preferences: Preferences
    let defaults: UserDefaults
    let suite = "inigo-controller-tests-" + UUID().uuidString
    let element = AXUIElementCreateApplication(12345)
    let otherElement = AXUIElementCreateApplication(12346)
    var permitsOperation = true
    var isWriting = false
    var permissionsGranted = true
    var selectedSourceID: String? = "en"
    var onSourceChange: (() -> Void)?
    var receive: ((AutomaticRepairEvent) -> Void)?
    var focused: EditorFocus?
    var caret = 6
    var listening = false
    var captures = 0
    var applications = 0
    var cancellations = 0
    var requestedSources: [String] = []
    var sourceSwitchSucceeds = true
    init() {
        defaults = UserDefaults(suiteName: suite)!
        preferences = Preferences(defaults: defaults); preferences.automaticLayoutRepair = true
        focused = EditorFocus(element: element, pid: 12345)
    }
    func cleanup() { defaults.removePersistentDomain(forName: suite) }
    func language(for sourceID: String) -> String? { sourceID == "en" ? "en" : "uk" }
    func targets(from sourceID: String) -> [LayoutDetectionTarget] {
        [LayoutDetectionTarget(id: "uk", language: "uk", mapping: Dictionary(uniqueKeysWithValues: zip(Array("ghsdbn"), Array("привіт"))))]
    }
    func selectSource(_ id: String) -> Bool {
        requestedSources.append(id)
        guard sourceSwitchSucceeds else { return false }
        selectedSourceID = id; onSourceChange?(); return true
    }
    func focus() -> EditorFocus? { preferences.excludedApps.contains("test.editor") ? nil : focused }
    func capture() -> EditorSnapshot? {
        captures += 1
        guard let focus = focus() else { return nil }
        return EditorSnapshot(element: focus.element, pid: focus.pid, appID: "test.editor", fullText: "ghsdbn",
            selection: NSRange(location: caret, length: 0), target: NSRange(location: 0, length: 6),
            context: "", canReplace: true, fallbackReason: nil, insertion: .wholeValue)
    }
    func unchanged(_ snapshot: EditorSnapshot) -> Bool { focus() == EditorFocus(element: snapshot.element, pid: snapshot.pid) && caret == snapshot.selection.location }
    func apply(_ snapshot: EditorSnapshot, candidate: LayoutRepairCandidate, sourceID: String) { applications += 1 }
    func cancelOperation() { cancellations += 1 }
    func clearResult() {}
    func requestPermissions() {}
    func startEvents(_ receive: @escaping (AutomaticRepairEvent) -> Void) -> Bool { self.receive = receive; listening = true; return true }
    func observeFocus(_ focus: EditorFocus?) {}
    func stopEvents() { receive = nil; listening = false }
    func type() { receive?(.keyDown(key: 5, flags: [], synthetic: false)) }
    func manualSource(_ id: String) { selectedSourceID = id; onSourceChange?() }
}

@MainActor
private final class RepairFixture {
    let environment = FakeRepairEnvironment()
    let clock = ManualRepairClock()
    let recognizer = SuspendedRepairRecognizer()
    let controller: AutomaticLayoutRepairController
    init() {
        controller = AutomaticLayoutRepairController(environment: environment, recognizer: recognizer, clock: clock.clock)
        controller.start()
    }
    func settle() async { for _ in 0..<30 { await Task.yield() } }
    func begin(suspended: Bool) async {
        recognizer.suspendNext = suspended; environment.type(); await settle()
        XCTAssertEqual(clock.sleepers.count, 1)
        if suspended {
            clock.advanceFirst(); await settle()
            XCTAssertNotNil(recognizer.waiting)
        }
    }
    func finishPending(suspended: Bool) async {
        if suspended { recognizer.resume() } else { clock.advanceFirst() }
        await settle()
        XCTAssertEqual(environment.applications, 0)
        XCTAssertLessThanOrEqual(recognizer.calls, 1)
    }
    func cleanup() async {
        controller.stop(); clock.finish(); recognizer.resume(); await settle(); environment.cleanup()
    }
}

final class AutomaticRepairControllerTests: XCTestCase {
    @MainActor func testValidIdleInputAppliesExactlyOnce() async {
        let fixture = RepairFixture()
        await fixture.begin(suspended: false)
        fixture.clock.advanceFirst(); await fixture.settle()
        XCTAssertEqual(fixture.environment.applications, 1)
        XCTAssertEqual(fixture.environment.captures, 1)
        XCTAssertEqual(fixture.recognizer.calls, 2)
        await fixture.cleanup()
    }
    @MainActor func testResumedTypingInvalidatesDebounceAndSuspendedDetection() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            let cancellations = fixture.environment.cancellations
            fixture.environment.type()
            XCTAssertGreaterThan(fixture.environment.cancellations, cancellations)
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testFocusAwayAndBackCannotRevivePendingRepair() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.environment.focused = EditorFocus(element: fixture.environment.otherElement, pid: 12346)
            fixture.environment.receive?(.focusChanged)
            fixture.environment.focused = EditorFocus(element: fixture.environment.element, pid: 12345)
            fixture.environment.receive?(.focusChanged)
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testCaretAwayAndBackCannotRevivePendingRepair() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.clock.date.addTimeInterval(0.2)
            fixture.environment.caret = 2; fixture.environment.receive?(.selectionChanged)
            fixture.environment.caret = 6; fixture.environment.receive?(.selectionChanged)
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testManualLayoutAwayAndBackInvalidatesPendingRepair() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.environment.manualSource("uk"); fixture.environment.manualSource("en")
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testExclusionNotificationsCancelBeforeAppIsReenabled() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.environment.preferences.exclusions = "test.editor"; await fixture.settle()
            fixture.environment.preferences.exclusions = ""; await fixture.settle()
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testPermissionLossStopsListeningAndPendingRepair() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            let cancellations = fixture.environment.cancellations
            fixture.environment.permissionsGranted = false; fixture.environment.receive?(.permissionsChanged)
            XCTAssertFalse(fixture.environment.listening)
            XCTAssertGreaterThan(fixture.environment.cancellations, cancellations)
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testPermissionIsRecheckedEvenWithoutARevocationEvent() async {
        let fixture = RepairFixture(); await fixture.begin(suspended: true)
        fixture.environment.permissionsGranted = false
        await fixture.finishPending(suspended: true); await fixture.cleanup()
    }
    @MainActor func testDisablingPreferenceStopsPendingRepair() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.environment.preferences.automaticLayoutRepair = false; await fixture.settle()
            XCTAssertFalse(fixture.environment.listening)
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testManualOperationCancelsDebounceAndSuspendedDetection() async {
        for suspended in [false, true] {
            let fixture = RepairFixture(); await fixture.begin(suspended: suspended)
            fixture.environment.permitsOperation = false; fixture.controller.cancelPending()
            fixture.environment.permitsOperation = true
            await fixture.finishPending(suspended: suspended); await fixture.cleanup()
        }
    }
    @MainActor func testFailedSwitchDoesNotOwnSubsequentManualSelection() async {
        let fixture = RepairFixture()
        fixture.environment.sourceSwitchSucceeds = false
        let switched = fixture.controller.selectSource("uk")
        let undo = fixture.controller.undoState(sourceID: "en", targetID: "uk", switched: switched, caret: NSRange(location: 6, length: 0))
        XCTAssertEqual(undo.selectedSourceID, "en")
        fixture.environment.manualSource("uk")
        fixture.controller.restoreSource(for: undo)
        XCTAssertEqual(fixture.environment.requestedSources, ["uk"])
        XCTAssertEqual(fixture.environment.selectedSourceID, "uk")
        await fixture.cleanup()
    }
    @MainActor func testSuccessfulAutomaticSwitchCanBeRestored() async {
        let fixture = RepairFixture()
        let switched = fixture.controller.selectSource("uk")
        let undo = fixture.controller.undoState(sourceID: "en", targetID: "uk", switched: switched, caret: NSRange(location: 6, length: 0))
        fixture.controller.restoreSource(for: undo)
        XCTAssertEqual(fixture.environment.requestedSources, ["uk", "en"])
        await fixture.cleanup()
    }
    @MainActor func testManualLayoutChoiceRevokesUndoOwnershipEvenAfterReturning() async {
        let fixture = RepairFixture()
        let switched = fixture.controller.selectSource("uk")
        let undo = fixture.controller.undoState(sourceID: "en", targetID: "uk", switched: switched, caret: NSRange(location: 6, length: 0))
        fixture.environment.manualSource("en"); fixture.environment.manualSource("uk")
        fixture.controller.restoreSource(for: undo)
        XCTAssertEqual(fixture.environment.requestedSources, ["uk"])
        XCTAssertEqual(fixture.environment.selectedSourceID, "uk")
        await fixture.cleanup()
    }
    @MainActor func testUnconfirmedFieldIsSuspendedUntilFocusChanges() async throws {
        let fixture = RepairFixture()
        let snapshot = try XCTUnwrap(fixture.environment.capture())
        fixture.controller.block(snapshot)
        fixture.environment.type(); await fixture.settle()
        XCTAssertTrue(fixture.clock.sleepers.isEmpty)
        XCTAssertEqual(fixture.environment.applications, 0)
        fixture.environment.focused = EditorFocus(element: fixture.environment.otherElement, pid: 12346)
        fixture.environment.receive?(.focusChanged)
        fixture.environment.focused = EditorFocus(element: fixture.environment.element, pid: 12345)
        fixture.environment.receive?(.focusChanged)
        await fixture.begin(suspended: false)
        fixture.clock.advanceFirst(); await fixture.settle()
        XCTAssertEqual(fixture.environment.applications, 1)
        await fixture.cleanup()
    }
}
