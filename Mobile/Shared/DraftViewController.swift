import UIKit
import UniformTypeIdentifiers
import InigoCore

/// Phase-one transport prototype: no automatic refinement or host editing claim.
class DraftViewController: UIViewController {
    let draft = UITextView()
    let status = UILabel()
    let copyButton = UIButton(type: .system)
    var onClose: (() -> Void)?
    var isShare = false
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Inigo · Round-trip prototype"
        status.text = "No AI changes yet. Edit this text, then copy it back to your app. Mentions and rich objects may arrive as plain text."
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .subheadline)
        status.adjustsFontForContentSizeCategory = true
        draft.font = .preferredFont(forTextStyle: .body)
        draft.adjustsFontForContentSizeCategory = true
        draft.accessibilityLabel = "Shared draft"
        draft.layer.borderWidth = 1
        draft.layer.borderColor = UIColor.separator.cgColor
        draft.layer.cornerRadius = 12
        copyButton.setTitle(isShare ? "Copy & Close" : "Copy", for: .normal)
        copyButton.addTarget(self, action: #selector(copyDraft), for: .touchUpInside)
        let cancel = UIButton(type: .system)
        cancel.setTitle(isShare ? "Cancel" : "Clear", for: .normal)
        cancel.addTarget(self, action: #selector(cancelDraft), for: .touchUpInside)
        let probe = UIButton(type: .system)
        probe.setTitle("Test on-device model (synthetic text)", for: .normal)
        probe.addTarget(self, action: #selector(showProbe), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [status, draft, copyButton, probe, cancel])
        stack.axis = .vertical; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -16),
            draft.heightAnchor.constraint(greaterThanOrEqualToConstant: 100)
        ])
    }
    @objc private func showProbe() {
        let probe = ModelProbeViewController()
        probe.contextName = isShare ? "Share extension" : "Main app"
        present(UINavigationController(rootViewController: probe), animated: true)
    }
    @objc func copyDraft() {
        guard let text = draft.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf16.count <= 20_000 else {
            status.text = "Choose between 1 and 20,000 characters. Nothing was copied."; return
        }
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true])
        if isShare { draft.text = ""; onClose?() }
        else { status.text = "Copied on this device. Return to your app and paste." }
    }
    @objc func cancelDraft() { draft.text = ""; onClose?() }
}
