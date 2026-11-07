import UIKit
import UniformTypeIdentifiers

final class ShareViewController: DraftViewController {
    private var loading: Progress?
    private var generation = UUID()
    override func viewDidLoad() {
        isShare = true
        super.viewDidLoad()
        onClose = { [weak self] in
            guard let self else { return }
            self.generation = UUID(); self.loading?.cancel()
            self.extensionContext?.completeRequest(returningItems: nil)
        }
        copyButton.isEnabled = false
        let items = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = items.flatMap { $0.attachments ?? [] }.filter { $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) }
        guard providers.count == 1 else {
            status.text = "Share one text selection. If this app cannot share text, open Inigo and use Paste."; return
        }
        let invocation = generation
        loading = providers[0].loadObject(ofClass: NSString.self) { [weak self] item, error in
            let text = item as? String
            DispatchQueue.main.async {
                guard let self, self.generation == invocation else { return }
                guard error == nil, let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 20_000 else {
                    self.status.text = "This selection could not be read as text, or exceeds 20,000 characters. Nothing was copied."; return
                }
                self.draft.text = text; self.copyButton.isEnabled = true
            }
        }
    }
    deinit { loading?.cancel() }
}
