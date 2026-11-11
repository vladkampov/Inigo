import XCTest
import ServiceManagement
@testable import Inigo

@MainActor
final class LoginItemManagerTests: XCTestCase {
    func testInitialStatusDoesNotRegisterOrUnregister() {
        for status in [SMAppService.Status.notRegistered, .enabled, .requiresApproval, .notFound] {
            let service = FakeLoginItemService(status: status)
            let manager = LoginItemManager(service: service)
            XCTAssertEqual(manager.status, status)
            XCTAssertEqual(manager.isOn, status == .enabled || status == .requiresApproval)
            XCTAssertTrue(manager.isAvailable)
            XCTAssertEqual(service.registrations, 0)
            XCTAssertEqual(service.unregistrations, 0)
        }
    }

    func testEnablingAndDisablingReadBackSystemStatus() async {
        let service = FakeLoginItemService()
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(true)
        XCTAssertTrue(manager.isOn)
        XCTAssertEqual(service.registrations, 1)
        await manager.setEnabled(false)
        XCTAssertFalse(manager.isOn)
        XCTAssertEqual(service.unregistrations, 1)
        XCTAssertNil(manager.errorMessage)
    }

    func testPendingApprovalIsOnAndCanBeCancelled() async {
        let service = FakeLoginItemService()
        service.registrationStatus = .requiresApproval
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(true)
        XCTAssertEqual(manager.status, .requiresApproval)
        XCTAssertTrue(manager.isOn)
        manager.openSystemSettings()
        XCTAssertEqual(service.settingsOpens, 1)
        await manager.setEnabled(false)
        XCTAssertEqual(manager.status, .notRegistered)
        XCTAssertEqual(service.unregistrations, 1)
    }

    func testRegistrationFailureShowsErrorAndAllowsRetry() async {
        let service = FakeLoginItemService()
        service.registrationError = TestError.failed
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(true)
        XCTAssertFalse(manager.isOn)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isUpdating)
        service.registrationError = nil
        await manager.setEnabled(true)
        XCTAssertTrue(manager.isOn)
        XCTAssertNil(manager.errorMessage)
    }

    func testRegistrationFailureStillReadsChangedApprovalStatus() async {
        let service = FakeLoginItemService()
        service.registrationError = TestError.failed
        service.statusOnRegistrationError = .requiresApproval
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(true)
        XCTAssertEqual(manager.status, .requiresApproval)
        XCTAssertTrue(manager.isOn)
        XCTAssertNotNil(manager.errorMessage)
        await manager.setEnabled(false)
        XCTAssertFalse(manager.isOn)
        XCTAssertNil(manager.errorMessage)
    }

    func testUnregistrationFailurePreservesActualStatus() async {
        let service = FakeLoginItemService(status: .enabled)
        service.unregistrationError = TestError.failed
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(false)
        XCTAssertTrue(manager.isOn)
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isUpdating)
    }

    func testRefreshReflectsExternalChangesWithoutRegistering() async {
        let service = FakeLoginItemService(status: .enabled)
        let manager = LoginItemManager(service: service)
        service.status = .requiresApproval
        manager.refresh()
        XCTAssertEqual(manager.status, .requiresApproval)
        service.status = .notRegistered
        manager.refresh()
        XCTAssertFalse(manager.isOn)
        // The state can also change after the last refresh, before the user clicks.
        service.status = .enabled
        await manager.setEnabled(false)
        XCTAssertFalse(manager.isOn)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.unregistrations, 1)
    }

    func testUnavailableCopiesAndUnchangedRequestsDoNotMutateService() async {
        let service = FakeLoginItemService()
        let manager = LoginItemManager(service: service)
        await manager.setEnabled(false)
        service.isAvailable = false
        XCTAssertFalse(manager.isAvailable)
        await manager.setEnabled(true)
        XCTAssertEqual(service.registrations, 0)
        XCTAssertEqual(service.unregistrations, 0)
    }

    func testMissingServiceRecordCanBeRegisteredFromSupportedBundle() async {
        let service = FakeLoginItemService(status: .notFound)
        let manager = LoginItemManager(service: service)
        XCTAssertTrue(manager.isAvailable)
        await manager.setEnabled(true)
        XCTAssertTrue(manager.isOn)
        XCTAssertEqual(service.registrations, 1)
    }

    func testConcurrentRequestsAreIgnoredUntilUnregistrationFinishes() async {
        let service = FakeLoginItemService(status: .enabled)
        service.suspendUnregistration = true
        let manager = LoginItemManager(service: service)
        let operation = Task { await manager.setEnabled(false) }
        // Wait for the fake service to reach its suspension point.
        while service.unregistrationContinuation == nil { await Task.yield() }
        XCTAssertTrue(manager.isUpdating)
        await manager.setEnabled(false)
        await manager.setEnabled(true)
        XCTAssertEqual(service.unregistrations, 1)
        XCTAssertEqual(service.registrations, 0)
        service.unregistrationContinuation?.resume()
        await operation.value
        XCTAssertFalse(manager.isUpdating)
        XCTAssertFalse(manager.isOn)
    }
}

private enum TestError: Error { case failed }

@MainActor
private final class FakeLoginItemService: LoginItemService {
    var status: SMAppService.Status
    var isAvailable = true
    var registrations = 0
    var unregistrations = 0
    var settingsOpens = 0
    var registrationStatus: SMAppService.Status = .enabled
    var statusOnRegistrationError: SMAppService.Status?
    var registrationError: Error?
    var unregistrationError: Error?
    var suspendUnregistration = false
    var unregistrationContinuation: CheckedContinuation<Void, Never>?

    init(status: SMAppService.Status = .notRegistered) { self.status = status }
    func register() throws {
        registrations += 1
        if let error = registrationError {
            if let newStatus = statusOnRegistrationError { status = newStatus }
            throw error
        }
        status = registrationStatus
    }
    func unregister() async throws {
        unregistrations += 1
        if suspendUnregistration {
            await withCheckedContinuation { unregistrationContinuation = $0 }
        }
        if let error = unregistrationError { throw error }
        status = .notRegistered
    }
    func openSystemSettings() { settingsOpens += 1 }
}
