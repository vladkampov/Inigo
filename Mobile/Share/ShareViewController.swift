import UIKit

final class ShareViewController: DraftViewController {
    private var generation = UUID()
    private var started = false
    private var timeout: DispatchWorkItem?
    override func viewDidLoad() {
        isShare = true
        super.viewDidLoad()
        onClose = { [weak self] in
            guard let self else { return }
            self.generation = UUID(); self.timeout?.cancel()
            self.extensionContext?.completeRequest(returningItems: nil)
        }
        copyButton.isEnabled = false
        showStatus("Loading your selection…")
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }; started = true
        let invocation = generation
        let expiry = DispatchWorkItem { [weak self] in
            guard let self, self.generation == invocation else { return }
            self.generation = UUID()
            self.showStatus("The host app did not finish sharing. Cancel and retry, or copy the text and use Paste in Inigo.")
        }
        timeout = expiry; DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: expiry)
        ShareTextLoader.load(extensionContext?.inputItems as? [NSExtensionItem] ?? []) { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.generation == invocation else { return }
                self.timeout?.cancel()
                switch result {
                case .success(let text):
                    self.receive(text)
                case .failure(let error): self.showStatus(error.localizedDescription)
                }
            }
        }
    }
    deinit { timeout?.cancel() }
}
