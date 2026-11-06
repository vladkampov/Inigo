import Foundation
import Security
import InigoCore

final class NoRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
enum LocalServer {
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil; configuration.timeoutIntervalForRequest = 120
        configuration.connectionProxyDictionary = [:]
        return URLSession(configuration:configuration,delegate:NoRedirects(),delegateQueue:nil)
    }
    static func request(base: String, path: String, key: String = "") throws -> URLRequest {
        var request = URLRequest(url:try LocalEndpoint.validated(base).appendingPathComponent(path))
        request.setValue("application/json",forHTTPHeaderField:"Content-Type")
        if !key.isEmpty { request.setValue("Bearer \(key)",forHTTPHeaderField:"Authorization") }
        return request
    }
    static func models(base: String, key: String) async throws -> [String] {
        let session = session(); defer { session.invalidateAndCancel() }
        let (data,response) = try await session.data(for:request(base:base,path:"models",key:key))
        guard (response as? HTTPURLResponse)?.statusCode == 200,
              let object = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              let list = object["data"] as? [[String:Any]] else { throw InigoError.message("The local server did not return a model list.") }
        return list.compactMap { $0["id"] as? String }.filter { !$0.isEmpty }.sorted()
    }
}
enum LocalServerKey {
    private static func query(_ endpoint: String) -> [String:Any] { [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:"app.inigo.local-server",kSecAttrAccount as String:endpoint] }
    static func read(_ endpoint: String) -> String {
        var q = query(endpoint); q[kSecReturnData as String] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&result) == errSecSuccess, let data = result as? Data else { return "" }
        return String(data:data,encoding:.utf8) ?? ""
    }
    static func save(_ value: String, endpoint: String) throws {
        let q = query(endpoint)
        if value.isEmpty { SecItemDelete(q as CFDictionary); return }
        let status = SecItemUpdate(q as CFDictionary,[kSecValueData as String:Data(value.utf8)] as CFDictionary)
        if status == errSecItemNotFound {
            var addition = q; addition[kSecValueData as String] = Data(value.utf8)
            addition[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            guard SecItemAdd(addition as CFDictionary,nil) == errSecSuccess else { throw InigoError.message("Could not save the local server credential in Keychain.") }; return
        }
        guard status == errSecSuccess else { throw InigoError.message("Could not save the local server credential in Keychain.") }
    }
}
