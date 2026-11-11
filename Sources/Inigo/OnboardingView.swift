import SwiftUI
import AppKit
import ApplicationServices
import InigoCore

/// A real local rewrite of an editable sample. External-editor access is verified separately.
struct OnboardingView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var preferences: Preferences
    @ObservedObject var local: LocalEngine
    @State private var step = 0
    @State private var allowed = AXIsProcessTrusted()
    @State private var draft = L("Hi team, can you please share a update when you have time? I think we could finish this by Friday but we still need to confirm.")
    @State private var previous = ""
    @State private var busy = false
    @State private var completed = false
    @State private var celebrating = false
    @State private var celebrationStart = Date()
    @State private var feedback = ""
    @State private var practiceTask: Task<Void, Never>?
    private let titles = ["Make yourself clear.", "Use Inigo where you write.", "Your writing stays on your Mac.", "Try it for yourself."]
    var body: some View {
        ScrollView {
        VStack(alignment:.leading,spacing:16) {
            HStack { BrandMark(size:44); Spacer(); Text(L("%d of 4").replacingOccurrences(of:"%d",with:String(step + 1))).font(.callout).foregroundStyle(.secondary) }
            Text(L(step == 3 && completed ? "You’re ready. Make it your own." : (step == 2 && local.isExternal ? "Managed by your local server" : titles[step]))).font(.system(size:28,weight:.bold))
            switch step {
            case 0:
                Text(L("Clearer messages, with your meaning and voice intact.")).font(.title3).foregroundStyle(.secondary)
                Label(L("Write in your language"),systemImage:"text.bubble")
                Label(L("Refine a draft with one shortcut"),systemImage:"keyboard")
                Label(L("Review and undo. Inigo never sends it."),systemImage:"arrow.uturn.backward")
                Text(L("We'll check text access, prepare offline writing, then try a real rewrite together.")).foregroundStyle(.secondary)
            case 1:
                Text(L("Allow Accessibility access so Inigo can read and update the text field you invoke it in. It does not record your screen.")).foregroundStyle(.secondary)
                Label(L(allowed ? "Text access is enabled" : "Text access needs your permission"),systemImage:allowed ? "checkmark.circle.fill" : "hand.raised").foregroundStyle(allowed ? .green : .primary)
                if !allowed {
                    Button(L("Open Accessibility settings")) {
                        AccessibilityEditor.requestPermission()
                        NSWorkspace.shared.open(URL(string:"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }.buttonStyle(.borderedProminent)
                    Text(L("Turn on Inigo in Accessibility, then return here. This step updates automatically.")).font(.callout).foregroundStyle(.secondary)
                }
                Text(L("You'll still review the result before sending. Password fields are excluded.")).font(.callout).foregroundStyle(.secondary)
            case 2:
                Text(L(local.isExternal ? "Managed by your local server" : "Download once. Refine privately, even without internet. Inigo starts the writing assistant for you.")).foregroundStyle(.secondary)
                HStack {
                    if local.preparing || local.progress != nil { ProgressView().controlSize(.small) }
                    else { Image(systemName:local.ready ? "checkmark.circle.fill" : "arrow.down.circle").foregroundStyle(.blue) }
                    Text(L(local.status))
                }.padding(18).frame(maxWidth:.infinity,alignment:.leading).background(.quaternary.opacity(0.5),in:RoundedRectangle(cornerRadius:12))
                if let progress = local.progress { ProgressView(value:progress); Button(L("Cancel download")) { local.cancelDownload() } }
                else if !local.ready { Button(L("Download model")) { local.downloadModel() }.buttonStyle(.borderedProminent) }
                Text(local.isExternal ? local.displayName : L("No account, subscription or cloud connection needed. Your writing stays on this Mac.")).font(.callout).foregroundStyle(.secondary)
            default:
                ShortcutControl(model:model, preferences:preferences)
                Text(L("Click the sample, then press your shortcut to try a real rewrite.")).foregroundStyle(.secondary)
                TextEditor(text:$draft).font(.body).frame(height:90).padding(10).background(.quaternary.opacity(0.4),in:RoundedRectangle(cornerRadius:12)).disabled(busy)
                HStack {
                    Button(L(busy ? "Refining…" : "Or click to refine")) { practice() }.buttonStyle(.borderedProminent).disabled(busy || draft.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    if busy { ProgressView().controlSize(.small) }
                    if !previous.isEmpty { Button(L("Undo")) { draft = previous; previous = ""; feedback = "Original restored. Try another rewrite whenever you like." } }
                }
                Text(L(feedback.isEmpty ? "You can also use your configured shortcut while this window is active." : feedback)).font(.callout).foregroundStyle(.secondary)
                Text(L("In other apps, select text and press your shortcut. A brief notification confirms the change. Unsupported editors offer a copyable rewrite.")).font(.caption).foregroundStyle(.secondary)
                Divider()
                LoginItemSettings(loginItem: model.loginItem)
            }
            Spacer(minLength:0)
            HStack {
                if step > 0 { Button(L("Back")) { step -= 1 }.disabled(busy) }
                Spacer()
                if step == 3 {
                    Button(L("Finish setup")) { preferences.onboarding = true }.buttonStyle(.borderedProminent).disabled(!completed || busy)
                } else {
                    Button(L(step == 0 ? "Get started" : "Continue")) { step += 1 }.buttonStyle(.borderedProminent).disabled((step == 1 && !allowed) || (step == 2 && !local.ready))
                }
            }
        }.padding(36).frame(maxWidth:.infinity,minHeight:570,alignment:.topLeading)
        }.frame(width:790,height:570)
        .overlay {
            if celebrating {
                OnboardingCelebration(start:celebrationStart)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
        }
        .task(id:celebrating) {
            guard celebrating else { return }
            try? await Task.sleep(for:.seconds(3))
            guard !Task.isCancelled else { return }; celebrating = false
        }
        .task {
            while !Task.isCancelled {
                allowed = AXIsProcessTrusted()
                try? await Task.sleep(for:.seconds(1))
            }
        }
        .onChange(of:step) { _, value in
            model.onboardingRefine = value == 3 ? { practice() } : nil
            if value == 2 && local.ready { Task { await local.prepareIfNeeded() } }
        }
        .onDisappear { practiceTask?.cancel(); model.onboardingRefine = nil; if preferences.mode != "Local" { local.stop() } }
    }
    private func practice() {
        guard step == 3, !busy, NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier else { return }
        let input = draft
        guard !input.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        busy = true; feedback = "Refining privately on your Mac…"
        practiceTask = Task { @MainActor in
            defer { busy = false }
            do {
                let protected = try ProtectedDraft(input)
                let request = RewriteRequest(draft:protected.masked,context:"",style:[],action:.refine)
                let result = try protected.restore(try await local.rewrite(request))
                try Task.checkCancellation()
                guard draft == input else { feedback = "The sample changed. Try again."; return }
                previous = input; draft = result
                if !completed { celebrationStart = Date(); celebrating = true }
                completed = true
                feedback = result == input ? "Already clear—no changes needed. You're ready to use Inigo." : "Refined. Compare the wording, or Undo to restore your original."
            } catch { if !Task.isCancelled { feedback = error.localizedDescription } }
        }
    }
}
