import Foundation

public enum DiagnosticCode: String, Codable, Sendable {
    case rewriteFailed = "rewrite_failed"
    case replacementUnconfirmed = "replacement_unconfirmed"
}
public struct DiagnosticEvent: Encodable, Sendable {
    public let event_id: String
    public let level = "error"
    public let platform = "cocoa"
    public let message: DiagnosticCode
    public let release: String
    public let tags: [String:String]
    public init(code: DiagnosticCode, version: String, osMajor: Int) {
        event_id = UUID().uuidString.replacingOccurrences(of:"-",with:"").lowercased()
        message = code
        // Only a version-shaped value is accepted, never arbitrary environment text.
        release = version.range(of:#"^[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$"#,options:.regularExpression) != nil ? "Inigo@" + version : "Inigo@development"
        tags = ["os_major":String(max(0,osMajor))]
    }
}
