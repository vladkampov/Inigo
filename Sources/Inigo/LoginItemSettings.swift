import SwiftUI

struct LoginItemSettings: View {
    @ObservedObject var loginItem: LoginItemManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(L("Launch at login"), isOn: Binding(
                get: { loginItem.isOn },
                set: { enabled in Task { await loginItem.setEnabled(enabled) } }
            ))
            .disabled(!loginItem.isAvailable || loginItem.isUpdating)
            Text(L("Start Inigo in the menu bar when you log in to your Mac."))
                .font(.caption).foregroundStyle(.secondary)
            if !loginItem.isAvailable {
                Text(L("Launch at login is unavailable for this copy of Inigo."))
                    .font(.caption).foregroundStyle(.secondary)
            } else if loginItem.status == .requiresApproval {
                Text(L("Approval is needed in System Settings before Inigo can launch at login."))
                    .font(.caption).foregroundStyle(.secondary)
                Button(L("Open Login Items settings")) { loginItem.openSystemSettings() }
                    .disabled(loginItem.isUpdating)
            }
            if let error = loginItem.errorMessage {
                Text(L(error)).font(.callout).foregroundStyle(.red)
            }
        }
        .onAppear { loginItem.refresh() }
    }
}
