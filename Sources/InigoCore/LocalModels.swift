import Foundation

public struct ManagedModel: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let filename: String
    public let revision: String
    public let bytes: Int64
    public let sha256: String
    public let minimumMemoryGB: Int
    public var downloadURL: URL { URL(string:"https://huggingface.co/unsloth/Qwen3.5-\(id)-GGUF/resolve/\(revision)/\(filename)")! }
    public static let all: [ManagedModel] = [
        .init(id:"2B",name:"Qwen 3.5 · 2B",filename:"Qwen3.5-2B-Q4_K_M.gguf",revision:"f6d5376be1edb4d416d56da11e5397a961aca8ae",bytes:1280835840,sha256:"aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223",minimumMemoryGB:8),
        .init(id:"4B",name:"Qwen 3.5 · 4B",filename:"Qwen3.5-4B-Q4_K_M.gguf",revision:"e87f176479d0855a907a41277aca2f8ee7a09523",bytes:2740937888,sha256:"00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4",minimumMemoryGB:16),
        .init(id:"9B",name:"Qwen 3.5 · 9B",filename:"Qwen3.5-9B-Q4_K_M.gguf",revision:"3885219b6810b007914f3a7950a8d1b469d598a5",bytes:5680522464,sha256:"03b74727a860a56338e042c4420bb3f04b2fec5734175f4cb9fa853daf52b7e8",minimumMemoryGB:24),
    ]
    public static func recommended(memoryGB: Int) -> ManagedModel { all[memoryGB >= 24 ? 2 : memoryGB >= 16 ? 1 : 0] }
}
public struct LocalModelConfiguration: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable { case managed, file, server }
    public var kind: Kind = .managed
    public var modelID: String = "4B"
    public var filePath: String = ""
    public var endpoint: String = "http://127.0.0.1:11434/v1"
    public init(kind: Kind = .managed, modelID: String = "4B", filePath: String = "", endpoint: String = "http://127.0.0.1:11434/v1") {
        self.kind = kind; self.modelID = modelID; self.filePath = filePath; self.endpoint = endpoint
    }
    public var preset: ManagedModel? { ManagedModel.all.first { $0.id == modelID } }
}
public enum LocalEndpoint {
    public static func validated(_ value: String) throws -> URL {
        guard let url = URL(string:value), let parts = URLComponents(url:url,resolvingAgainstBaseURL:false),
              ["http","https"].contains(parts.scheme ?? ""),
              ["127.0.0.1","[::1]","::1","localhost"].contains(parts.host?.lowercased() ?? ""),
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.port.map({ $0 > 0 && $0 < 65536 }) ?? true else {
            throw InigoError.message("Use a local server address such as http://127.0.0.1:11434/v1.")
        }
        // Pin localhost to loopback rather than trusting DNS or a hosts-file alias.
        var pinned = parts
        if pinned.host?.lowercased() == "localhost" { pinned.host = "127.0.0.1" }
        guard let result = pinned.url else { throw InigoError.message("Invalid local server address.") }
        return result
    }
}
