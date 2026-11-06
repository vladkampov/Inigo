import Foundation

/// Populate these bundle keys when the public destinations exist.
enum SupportLinks {
    static var repository: URL? { validated("InigoRepositoryURL",host:"github.com") }
    static var coffee: URL? { validated("InigoCoffeeURL",host:"buymeacoffee.com") }
    static func issue(_ title: String) -> URL? {
        guard let repository else { return nil }
        var components = URLComponents(url:repository.appendingPathComponent("issues/new"),resolvingAgainstBaseURL:false)
        let template = ["Report a bug":"bug_report.yml","Request a feature":"feature_request.yml","Share feedback":"feedback.yml"][title]
        components?.queryItems = template.map { [URLQueryItem(name:"template",value:$0)] } ?? []
        return components?.url
    }
    private static func validated(_ key: String, host: String) -> URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey:key) as? String,
              let url = URL(string:value), url.scheme == "https", url.host == host else { return nil }
        return url
    }
}
