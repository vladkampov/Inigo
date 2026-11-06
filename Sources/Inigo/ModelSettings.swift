import SwiftUI
import AppKit
import InigoCore

struct ModelSettings: View {
    @ObservedObject var model: AppModel
    @ObservedObject var local: LocalEngine
    @State private var endpoint = "http://127.0.0.1:11434/v1"
    @State private var key = ""
    @State private var serverModel = ""
    @State private var models: [String] = []
    @State private var busy = false
    @State private var notice = ""
    private var memory: Int { Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824) }
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            Text(L("Choose what powers your writing.")).foregroundStyle(.secondary)
            HStack {
                VStack(alignment:.leading,spacing:5) {
                    Text(local.displayName).font(.headline)
                    Text(L(local.status)).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if local.preparing || busy { ProgressView().controlSize(.small) }
                if local.progress != nil { Button(L("Cancel")) { local.cancelDownload() } }
                else if !local.ready && local.configuration.kind == .managed {
                    Button(L("Download model")) { local.downloadModel() }
                }
            }.padding(16).background(.quaternary,in:RoundedRectangle(cornerRadius:12))
            if let progress = local.progress { ProgressView(value:progress) }
            Text(L("Your Mac has %d GB of memory.").replacingOccurrences(of:"%d",with:String(memory))).font(.caption).foregroundStyle(.secondary)
            ForEach(ManagedModel.all) { preset in
                HStack {
                    VStack(alignment:.leading,spacing:4) {
                        Text(preset.name).fontWeight(.medium)
                        Text(ByteCountFormatter.string(fromByteCount:preset.bytes,countStyle:.decimal))
                            .font(.caption).foregroundStyle(.secondary)
                        if preset.id == ManagedModel.recommended(memoryGB:memory).id {
                            Text(L("Recommended for your Mac")).font(.caption).foregroundStyle(.tint)
                        }
                    }
                    Spacer()
                    if local.configuration.kind == .managed && local.configuration.modelID == preset.id {
                        Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Button(L("Use model")) { use(.init(modelID:preset.id)) }
                            .disabled(busy || model.working || memory < preset.minimumMemoryGB)
                    }
                }
            }
            Text(L("On an M5 with 24 GB, 9B gave the most faithful English, Polish and Ukrainian results at about 4 seconds. 4B took about 2 seconds; 2B about 1 second, with more quality errors. All results still need review.")).font(.caption).foregroundStyle(.secondary)
            Text(L("Downloads are verified before use. Models start automatically and release memory when idle.")).font(.caption).foregroundStyle(.secondary)
            Divider()
            DisclosureGroup(L("Use your own local model")) {
                VStack(alignment:.leading,spacing:14) {
                    Text(L("Choose a GGUF file compatible with llama.cpp. Inigo tests it before switching; your file stays where it is.")).font(.caption).foregroundStyle(.secondary)
                    Button(L("Choose GGUF file…")) {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url {
                            testAndUse(.init(kind:.file,filePath:url.path))
                        }
                    }
                    Divider()
                    Text(L("Connect a local server")).font(.headline)
                    Text(L("Use an OpenAI-compatible endpoint from Ollama, LM Studio or another local server. Only loopback addresses are accepted. Make sure your server runs the model locally; Inigo cannot control whether it forwards requests elsewhere.")).font(.caption).foregroundStyle(.secondary)
                    TextField(L("Server address"),text:$endpoint).textFieldStyle(.roundedBorder)
                    SecureField(L("API key (optional)"),text:$key).textFieldStyle(.roundedBorder)
                    Button(L("Find models")) {
                        busy = true; notice = ""
                        Task { defer { busy = false }
                            do { models = try await LocalServer.models(base:endpoint,key:key); serverModel = models.first ?? ""; if models.isEmpty { notice = L("No models found.") } }
                            catch { notice = error.localizedDescription }
                        }
                    }
                    TextField(L("Model ID"),text:$serverModel).textFieldStyle(.roundedBorder)
                    if !models.isEmpty {
                        Picker(L("Available models"),selection:$serverModel) {
                            ForEach(models,id:\.self) { Text($0).tag($0) }
                        }
                    }
                    Button(L("Test and use")) { testAndUse(.init(kind:.server,modelID:serverModel,endpoint:endpoint)) }
                        .disabled(serverModel.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                    Text(L("The test uses a sample sentence, never your writing. Credentials are saved in Keychain.")).font(.caption).foregroundStyle(.secondary)
                }.padding(.top,12).disabled(busy || model.working)
            }
            if !notice.isEmpty { Text(L(notice)).font(.callout).textSelection(.enabled) }
        }
        .onAppear {
            if local.configuration.kind == .server {
                endpoint = local.configuration.endpoint; serverModel = local.configuration.modelID
                key = LocalServerKey.read(endpoint)
            }
        }
    }
    private func use(_ configuration: LocalModelConfiguration) {
        busy = true; notice = ""; model.cancel(); model.clearResult()
        Task { defer { busy = false }
            do { try await local.configure(configuration); notice = L("Model selected.") }
            catch { notice = error.localizedDescription }
        }
    }
    private func testAndUse(_ configuration: LocalModelConfiguration) {
        busy = true; notice = L("Testing with a sample sentence…")
        let credential = key
        Task { defer { busy = false }
            let probe = LocalEngine(configuration:configuration); probe.apiKeyOverride = credential
            defer { probe.stop() }
            do {
                if configuration.kind == .file { try LocalEngine.validateFile(URL(fileURLWithPath:configuration.filePath)) }
                let sample = try ProtectedDraft("Hello @alex, could you please check https://example.com and share an update when you have time?")
                _ = try sample.restore(try await probe.rewrite(RewriteRequest(draft:sample.masked)))
                model.cancel(); model.clearResult()
                try await local.configure(configuration,key:credential)
                notice = L("Connection tested. Your model is ready.")
            } catch { notice = error.localizedDescription }
        }
    }
}
