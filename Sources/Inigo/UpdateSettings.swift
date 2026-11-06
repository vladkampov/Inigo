import SwiftUI

struct UpdateSettings: View {
    @ObservedObject var updates: UpdateManager
    var body: some View {
        VStack(alignment:.leading,spacing:12) {
            Text("Inigo " + updates.version).font(.headline)
            Toggle(L("Check for updates every hour"),isOn:$updates.automaticChecks).disabled(!updates.configured)
            Text(L("Checks while Inigo is running. You choose when to install. No writing is included in update checks.")).font(.caption).foregroundStyle(.secondary)
            Button(L("Check for Updates…")) { updates.check() }.disabled(!updates.canCheck)
            if !updates.configured {
                Text(L("Updates will be available after the first signed release.")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ErrorReportSettings: View {
    @ObservedObject var reports: ErrorReports
    var body: some View {
        VStack(alignment:.leading,spacing:10) {
            Toggle(L("Send optional error reports"),isOn:$reports.enabled).disabled(!reports.configured)
            Text(L("Off by default. Reports include only an error category, app version and macOS major version. No writing, clipboard content, file paths or usage analytics. The provider still receives connection metadata.")).font(.caption).foregroundStyle(.secondary)
            if !reports.configured { Text(L("Error reporting is not configured for this build.")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
