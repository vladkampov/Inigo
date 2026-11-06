import SafariServices
import Network

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    private var connection: NWConnection?
    private var timeout: DispatchWorkItem?
    private var finished = false
    func beginRequest(with context: NSExtensionContext) {
        guard let item = context.inputItems.first as? NSExtensionItem,
              var message = item.userInfo?[SFExtensionMessageKey] as? [String:Any],
              message["private"] as? Bool == false,
              let draft = message["draft"] as? String, !draft.isEmpty, draft.utf16.count <= 20_000,
              let surrounding = message["context"] as? String, surrounding.count <= 6000 else {
            finish(context,["error":"This field cannot be read safely."]); return
        }
        guard let folder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier:"group.app.inigo.personal"),
              let data = try? Data(contentsOf:folder.appendingPathComponent("inigo-browser-route.json")),
              let route = try? JSONSerialization.jsonObject(with:data) as? [String:Any],
              let port = route["port"] as? Int, (1024...65535).contains(port), let token = route["token"] as? String else {
            finish(context,["error":"Open the signed Inigo app with the shared Safari connection configured."]); return
        }
        message["token"] = token
        guard var payload = try? JSONSerialization.data(withJSONObject:message) else { finish(context,["error":"Invalid request."]); return }; payload.append(10)
        let connection = NWConnection(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:UInt16(port))!,using:.tcp); self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                connection.send(content:payload,completion:.contentProcessed { error in
                    if error != nil { self.finish(context,["error":"The local Inigo connection failed."]) }
                    else { self.read(context,Data()) }
                })
            case .failed: self.finish(context,["error":"Open Inigo and try again."])
            default: break
            }
        }
        let deadline = DispatchWorkItem { [weak self] in self?.finish(context,["error":"The rewrite timed out."]) }; timeout = deadline
        DispatchQueue.main.asyncAfter(deadline:.now()+120,execute:deadline)
        connection.start(queue:.main)
    }
    private func read(_ context:NSExtensionContext,_ previous:Data) {
        connection?.receive(minimumIncompleteLength:1,maximumLength:65536) { [weak self] data,_,ended,error in
            guard let self else { return }; var buffer = previous; if let data { buffer.append(data) }
            guard buffer.count <= 100_000, error == nil else { self.finish(context,["error":"The reply could not be read safely."]); return }
            if let end = buffer.firstIndex(of:10), let result = try? JSONSerialization.jsonObject(with:buffer.prefix(upTo:end)) as? [String:Any] { self.finish(context,result) }
            else if ended { self.finish(context,["error":"The local connection ended early."]) }
            else { self.read(context,buffer) }
        }
    }
    private func finish(_ context:NSExtensionContext,_ message:[String:Any]) {
        guard !finished else { return }; finished = true; timeout?.cancel(); connection?.cancel()
        let response = NSExtensionItem(); response.userInfo = [SFExtensionMessageKey:message]
        context.completeRequest(returningItems:[response],completionHandler:nil)
    }
}
