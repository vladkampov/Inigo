import Foundation
import Network
import InigoCore

// Only the locally installed native-messaging host knows this per-launch token.
// No browser-origin HTTP endpoint, no all-sites content script, and no writing on disk.
@MainActor
final class BrowserBridge {
    private var listener: NWListener?
    private let token = UUID().uuidString + UUID().uuidString
    private weak var model: AppModel?
    private var tasks: [UUID: Task<Void,Never>] = [:]
    private var sharedRoute: URL? {
        guard Bundle.main.object(forInfoDictionaryKey:"InigoSafariEnabled") as? Bool == true else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:"group.app.inigo.personal")?.appendingPathComponent("inigo-browser-route.json")
    }
    private var routeURL: URL { LocalEngine.support.appendingPathComponent("browser-route.json") }
    func start(model: AppModel) throws {
        self.model = model
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:.any)
        let listener = try NWListener(using:params); self.listener = listener
        listener.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                if case .ready = state, let port = self.listener?.port {
                    do {
                        try FileManager.default.createDirectory(at:LocalEngine.support,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
                        let data = try JSONSerialization.data(withJSONObject:["port":Int(port.rawValue),"token":self.token])
                        try data.write(to:self.routeURL,options:.atomic)
                        try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:self.routeURL.path)
                        if let shared = self.sharedRoute { try data.write(to:shared,options:.atomic); try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:shared.path) }
                    } catch { self.stop() }
                }
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { @MainActor in self?.accept(connection) }
        }
        listener.start(queue:.main)
    }
    private func accept(_ connection: NWConnection) {
        connection.start(queue:.main)
        read(connection,data:Data())
    }
    private func read(_ connection: NWConnection, data: Data) {
        connection.receive(minimumIncompleteLength:1,maximumLength:65536) { [weak self] bytes,_,ended,error in
            Task { @MainActor in
                guard let self else { connection.cancel(); return }
                var all = data; if let bytes { all.append(bytes) }
                guard all.count <= 100_000, error == nil else { connection.cancel(); return }
                if all.contains(10) { self.handle(connection,data:all.prefix { $0 != 10 }) }
                else if !ended { self.read(connection,data:all) } else { connection.cancel() }
            }
        }
    }
    private func handle(_ connection: NWConnection,data:Data) {
        guard let model, let value = try? JSONSerialization.jsonObject(with:data) as? [String:Any], value["token"] as? String == token,
              value["private"] as? Bool == false, let draft = value["draft"] as? String, !draft.isEmpty, draft.utf16.count <= 20_000,
              let context = value["context"] as? String, context.count <= 6000 else { connection.cancel(); return }
        let id = UUID(); let mode = model.preferences.mode
        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state { Task { @MainActor in self?.tasks.removeValue(forKey:id)?.cancel() } }
        }
        // Detect the native host closing the socket when typing cancels the browser request.
        connection.receive(minimumIncompleteLength:1,maximumLength:1) { [weak self] _,_,ended,error in
            if ended || error != nil { Task { @MainActor in self?.tasks.removeValue(forKey:id)?.cancel(); connection.cancel() } }
        }
        tasks[id] = Task {
            do {
                let protected = try ProtectedDraft(draft)
                let request = RewriteRequest(draft:protected.masked,context:context,style:model.preferences.profile.preferences(for:Preferences.language(draft)))
                let output = try await (mode == "Local" ? model.local.rewrite(request) : model.cloud.rewrite(request))
                try Task.checkCancellation()
                guard model.preferences.mode == mode else { throw CancellationError() }
                let result = try protected.restore(output)
                self.reply(connection,["text":result])
            } catch { if !Task.isCancelled { self.reply(connection,["error":error.localizedDescription]) } }
            self.tasks.removeValue(forKey:id)
        }
    }
    private func reply(_ connection:NWConnection,_ object:[String:Any]) {
        guard var data = try? JSONSerialization.data(withJSONObject:object) else { connection.cancel(); return }; data.append(10)
        connection.send(content:data,completion:.contentProcessed { _ in connection.cancel() })
    }
    func stop() { tasks.values.forEach { $0.cancel() }; tasks.removeAll(); listener?.cancel(); try? FileManager.default.removeItem(at:routeURL); if let sharedRoute { try? FileManager.default.removeItem(at:sharedRoute) } }
}
