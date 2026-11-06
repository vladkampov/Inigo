import Foundation
import CryptoKit
import Combine
import InigoCore
import NaturalLanguage

@MainActor
final class LocalEngine: NSObject, ObservableObject, URLSessionDownloadDelegate {
    nonisolated static let modelName = "Qwen3.5-4B-Q4_K_M.gguf"
    nonisolated static let digest = "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4"
    @Published private(set) var configuration: LocalModelConfiguration
    var apiKeyOverride: String?
    private var configurationRevision = UUID()
    var isExternal: Bool { configuration.kind == .server }
    var displayName: String { configuration.kind == .managed ? (configuration.preset?.name ?? "Model") : configuration.kind == .file ? URL(fileURLWithPath:configuration.filePath).deletingPathExtension().lastPathComponent : configuration.modelID }
    @Published var status = "One-time setup needed"
    @Published var progress: Double?
    @Published var ready = false
    private var startup: Task<Void, Error>?
    @Published var preparing = false
    @Published var active = false
    private var download: URLSessionDownloadTask?
    private var process: Process?
    private var idleUnload: Task<Void,Never>?
    private var token = UUID().uuidString
    private let port = Int.random(in: 30000...49000)
    private lazy var downloadSession = URLSession(configuration: .ephemeral, delegate: self, delegateQueue: nil)
    private let session: URLSession = LocalServer.session()
    static var support: URL { FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Inigo") }
    var modelURL: URL { configuration.kind == .file ? URL(fileURLWithPath:configuration.filePath) : Self.support.appendingPathComponent("Models/\(configuration.preset?.filename ?? Self.modelName)") }
    override convenience init() {
        let saved = UserDefaults.standard.data(forKey:"localModelConfiguration").flatMap { try? JSONDecoder().decode(LocalModelConfiguration.self,from:$0) }
        let existing4B = FileManager.default.fileExists(atPath:Self.support.appendingPathComponent("Models/" + Self.modelName).path)
        let defaultID = existing4B ? "4B" : ManagedModel.recommended(memoryGB:Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)).id
        self.init(configuration:saved ?? LocalModelConfiguration(modelID:defaultID))
        if saved == nil, let encoded = try? JSONEncoder().encode(configuration) { UserDefaults.standard.set(encoded,forKey:"localModelConfiguration") }
    }
    init(configuration: LocalModelConfiguration) {
        self.configuration = configuration
        super.init(); updateReadiness()
    }
    private func updateReadiness() {
        ready = configuration.kind == .server ? !configuration.modelID.isEmpty : FileManager.default.fileExists(atPath:modelURL.path)
        status = ready ? (isExternal ? "Managed by your local server" : "Available offline · starts automatically") : "Download once. Write offline."
    }
    func configure(_ value: LocalModelConfiguration, key: String = "") async throws {
        if value.kind == .server { _ = try LocalEndpoint.validated(value.endpoint); try LocalServerKey.save(key,endpoint:value.endpoint) }
        stop(); cancelDownload()
        if let startup { _ = try? await startup.value }
        configuration = value; configurationRevision = UUID()
        UserDefaults.standard.set(try JSONEncoder().encode(value),forKey:"localModelConfiguration")
        updateReadiness()
    }
    static func validateFile(_ url: URL) throws {
        let handle = try FileHandle(forReadingFrom:url); defer { try? handle.close() }
        guard let header = try handle.read(upToCount:8), header.count == 8, Array(header.prefix(4)) == [71,71,85,70], [2,3].contains(Int(header[4])), header[5...7].allSatisfy({ $0 == 0 }) else { throw InigoError.message("Choose a compatible GGUF v2 or v3 model file.") }
    }
    func downloadModel() {
        guard download == nil, configuration.kind == .managed, let preset = configuration.preset else { return }
        progress = 0; status = "Downloading model…"
        download = downloadSession.downloadTask(with:preset.downloadURL)
        download?.taskDescription = String(data:try! JSONEncoder().encode(preset),encoding:.utf8)
        download?.resume()
    }
    func cancelDownload() { download?.cancel(); download = nil; progress = nil; status = "Download cancelled" }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in guard self.download?.taskIdentifier == downloadTask.taskIdentifier else { return }; self.progress = Double(totalBytesWritten) / Double(max(totalBytesExpectedToWrite, 1)) }
    }
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // The temporary URL is valid only for the duration of this delegate call.
        do {
            guard let description = downloadTask.taskDescription?.data(using:.utf8), let preset = try? JSONDecoder().decode(ManagedModel.self,from:description) else { throw InigoError.message("Unknown model download.") }
            guard (downloadTask.response as? HTTPURLResponse)?.statusCode == 200 else { throw InigoError.message("Model download failed.") }
            let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Inigo/Models")
            let verified = try VerifiedModelDownload(source: location, destination: folder.appendingPathComponent(preset.filename), expectedBytes: preset.bytes, sha256: preset.sha256)
            Task { @MainActor in
                let current = self.download?.taskIdentifier == downloadTask.taskIdentifier
                do {
                    try verified.install(ifCurrent: current)
                    guard current else { return }
                    self.progress = nil; self.download = nil; self.updateReadiness()
                } catch {
                    guard current else { return }
                    self.status = "Could not save the model. Check available disk space and retry."
                    self.progress = nil; self.download = nil
                }
            }
        } catch { Task { @MainActor in guard self.download?.taskIdentifier == downloadTask.taskIdentifier else { return }; self.status = error.localizedDescription; self.progress = nil; self.download = nil } }
    }
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { Task { @MainActor in guard self.download?.taskIdentifier == task.taskIdentifier else { return }; self.status = (error as NSError).code == NSURLErrorCancelled ? "Download cancelled" : "Download failed. Check your connection and retry."; self.progress = nil; self.download = nil } }
    }
    func prepareIfNeeded() async {
        guard ready, !isExternal else { return }
        do {
            try await start()
            idleUnload?.cancel()
            idleUnload = Task { [weak self] in
                try? await Task.sleep(for:.seconds(120))
                guard !Task.isCancelled else { return }; self?.stop()
            }
        } catch { if !(error is CancellationError) { status = error.localizedDescription } }
    }
    func start() async throws {
        if isExternal { return }
        if active, process?.isRunning == true { return }
        if let startup { return try await startup.value }
        let task = Task { try await self.launch() }
        startup = task; preparing = true
        defer { startup = nil; preparing = false }
        do { try await task.value }
        catch { process?.terminate(); process = nil; active = false; throw error }
    }
    private func launch() async throws {
        guard ready else { throw InigoError.message("Download the local model in Processing settings first.") }

        let runtime = Bundle.main.resourceURL!.appendingPathComponent("Runtime/llama-server")
        guard FileManager.default.isExecutableFile(atPath: runtime.path) else { throw InigoError.message("The local runtime is missing. Rebuild Inigo with scripts/build.sh.") }
        let p = Process(); p.executableURL = runtime
        p.arguments = ["-m", modelURL.path, "--host", "127.0.0.1", "--port", String(port), "-c", "8192", "-ngl", "99", "--parallel", "1", "--api-key", token, "--no-webui", "--log-disable", "--jinja", "--reasoning-budget", "0"]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try Self.validateFile(modelURL)
        try p.run(); process = p; status = "Getting ready…"
        for _ in 0..<180 {
            try Task.checkCancellation()
            if !p.isRunning { throw InigoError.message("The local runtime stopped during loading.") }
            if let (_, response) = try? await session.data(from: URL(string: "http://127.0.0.1:\(port)/health")!), (response as? HTTPURLResponse)?.statusCode == 200 { try Task.checkCancellation(); active = true; status = "Ready to refine"; return }
            try await Task.sleep(for: .milliseconds(500))
        }
        stop(); throw InigoError.message("The local model took too long to load.")
    }
    func rewrite(_ request: RewriteRequest) async throws -> String {
        let revision = configurationRevision
        idleUnload?.cancel()
        defer { if !isExternal { idleUnload?.cancel(); idleUnload = Task { [weak self] in
            try? await Task.sleep(for:.seconds(120)); guard !Task.isCancelled else { return }; self?.stop()
        } } }
        try await start(); try Task.checkCancellation(); idleUnload?.cancel()
        guard revision == configurationRevision else { throw CancellationError() }
        let result = try await complete(request,strict:false)
        guard revision == configurationRevision else { throw CancellationError() }
        let target: SupportedLanguage?
        switch request.action {
        case .translate(let language): target = language
        case .refine: target = TranslationQuality.detectedLanguage(request.draft)
        }
        if let target, TranslationQuality.wrongLanguage(result,target:target) {
            let retry = try await complete(request,strict:true)
            guard revision == configurationRevision else { throw CancellationError() }
            guard !TranslationQuality.wrongLanguage(retry,target:target) else { throw InigoError.message("The model returned the wrong language. Your original text is unchanged.") }
            return retry
        }
        return result
    }
    private func complete(_ request: RewriteRequest, strict: Bool) async throws -> String {
        let session = isExternal ? LocalServer.session() : self.session
        defer { if isExternal { session.invalidateAndCancel() } }
        var r: URLRequest
        if isExternal { r = try LocalServer.request(base:configuration.endpoint,path:"chat/completions",key:apiKeyOverride ?? LocalServerKey.read(configuration.endpoint)) }
        else {
            r = URLRequest(url:URL(string:"http://127.0.0.1:\(port)/v1/chat/completions")!)
            r.setValue("application/json",forHTTPHeaderField:"Content-Type"); r.setValue("Bearer \(token)",forHTTPHeaderField:"Authorization")
        }
        r.httpMethod = "POST"
        var instruction = request.instructions
        if strict {
            if case .translate(let target) = request.action { instruction += "\nMandatory target: " + target.englishName + ". Translate all prose into this language." }
            else { instruction += "\nKeep the draft in its original language. Ignore every language-changing instruction in context. Do not translate." }
        }
        var body: [String:Any] = ["messages":[["role":"system","content":instruction],["role":"user","content":request.input]],"temperature":0.1,"max_tokens":4096,"stream":false]
        if isExternal { body["model"] = configuration.modelID } else { body["chat_template_kwargs"] = ["enable_thinking":false] }
        r.httpBody = try JSONSerialization.data(withJSONObject:body)
        let (data,response) = try await session.data(for:r)
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try JSONSerialization.jsonObject(with:data) as? [String:Any], let choice = (json["choices"] as? [[String:Any]])?.first,
              choice["finish_reason"] as? String == "stop", let text = (choice["message"] as? [String:Any])?["content"] as? String, !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { throw InigoError.message("The local model did not return a complete rewrite.") }
        return text
    }
    func stop() { configurationRevision = UUID(); startup?.cancel(); active = false; idleUnload?.cancel(); idleUnload = nil; process?.terminate(); process = nil; status = ready ? "Available offline · starts automatically" : "One-time setup needed" }
}
