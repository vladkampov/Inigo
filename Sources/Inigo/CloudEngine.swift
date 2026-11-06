import Foundation
import AppKit
import Security
import InigoCore

@MainActor
final class CloudEngine: ObservableObject {
    @Published var connected = false
    @Published var status = "Not connected"
    @Published var busy = false
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private var pending: [String: CheckedContinuation<[String:Any], Error>] = [:]
    private let service = "app.inigo.chatgpt.credentials"
    private func launch() throws {
        if process?.isRunning == true { return }
        let resources = Bundle.main.resourceURL!
        let p = Process(); p.executableURL = resources.appendingPathComponent("Runtime/node")
        p.arguments = [resources.appendingPathComponent("CloudBridge/bridge.mjs").path, LocalEngine.support.appendingPathComponent("ChatGPT").path]
        let stdin = Pipe(), stdout = Pipe(); p.standardInput = stdin; p.standardOutput = stdout; p.standardError = FileHandle.nullDevice
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor in self?.receive(data) }
        }
        p.terminationHandler = { [weak self] _ in Task { @MainActor in
            guard let self else { return }; self.process = nil
            let waiting = self.pending; self.pending.removeAll()
            for continuation in waiting.values { continuation.resume(throwing: InigoError.message("The ChatGPT connection stopped. Please retry.")) }
        } }
        try p.run(); process = p; input = stdin.fileHandleForWriting
    }
    private func send(_ value: [String:Any]) throws {
        var data = try JSONSerialization.data(withJSONObject: value); data.append(10); try input?.write(contentsOf:data)
    }
    private func receive(_ data: Data) {
        buffer.append(data)
        while let end = buffer.firstIndex(of: 10) {
            let line = buffer.prefix(upTo:end); buffer.removeSubrange(...end)
            guard let value = try? JSONSerialization.jsonObject(with: line) as? [String:Any] else { continue }
            if let id = value["vault"] as? String {
                do { let result = try vault(value); try send(["vaultReply":id,"value":result]) }
                catch { try? send(["vaultReply":id,"error":true]) }
            } else if let string = value["openBrowser"] as? String, let url = URL(string:string), url.scheme == "https", ["auth.openai.com", "auth0.openai.com"].contains(url.host ?? "") { NSWorkspace.shared.open(url) }
            else if let id = value["id"] as? String, let continuation = pending.removeValue(forKey:id) {
                if let error = value["error"] as? [String:Any] { continuation.resume(throwing: InigoError.message(error["message"] as? String ?? "Cloud request failed.")) }
                else { continuation.resume(returning:value["result"] as? [String:Any] ?? [:]) }
            }
        }
    }
    private func vault(_ message: [String:Any]) throws -> String {
        guard let operation = message["operation"] as? String, let value = message["value"] as? String else { throw InigoError.message("Invalid credential operation.") }
        if operation == "delete", UUID(uuidString:value) != nil {
            let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:value]
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw InigoError.message("Could not remove old credentials.") }
            return "deleted"
        }
        if operation == "store" {
            let id = UUID().uuidString
            let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:id,kSecValueData as String:Data(value.utf8),kSecAttrAccessible as String:kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
            guard SecItemAdd(query as CFDictionary,nil) == errSecSuccess else { throw InigoError.message("Could not store credentials in Keychain.") }
            return id
        }
        guard operation == "load", UUID(uuidString:value) != nil else { throw InigoError.message("Invalid Keychain reference.") }
        let query: [String:Any] = [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:value,kSecReturnData as String:true,kSecMatchLimit as String:kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary,&result) == errSecSuccess, let data = result as? Data, let text = String(data:data,encoding:.utf8) else { throw InigoError.message("Unlock your Keychain to use ChatGPT.") }
        return text
    }
    func call(_ method: String, fields: [String:Any] = [:]) async throws -> [String:Any] {
        try launch(); let id = UUID().uuidString
        return try await withTaskCancellationHandler(operation: {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                pending[id] = continuation
                do { var value = fields; value["id"] = id; value["method"] = method; try send(value) }
                catch { pending.removeValue(forKey:id)?.resume(throwing:error) }
            }
        }, onCancel: { Task { @MainActor in try? self.send(["cancel":id]); self.pending.removeValue(forKey:id)?.resume(throwing:CancellationError()) } })
    }
    func signIn() async {
        busy = true; status = "Finish signing in in your browser…"; defer { busy = false }
        do { let result = try await call("signIn"); connected = result["sharing"] as? Bool == true; status = connected ? "Connected · using ChatGPT plan" : "Enable ChatGPT plan usage to continue" }
        catch { status = error.localizedDescription }
    }
    func refresh() async { if let result = try? await call("session") { connected = result["sharing"] as? Bool == true; status = connected ? "Connected · using ChatGPT plan" : "Not connected" } }
    func disconnect() async {
        do { let result = try await call("disconnect"); connected = false; status = result["revoked"] as? Bool == false ? "Signed out locally. Remove access in ChatGPT Settings to confirm remote revocation." : "Disconnected"
            // Remove any superseded credential records after the connection has signed out.
            SecItemDelete([kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service] as CFDictionary)
            try? FileManager.default.removeItem(at: LocalEngine.support.appendingPathComponent("ChatGPT/chatgpt-auth.json"))
        } catch { status = "Sign-out could not complete. Check your connection and retry." }
    }
    func rewrite(_ request: RewriteRequest) async throws -> String {
        let result = try await call("rewrite",fields:["instructions":request.instructions,"input":request.input])
        guard let text = result["text"] as? String else { throw InigoError.message("ChatGPT returned no completed rewrite.") }; return text
    }
    func cancelSignIn() { process?.terminate(); status = "Sign-in cancelled" }
    func stop() { process?.terminate() }
}
