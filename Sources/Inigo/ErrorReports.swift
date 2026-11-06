import Foundation
import Combine
import InigoCore

@MainActor
final class ErrorReports: ObservableObject {
    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled,forKey:"sendErrorReports")
            if !enabled { session?.invalidateAndCancel(); session = nil }
        }
    }
    let configured: Bool
    private let endpoint: URL?
    private let dsn: String
    private var session: URLSession?
    private var lastSent: [DiagnosticCode:Date] = [:]
    private var sent = 0
    init() {
        dsn = Bundle.main.object(forInfoDictionaryKey:"InigoSentryDSN") as? String ?? ""
        endpoint = Self.endpoint(dsn)
        configured = endpoint != nil
        enabled = UserDefaults.standard.bool(forKey:"sendErrorReports")
    }
    static func endpoint(_ dsn: String) -> URL? {
        guard let parts = URLComponents(string:dsn), parts.scheme == "https",
              let host = parts.host, host.hasSuffix(".sentry.io"), host.contains(".ingest."),
              let key = parts.user, !key.isEmpty, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port == nil, let project = parts.path.split(separator:"/").last,
              parts.path == "/" + project, project.allSatisfy(\.isNumber) else { return nil }
        return URL(string:"https://\(host)/api/\(project)/envelope/")
    }
    func capture(_ code: DiagnosticCode) {
        guard enabled, let endpoint, sent < 10,
              Date().timeIntervalSince(lastSent[code] ?? .distantPast) >= 300 else { return }
        sent += 1; lastSent[code] = Date()
        let event = DiagnosticEvent(code:code,version:Bundle.main.object(forInfoDictionaryKey:"InigoDisplayVersion") as? String ?? "",osMajor:ProcessInfo.processInfo.operatingSystemVersion.majorVersion)
        guard let payload = try? JSONEncoder().encode(event),
              let header = try? JSONSerialization.data(withJSONObject:["event_id":event.event_id,"dsn":dsn]),
              let item = try? JSONSerialization.data(withJSONObject:["type":"event","length":payload.count]) else { return }
        var request = URLRequest(url:endpoint); request.httpMethod = "POST"
        request.setValue("application/x-sentry-envelope",forHTTPHeaderField:"Content-Type")
        request.httpBody = header + Data([10]) + item + Data([10]) + payload + Data([10])
        if session == nil {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil; configuration.httpCookieStorage = nil; configuration.timeoutIntervalForRequest = 10
            session = URLSession(configuration:configuration,delegate:NoRedirects(),delegateQueue:nil)
        }
        // No retries, disk queue, response logging, raw errors or text-bearing parameters.
        session?.dataTask(with:request) { _,_,_ in }.resume()
    }
}
