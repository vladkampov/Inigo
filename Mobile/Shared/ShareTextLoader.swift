import Foundation
import UniformTypeIdentifiers

/// Text only: never fetch shared URLs or interpret HTML/files as a draft.
enum ShareTextLoader {
    enum Failure: LocalizedError {
        case missing, multiple, unreadable, tooLong
        var errorDescription: String? {
            switch self {
            case .missing: return "No text was shared. Select words in your app, then choose Share. You can also copy them and use Paste in Inigo."
            case .multiple: return "Share one text selection at a time. Nothing was copied."
            case .unreadable: return "This app did not provide readable text. Copy the selection, then use Paste in Inigo."
            case .tooLong: return "Choose up to 20,000 characters. Nothing was copied."
            }
        }
    }
    static func validate(_ text: String) throws -> String {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw Failure.missing }
        guard text.utf16.count <= 20_000 else { throw Failure.tooLong }
        return text
    }
    static func load(_ items: [NSExtensionItem], completion: @escaping (Result<String, Error>) -> Void) {
        // Notes and other hosts can supply attributedContentText without a provider.
        let direct = items.compactMap { $0.attributedContentText?.string }.filter { !$0.isEmpty }
        if !direct.isEmpty {
            guard direct.count == 1 else { completion(.failure(Failure.multiple)); return }
            completion(Result { try validate(direct[0]) }); return
        }
        let providers = items.flatMap { $0.attachments ?? [] }.filter { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        guard providers.count == 1 else {
            completion(.failure(providers.isEmpty ? Failure.missing : Failure.multiple)); return
        }
        // loadItem supports providers that advertise text but not NSString object loading.
        providers[0].loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, error in
            if let error { completion(.failure(error)); return }
            let text: String?
            if let value = item as? String { text = value }
            else if let value = item as? NSAttributedString { text = value.string }
            else if let value = item as? Data { text = String(data: value, encoding: .utf8) }
            else { text = nil }
            completion(Result {
                guard let text else { throw Failure.unreadable }
                return try validate(text)
            })
        }
    }
}
