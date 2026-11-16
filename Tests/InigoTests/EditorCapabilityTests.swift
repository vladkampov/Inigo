import XCTest
import AppKit
import ApplicationServices
@testable import Inigo

@MainActor
private final class FakeEditorAccessibility: EditorAccessibility {
    let element = AXUIElementCreateApplication(12345)
    var isTrusted = true
    var secureInputEnabled = false
    var frontmostApplication: (pid: pid_t, id: String?)? = (12345, "test.editor")
    var text = "ghsdbn"
    var selection = NSRange(location: 2, length: 0)
    var writable = Set([kAXValueAttribute, kAXSelectedTextRangeAttribute])
    var failedQueries: Set<String> = []
    var valueWrites = 0
    var selectionWrites = 0
    var valueReads = 0
    var afterValueWrite: (() -> Void)?
    func focusedElement() -> AXUIElement? { element }
    func read(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        switch name {
        case kAXRoleAttribute: return kAXTextAreaRole as CFString
        case kAXSubroleAttribute: return "" as CFString
        case kAXValueAttribute: valueReads += 1; return text as CFString
        case kAXSelectedTextRangeAttribute:
            var range = CFRange(location: selection.location, length: selection.length)
            return AXValueCreate(.cfRange, &range)
        default: return nil
        }
    }
    func attributedText(_ element: AXUIElement, range: NSRange) -> NSAttributedString? {
        NSAttributedString(string: (text as NSString).substring(with: range))
    }
    func isSettable(_ element: AXUIElement, _ name: String) -> Bool {
        !failedQueries.contains(name) && writable.contains(name)
    }
    func write(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> AXError {
        guard isSettable(element, name) else { return .attributeUnsupported }
        if name == kAXValueAttribute {
            valueWrites += 1; text = value as! String; selection = NSRange(location: text.utf16.count, length: 0)
            afterValueWrite?(); return .success
        }
        if name == kAXSelectedTextRangeAttribute {
            var range = CFRange()
            guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return .illegalArgument }
            selectionWrites += 1; selection = NSRange(location: range.location, length: range.length)
            return .success
        }
        return .attributeUnsupported
    }
}

final class EditorCapabilityTests: XCTestCase {
    @MainActor func testReadOnlySelectionRejectsCaptureBeforeReadingWriting() {
        let access = FakeEditorAccessibility(); access.writable.remove(kAXSelectedTextRangeAttribute)
        XCTAssertNil(AccessibilityEditor(accessibility: access).captureForLayoutRepair(exclusions: []))
        XCTAssertEqual(access.valueReads, 0)
        XCTAssertEqual(access.valueWrites, 0)
    }
    @MainActor func testFailedCapabilityQueriesRejectCapture() {
        for attribute in [kAXValueAttribute, kAXSelectedTextRangeAttribute] {
            let access = FakeEditorAccessibility(); access.failedQueries.insert(attribute)
            XCTAssertNil(AccessibilityEditor(accessibility: access).captureForLayoutRepair(exclusions: []))
            XCTAssertEqual(access.valueWrites, 0)
        }
    }
    @MainActor func testCapabilitiesRevokedAfterCaptureNeverWrite() async throws {
        for attribute in [kAXValueAttribute, kAXSelectedTextRangeAttribute] {
            let access = FakeEditorAccessibility()
            let actualEditor = AccessibilityEditor(accessibility: access)
            let snapshot = try XCTUnwrap(actualEditor.captureForLayoutRepair(exclusions: []))
            access.writable.remove(attribute)
            do { _ = try await actualEditor.replace(snapshot, with: "привіт", restoringSelection: snapshot.selection); XCTFail("Expected pre-write rejection") }
            catch { XCTAssertFalse((error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged ?? true) }
            XCTAssertEqual(access.valueWrites, 0)
            XCTAssertEqual(access.text, "ghsdbn")
        }
    }
    @MainActor func testWritableFieldRestoresCaretAndExactUndo() async throws {
        let access = FakeEditorAccessibility()
        let editor = AccessibilityEditor(accessibility: access)
        let snapshot = try XCTUnwrap(editor.captureForLayoutRepair(exclusions: []))
        let applied = try await editor.replace(snapshot, with: "привіт", restoringSelection: snapshot.selection)
        XCTAssertTrue(applied.canReplace)
        XCTAssertEqual(access.text, "привіт")
        XCTAssertEqual(access.selection, snapshot.selection)
        _ = try await editor.replace(applied, with: snapshot.draft, restoringSelection: snapshot.selection)
        XCTAssertEqual(access.text, "ghsdbn")
        XCTAssertEqual(access.selection, snapshot.selection)
        XCTAssertEqual(access.valueWrites, 2)
    }
    @MainActor func testCapabilityQueryFailureAfterCaptureNeverWrites() async throws {
        for attribute in [kAXValueAttribute, kAXSelectedTextRangeAttribute] {
            let access = FakeEditorAccessibility()
            let editor = AccessibilityEditor(accessibility: access)
            let snapshot = try XCTUnwrap(editor.captureForLayoutRepair(exclusions: []))
            access.failedQueries.insert(attribute)
            do { _ = try await editor.replace(snapshot, with: "привіт", restoringSelection: snapshot.selection); XCTFail("Expected capability-query rejection") }
            catch { XCTAssertFalse((error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged ?? true) }
            XCTAssertEqual(access.valueWrites, 0)
        }
    }
    @MainActor func testLaterTypingPreventsUndo() async throws {
        let access = FakeEditorAccessibility()
        let actualEditor = AccessibilityEditor(accessibility: access)
        let snapshot = try XCTUnwrap(actualEditor.captureForLayoutRepair(exclusions: []))
        let applied = try await actualEditor.replace(snapshot, with: "привіт", restoringSelection: snapshot.selection)
        access.text += " EXTRA"
        do { _ = try await actualEditor.replace(applied, with: snapshot.draft, restoringSelection: snapshot.selection); XCTFail("Expected changed-draft rejection") }
        catch {}
        XCTAssertEqual(access.text, "привіт EXTRA")
        XCTAssertEqual(access.valueWrites, 1)
    }
    @MainActor func testCaretCapabilityLostAfterWriteRemainsUnconfirmedWithoutRollback() async throws {
        let access = FakeEditorAccessibility()
        let editor = AccessibilityEditor(accessibility: access)
        let snapshot = try XCTUnwrap(editor.captureForLayoutRepair(exclusions: []))
        access.afterValueWrite = { access.writable.remove(kAXSelectedTextRangeAttribute) }
        do { _ = try await editor.replace(snapshot, with: "привіт", restoringSelection: snapshot.selection); XCTFail("Expected unconfirmed result") }
        catch { XCTAssertTrue((error as? AccessibilityEditor.ReplacementError)?.mayHaveChanged ?? false) }
        XCTAssertEqual(access.valueWrites, 1)
        XCTAssertEqual(access.selectionWrites, 0)
        XCTAssertEqual(access.text, "привіт")
    }
}
