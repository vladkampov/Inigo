import UIKit
import UniformTypeIdentifiers
import InigoCore

class DraftViewController: UIViewController {
    let draft = UITextView()
    let status = UILabel()
    let copyButton = UIButton(type: .system)
    var onClose: (() -> Void)?
    var isShare = false
    private let accent = UIColor { traits in
        traits.userInterfaceStyle == .dark ? UIColor(red: 0.76, green: 0.73, blue: 1, alpha: 1) : UIColor(red: 0.36, green: 0.29, blue: 0.66, alpha: 1)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inigo"
        view.backgroundColor = .systemGroupedBackground
        view.tintColor = accent
        preferredContentSize = CGSize(width: 420, height: 620)
        let mark = UIImageView(image: UIImage(named: "InigoMark"))
        mark.contentMode = .scaleAspectFit; mark.layer.cornerRadius = 13; mark.clipsToBounds = true
        mark.widthAnchor.constraint(equalToConstant: 48).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 48).isActive = true
        mark.isAccessibilityElement = false
        let name = UILabel(); name.text = "Inigo"; name.font = .preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        name.adjustsFontForContentSizeCategory = true
        let subtitle = UILabel(); subtitle.text = "A little clarity, wherever you write."; subtitle.font = .preferredFont(forTextStyle: .subheadline); subtitle.textColor = .secondaryLabel; subtitle.numberOfLines = 0
        let names = UIStackView(arrangedSubviews: [name, subtitle]); names.axis = .vertical; names.spacing = 3
        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        close.tintColor = .tertiaryLabel; close.accessibilityLabel = isShare ? "Cancel" : "Clear draft"
        close.widthAnchor.constraint(equalToConstant: 44).isActive = true
        close.heightAnchor.constraint(equalToConstant: 44).isActive = true
        close.addTarget(self, action: #selector(cancelDraft), for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [mark, names, close]); header.alignment = .center; header.spacing = 12
        status.text = "Paste or share a selection to get started."
        status.numberOfLines = 0; status.font = .preferredFont(forTextStyle: .subheadline)
        status.textColor = .secondaryLabel; status.adjustsFontForContentSizeCategory = true
        draft.font = .preferredFont(forTextStyle: .body); draft.adjustsFontForContentSizeCategory = true
        draft.accessibilityLabel = "Your text"
        draft.backgroundColor = .secondarySystemGroupedBackground
        draft.layer.cornerRadius = 20; draft.layer.cornerCurve = .continuous
        draft.textContainerInset = UIEdgeInsets(top: 18, left: 14, bottom: 18, right: 14)
        draft.alwaysBounceVertical = true
        var primary = UIButton.Configuration.filled()
        primary.title = isShare ? "Copy & Close" : "Copy text"
        primary.image = UIImage(systemName: "doc.on.doc"); primary.imagePadding = 9
        primary.baseBackgroundColor = accent; primary.baseForegroundColor = .systemBackground
        primary.cornerStyle = .large
        primary.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
        copyButton.configuration = primary
        copyButton.addTarget(self, action: #selector(copyDraft), for: .touchUpInside)
        let note = UILabel(); note.text = "Copied only when you choose. Nothing is sent."
        note.font = .preferredFont(forTextStyle: .caption1); note.textColor = .secondaryLabel; note.textAlignment = .center; note.numberOfLines = 0
        let prototype = UILabel(); prototype.text = "Preview · Text transfer only. Automatic refinement is coming next."
        prototype.font = .preferredFont(forTextStyle: .caption1); prototype.textColor = .secondaryLabel; prototype.numberOfLines = 0
        let probe = UIButton(type: .system)
        probe.setTitle("Try the on-device model", for: .normal)
        probe.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        probe.addTarget(self, action: #selector(showProbe), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [header, status, draft, copyButton, note, prototype, probe])
        stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let height = draft.heightAnchor.constraint(greaterThanOrEqualToConstant: 120); height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12), height
        ])
    }
    @objc private func showProbe() {
        let probe = ModelProbeViewController(); probe.contextName = isShare ? "Share extension" : "Main app"
        present(UINavigationController(rootViewController: probe), animated: true)
    }
    @objc func copyDraft() {
        guard let text = draft.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 20_000 else {
            status.text = "Choose between 1 and 20,000 characters. Nothing was copied."; return
        }
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true])
        if isShare { draft.text = ""; onClose?() }
        else { status.text = "Copied on this device. Return to your app and paste." }
    }
    @objc func cancelDraft() { draft.text = ""; onClose?() }
}
private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
