import SwiftUI

struct CompatibilityGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Where it works")).font(.headline)
            Text(L("Supported text fields allow replacement and guarded Undo. Some rich editors offer a copyable result instead."))
            Text(L("For manual rewriting in browsers, select text first. Password fields and excluded apps are always skipped."))
        }.font(.callout).foregroundStyle(.secondary)
    }
}

struct LayoutRepairSettings: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var controller: AutomaticLayoutRepairController
    @ObservedObject var catalog: InputSourceCatalog
    @State private var confirming = false
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("Recover writing typed with the wrong keyboard layout.")).font(.title3)
            Text(L("After a short typing pause, Inigo checks the whole focused draft, repairs a clear layout mismatch, and switches your keyboard layout. It does not rewrite your wording."))
            Toggle(L("Automatic keyboard-layout repair"), isOn: Binding(get: { preferences.automaticLayoutRepair }, set: { enabled in
                if enabled { confirming = true } else { preferences.automaticLayoutRepair = false }
            }))
            Text(L(controller.status)).font(.callout).foregroundStyle(.secondary)
            if preferences.automaticLayoutRepair {
                Button(L(controller.paused ? "Resume automatic repair" : "Pause automatic repair")) { controller.togglePaused() }
                Button(L("Check keyboard access")) { controller.requestEnable() }
            }
            Text(L("Automatic mode reads focused native and browser inputs, including private windows. Secure fields, excluded apps, and unverifiable editors are skipped. No writing or keystrokes are saved or uploaded."))
                .font(.callout).foregroundStyle(.secondary)
            Divider()
            Text(L("Your enabled macOS layouts")).font(.headline)
            ForEach(catalog.sources) { source in
                HStack {
                    Text(source.name)
                    Spacer()
                    Text(L(source.supported ? "Available" : "Unavailable for automatic repair")).foregroundStyle(.secondary)
                }
            }
            Text(L("Layouts need a reversible key map and a matching macOS spelling language. Short, ambiguous, or mixed-language drafts are left unchanged. Editors requiring Paste support manual rewriting only."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .alert(L("Enable background layout repair?"), isPresented: $confirming) {
            Button(L("Enable automatic repair")) { controller.requestEnable() }
            Button(L("Cancel"), role: .cancel) {}
        } message: {
            Text(L("Inigo will read the whole focused draft after typing pauses, including in private browser windows, and may replace it and switch the keyboard layout. Processing stays on this Mac. You can pause it or exclude apps anytime."))
        }
    }
}
