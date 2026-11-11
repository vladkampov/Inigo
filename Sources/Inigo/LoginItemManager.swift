import Combine
import Foundation
import ServiceManagement

@MainActor
protocol LoginItemService {
    var status: SMAppService.Status { get }
    var isAvailable: Bool { get }
    func register() throws
    func unregister() async throws
    func openSystemSettings()
}

@MainActor
struct SystemLoginItemService: LoginItemService {
    private let service = SMAppService.mainApp
    var status: SMAppService.Status { service.status }
    var isAvailable: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }
    func register() throws { try service.register() }
    func unregister() async throws { try await service.unregister() }
    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var isUpdating = false
    @Published private(set) var errorMessage: String?
    private let service: any LoginItemService

    init(service: any LoginItemService) {
        self.service = service
        status = service.status
    }
    convenience init() { self.init(service: SystemLoginItemService()) }

    var isOn: Bool { status == .enabled || status == .requiresApproval }
    var isAvailable: Bool {
        guard service.isAvailable else { return false }
        switch status {
        // A missing service record must not prevent an explicit registration attempt.
        case .notRegistered, .enabled, .requiresApproval, .notFound: return true
        @unknown default: return false
        }
    }

    func refresh() {
        let current = service.status
        if current != status { errorMessage = nil }
        status = current
    }

    func setEnabled(_ enabled: Bool) async {
        guard !isUpdating else { return }
        refresh()
        guard isAvailable, enabled != isOn else { return }
        isUpdating = true
        errorMessage = nil
        do {
            if enabled { try service.register() }
            else { try await service.unregister() }
        } catch {
            errorMessage = "Couldn’t change launch at login. Try again."
        }
        // Even a failed request can change registration or approval status.
        status = service.status
        isUpdating = false
    }

    func openSystemSettings() { service.openSystemSettings() }
}
