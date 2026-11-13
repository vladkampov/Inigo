import AppKit
import ApplicationServices
import InigoCore
import Carbon

@MainActor
enum InsertionMethod { case accessibility, compatibilityPaste, wholeValue }

@MainActor
struct EditorSnapshot {
    let element: AXUIElement
    let pid: pid_t
    let appID: String
    let fullText: String
    let selection: NSRange
    let target: NSRange
    let context: String
    let canReplace: Bool
    let fallbackReason: String?
    var insertion: InsertionMethod = .accessibility
    var draft: String { (fullText as NSString).substring(with: target) }
}

struct EditorFocus: Equatable {
    let element: AXUIElement
    let pid: pid_t
    static func == (lhs: Self, rhs: Self) -> Bool { lhs.pid == rhs.pid && CFEqual(lhs.element, rhs.element) }
}

@MainActor
struct InvocationSource {
    let appID: String
    let pid: pid_t
    func allowed(exclusions: Set<String>) -> Bool {
        InvocationPolicy.allowsSource(appID, ownAppID: Bundle.main.bundleIdentifier, exclusions: exclusions)
            && NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == appID
    }
}

@MainActor
final class AccessibilityEditor {
    func invocationSource(exclusions: Set<String>) throws -> InvocationSource {
        guard AXIsProcessTrusted() else { throw InigoError.message("Allow Inigo in System Settings → Privacy & Security → Accessibility, then try again.") }
        guard let app = NSWorkspace.shared.frontmostApplication,
              InvocationPolicy.allowsSource(app.bundleIdentifier, ownAppID: Bundle.main.bundleIdentifier, exclusions: []),
              let appID = app.bundleIdentifier else {
            throw InigoError.message("Focus an editable text field in another app.")
        }
        guard !exclusions.contains(appID) else { throw InigoError.message("This app is excluded. Change Apps Inigo should ignore in Privacy settings.") }
        if let element = focused(), attribute(element, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole {
            throw InigoError.message("Focus an ordinary text field. Secure fields are never read.")
        }
        return InvocationSource(appID: appID, pid: app.processIdentifier)
    }
    private func permitsImplicitDraft(_ element: AXUIElement, app: NSRunningApplication) -> Bool {
        var current: AXUIElement? = element
        var seen: [AXUIElement] = []
        var web = false, complete = false
        for _ in 0..<64 {
            guard let node = current, !seen.contains(where: { CFEqual($0, node) }) else { break }
            seen.append(node)
            let role = attribute(node, kAXRoleAttribute) as? String
            if role == "AXWebArea" { web = true }
            if role == kAXApplicationRole { complete = true; break }
            guard let parent = attribute(node, kAXParentAttribute), CFGetTypeID(parent) == AXUIElementGetTypeID() else { break }
            current = (parent as! AXUIElement)
        }
        let info = app.bundleURL.flatMap { Bundle(url: $0) }?.infoDictionary
        let schemes = (info?["CFBundleURLTypes"] as? [[String: Any]] ?? [])
            .flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }.map { $0.lowercased() }
        return InvocationPolicy.permitsImplicitDraft(appID: app.bundleIdentifier ?? "", hasWebAncestor: web,
            handlesWebURLs: schemes.contains("http") || schemes.contains("https"), ancestryComplete: complete)
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    private func range(_ element: AXUIElement, _ name: String) -> NSRange? {
        guard let raw = attribute(element, name), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var value = CFRange(); guard AXValueGetValue(raw as! AXValue, .cfRange, &value), value.location >= 0, value.length >= 0 else { return nil }
        return NSRange(location: value.location, length: value.length)
    }
    private func focused() -> AXUIElement? {
        guard let value = attribute(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    /// AX uses global top-left coordinates; AppKit uses bottom-left coordinates.
    func focusedFrame() -> NSRect? {
        guard AXIsProcessTrusted(), let element = focused(),
              let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero; var extent = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &extent),
              point.x.isFinite, point.y.isFinite, extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0, let primary = NSScreen.screens.first else { return nil }
        return NSRect(x: point.x, y: primary.frame.maxY - point.y - extent.height, width: extent.width, height: extent.height)
    }
    func selectedReference(exclusions: Set<String>) -> String? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              let id = app.bundleIdentifier, id != Bundle.main.bundleIdentifier, !exclusions.contains(id),
              let element = focused(), attribute(element,kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole,
              let text = attribute(element,kAXSelectedTextAttribute) as? String,
              !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty, text.utf16.count <= 20_000 else { return nil }
        return text
    }
    func capture(exclusions: Set<String>, compatibilityPaste: Bool) throws -> EditorSnapshot {
        guard AXIsProcessTrusted() else { throw InigoError.message("Allow Inigo in System Settings → Privacy & Security → Accessibility, then try again.") }
        guard let app = NSWorkspace.shared.frontmostApplication, let appID = app.bundleIdentifier, appID != Bundle.main.bundleIdentifier, let element = focused() else { throw InigoError.message("Focus an editable text field in another app.") }
        guard !exclusions.contains(appID) else { throw InigoError.message("This app is excluded. Change Apps Inigo should ignore in Privacy settings.") }
        let browser = !permitsImplicitDraft(element, app: app)
        let role = attribute(element, kAXRoleAttribute) as? String ?? ""
        let subrole = attribute(element, kAXSubroleAttribute) as? String ?? ""
        guard [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole].contains(role), subrole != kAXSecureTextFieldSubrole else { throw InigoError.message("Focus an ordinary text field. Secure fields are never read.") }
        guard let text = attribute(element, kAXValueAttribute) as? String, text.utf16.count <= 100_000, let selection = range(element, kAXSelectedTextRangeAttribute) else { throw InigoError.message("This editor does not expose a safe text selection.") }
        if browser && selection.length == 0 { throw InigoError.message("Select up to 20,000 characters.") }
        let target = try TextSafety.targetRange(text: text, selection: selection, messageField: appID == "com.tinyspeck.slackmacgap" || role == kAXTextFieldRole)
        guard target.length > 0, target.length <= 20_000 else { throw InigoError.message("Select a draft of up to 20,000 characters to refine.") }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &settable)
        let verifiedPlain = plainText(element, range: target)
        let slackObjects = appID == "com.tinyspeck.slackmacgap" && (text.contains("@") || text.contains("#") || text.contains("http") || text.contains("\u{FFFC}"))
        let usePaste = compatibilityPaste && (browser || ClipboardPolicy.prefersPaste(appID: appID) || !settable.boolValue)
        let safe = (settable.boolValue || usePaste) && verifiedPlain && !slackObjects
        // Context comes ONLY from an explicitly exposed visible range in the active field.
        var context = ""
        if !browser, let visible = range(element, kAXVisibleCharacterRangeAttribute), TextSafety.valid(visible, in: text) {
            context = String((text as NSString).substring(with: visible).prefix(6000))
        }
        return EditorSnapshot(element: element, pid: app.processIdentifier, appID: appID, fullText: text, selection: selection, target: target, context: context, canReplace: safe, fallbackReason: safe ? nil : "This editor's formatting cannot be verified. Your draft is unchanged.", insertion: usePaste ? .compatibilityPaste : .accessibility)
    }
    /// Metadata only: no field value is read until the opt-in idle capture.
    func automaticFocus(exclusions: Set<String>) -> EditorFocus? {
        guard AXIsProcessTrusted(), !IsSecureEventInputEnabled(),
              let app = NSWorkspace.shared.frontmostApplication,
              InvocationPolicy.allowsSource(app.bundleIdentifier, ownAppID: Bundle.main.bundleIdentifier, exclusions: exclusions),
              let element = focused(),
              attribute(element, kAXSubroleAttribute) as? String != kAXSecureTextFieldSubrole,
              let role = attribute(element, kAXRoleAttribute) as? String,
              [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole].contains(role) else { return nil }
        return EditorFocus(element: element, pid: app.processIdentifier)
    }
    /// Separate consent boundary; never relax the manual browser-selection policy.
    func captureForLayoutRepair(exclusions: Set<String>) -> EditorSnapshot? {
        guard let focus = automaticFocus(exclusions: exclusions),
              let app = NSRunningApplication(processIdentifier: focus.pid), let appID = app.bundleIdentifier,
              let selection = range(focus.element, kAXSelectedTextRangeAttribute), selection.length == 0,
              let text = attribute(focus.element, kAXValueAttribute) as? String,
              !text.isEmpty, text.utf16.count <= LayoutRepairPolicy.maximumLength,
              TextSafety.valid(selection, in: text) else { return nil }
        let target = NSRange(location: 0, length: text.utf16.count)
        guard plainText(focus.element, range: target) else { return nil }
        var settable: DarwinBoolean = false
        AXUIElementIsAttributeSettable(focus.element, kAXValueAttribute as CFString, &settable)
        // Automatic whole-draft repair must not select the entire draft while a user resumes typing.
        // Editors requiring a clipboard/selection transaction remain manual-only.
        guard settable.boolValue else { return nil }
        let slackObjects = appID == "com.tinyspeck.slackmacgap" && (text.contains("@") || text.contains("#") || text.contains("http") || text.contains("\u{FFFC}"))
        guard !slackObjects else { return nil }
        return EditorSnapshot(element: focus.element, pid: focus.pid, appID: appID, fullText: text, selection: selection, target: target, context: "", canReplace: true, fallbackReason: nil, insertion: .wholeValue)
    }
    private func plainText(_ element: AXUIElement, range: NSRange) -> Bool {
        var cfRange = CFRange(location: range.location, length: range.length)
        guard let parameter = AXValueCreate(.cfRange, &cfRange) else { return false }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, kAXAttributedStringForRangeParameterizedAttribute as CFString, parameter, &result) == .success,
              let attributed = result as? NSAttributedString, attributed.length == range.length else { return false }
        var safe = true
        var baseline: NSDictionary?
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, _, _ in
            let dictionary = attrs as NSDictionary
            if let baseline, !baseline.isEqual(dictionary) { safe = false }
            baseline = baseline ?? dictionary
            for key in attrs.keys {
                let name = key.rawValue.lowercased()
                if name.contains("link") || name.contains("attachment") || name.contains("heading") || name.contains("list") { safe = false }
            }
        }
        if attributed.string.contains("\u{FFFC}") { safe = false }
        return safe
    }
    func unchanged(_ snapshot: EditorSnapshot, selection: Bool = true) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid, let current = focused(), CFEqual(current, snapshot.element), let text = attribute(current, kAXValueAttribute) as? String, text == snapshot.fullText else { return false }
        return !selection || range(current, kAXSelectedTextRangeAttribute) == snapshot.selection
    }
    enum ReplacementError: LocalizedError {
        case notWritten(String)
        case unconfirmed
        var errorDescription: String? {
            switch self {
            case .notWritten(let message): return message
            case .unconfirmed: return "The editor has not confirmed the replacement. Check the original field before pasting."
            }
        }
        var mayHaveChanged: Bool { if case .unconfirmed = self { return true }; return false }
    }
    private func sameFocusedTarget(_ snapshot: EditorSnapshot) -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == snapshot.pid, let current = focused() else { return false }
        return CFEqual(current, snapshot.element)
    }
    func replace(_ snapshot: EditorSnapshot, with text: String, restoringSelection: NSRange? = nil, allowed: () -> Bool = { true }) async throws -> EditorSnapshot {
        guard allowed() else { throw CancellationError() }
        if let restoringSelection, !TextSafety.valid(restoringSelection, in: try TextSafety.replacing(snapshot.fullText, range: snapshot.target, with: text)) { throw ReplacementError.notWritten("The editor's selection could not be read safely.") }
        guard snapshot.canReplace, unchanged(snapshot), plainText(snapshot.element, range: snapshot.target) else {
            throw ReplacementError.notWritten("The draft or formatting changed. Nothing was replaced.")
        }
        if snapshot.insertion != .wholeValue {
            var selected = CFRange(location: snapshot.target.location, length: snapshot.target.length)
            guard let value = AXValueCreate(.cfRange, &selected), AXUIElementSetAttributeValue(snapshot.element, kAXSelectedTextRangeAttribute as CFString, value) == .success else {
                throw ReplacementError.notWritten("The editor did not accept the selection. Your draft is unchanged.")
            }
            // Electron/WebKit may acknowledge the request before exposing the updated selection.
            // Do not insert until the exact intended range has been read back.
            var selectionConfirmed = false
            for _ in 0..<10 {
                try Task.checkCancellation()
                guard allowed() else { throw CancellationError() }
                guard sameFocusedTarget(snapshot), attribute(snapshot.element, kAXValueAttribute) as? String == snapshot.fullText else {
                    throw ReplacementError.notWritten("The target changed before insertion. Nothing was replaced.")
                }
                let observed = range(snapshot.element, kAXSelectedTextRangeAttribute)
                if observed == snapshot.target { selectionConfirmed = true; break }
                guard observed == snapshot.selection else {
                    throw ReplacementError.notWritten("The selection changed before insertion. Nothing was replaced.")
                }
                try await Task.sleep(for: .milliseconds(30))
            }
            guard selectionConfirmed else { throw ReplacementError.notWritten("This editor cannot select the replacement range reliably. Use the copyable rewrite.") }
            try Task.checkCancellation()
            guard allowed() else { throw CancellationError() }
            guard sameFocusedTarget(snapshot), attribute(snapshot.element, kAXValueAttribute) as? String == snapshot.fullText,
                  range(snapshot.element, kAXSelectedTextRangeAttribute) == snapshot.target else {
                throw ReplacementError.notWritten("The draft changed before insertion. Nothing was replaced.")
            }
        }
        let expected = try TextSafety.replacing(snapshot.fullText, range: snapshot.target, with: text)
        // After this point, every failure is potentially mutating. Never claim the original is intact.
        // Never issue a second write or blindly restore the old draft after an ambiguous result.
        let clipboard: CompatibilityPaste?
        if snapshot.insertion == .compatibilityPaste {
            do {
                clipboard = try CompatibilityPaste()
                guard allowed() else { throw CancellationError() }
                // Capturing promised clipboard representations may have taken time.
                guard sameFocusedTarget(snapshot), attribute(snapshot.element, kAXValueAttribute) as? String == snapshot.fullText,
                      range(snapshot.element, kAXSelectedTextRangeAttribute) == snapshot.target else {
                    throw ReplacementError.notWritten("The target changed before pasting. Nothing was replaced.")
                }
                try clipboard?.insert(text, into: snapshot.pid)
            } catch { throw ReplacementError.notWritten(error.localizedDescription) }
        } else if snapshot.insertion == .wholeValue {
            guard allowed(), !Task.isCancelled, unchanged(snapshot), snapshot.target == NSRange(location: 0, length: snapshot.fullText.utf16.count) else { throw CancellationError() }
            clipboard = nil
            _ = AXUIElementSetAttributeValue(snapshot.element, kAXValueAttribute as CFString, text as CFString)
        } else {
            clipboard = nil
            _ = AXUIElementSetAttributeValue(snapshot.element, kAXSelectedTextAttribute as CFString, text as CFString)
        }
        defer { clipboard?.restore() }
        let intermediate = try TextSafety.replacing(snapshot.fullText, range:snapshot.target, with:"")
        var observedText = expected
        let result = await WriteVerification.verify(attempts: clipboard == nil ? 12 : 40, read: {
            guard self.sameFocusedTarget(snapshot) else { return .different }
            guard let current = self.attribute(snapshot.element, kAXValueAttribute) as? String else { return .unavailable }
            let observation = EditorTextEquivalence.observation(current:current,original:snapshot.fullText,expected:expected,deletionIntermediate:intermediate)
            if observation == .expected { observedText = current }
            return observation
        })
        guard result == .confirmed else { throw ReplacementError.unconfirmed }
        if let restoringSelection {
            // Restoring a caret is a write too. Do not move it after new typing/focus changes.
            guard allowed(), !Task.isCancelled, sameFocusedTarget(snapshot),
                  attribute(snapshot.element, kAXValueAttribute) as? String == expected,
                  let currentSelection = range(snapshot.element, kAXSelectedTextRangeAttribute),
                  currentSelection == snapshot.selection || currentSelection == NSRange(location: snapshot.target.location, length: text.utf16.count) || currentSelection == NSRange(location: snapshot.target.location + text.utf16.count, length: 0) else { throw ReplacementError.unconfirmed }
            var desired = CFRange(location: restoringSelection.location, length: restoringSelection.length)
            guard let value = AXValueCreate(.cfRange, &desired), AXUIElementSetAttributeValue(snapshot.element, kAXSelectedTextRangeAttribute as CFString, value) == .success,
                  range(snapshot.element, kAXSelectedTextRangeAttribute) == restoringSelection else { throw ReplacementError.unconfirmed }
        }
        let newSelection = range(snapshot.element, kAXSelectedTextRangeAttribute) ?? NSRange(location: snapshot.target.location + text.utf16.count, length: 0)
        return EditorSnapshot(element: snapshot.element, pid: snapshot.pid, appID: snapshot.appID, fullText: observedText, selection: newSelection, target: NSRange(location: snapshot.target.location, length: text.utf16.count), context: "", canReplace: observedText == expected, fallbackReason: nil, insertion: snapshot.insertion)
    }
    static func requestPermission() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary) }
}
