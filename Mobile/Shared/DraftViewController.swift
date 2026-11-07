import UIKit
import UniformTypeIdentifiers
import InigoCore
import NaturalLanguage

class DraftViewController: UIViewController, UITextViewDelegate {
    let draft = UITextView()
    let status = UILabel()
    let copyButton = UIButton(type: .system)
    var onClose: (() -> Void)?
    var isShare = false
    private let refineButton = UIButton(type: .system)
    private let translateButton = UIButton(type: .system)
    private let undoButton = UIButton(type: .system)
    private let cancelOperation = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var operation: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var revision = UUID()
    private var originalText = ""
    private var undoPair: (before: String, after: String)?
    private var busy = false
    private var localizationBindings: [() -> Void] = []
    private var currentStatusKey = "Paste or share a selection to get started."
    private var learningCandidate: (original: String, language: String)?
    var rewrite: (String, RewriteAction) async throws -> String = { try await MobileRewriteEngine().rewrite($0, action: $1) }
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
        let settings = UIButton(type: .system)
        settings.setImage(UIImage(systemName: "gearshape"), for: .normal)
        settings.widthAnchor.constraint(equalToConstant: 44).isActive = true
        settings.heightAnchor.constraint(equalToConstant: 44).isActive = true
        settings.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        let header = UIStackView(arrangedSubviews: [mark, names, settings, close]); header.alignment = .center; header.spacing = 12
        showStatus("Paste or share a selection to get started.")
        status.numberOfLines = 0; status.font = .preferredFont(forTextStyle: .subheadline)
        status.textColor = .secondaryLabel; status.adjustsFontForContentSizeCategory = true
        draft.font = .preferredFont(forTextStyle: .body); draft.adjustsFontForContentSizeCategory = true
        draft.accessibilityLabel = "Your text"
        draft.delegate = self
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
        refineButton.setTitle("Refine", for: .normal)
        refineButton.setImage(UIImage(systemName: "sparkles"), for: .normal)
        refineButton.addTarget(self, action: #selector(refine), for: .touchUpInside)
        updateTranslationMenu()
        let compare = UIButton(type: .system); compare.setTitle("Original", for: .normal)
        compare.addTarget(self, action: #selector(showOriginal), for: .touchUpInside)
        undoButton.setTitle("Undo", for: .normal); undoButton.isEnabled = false
        undoButton.addTarget(self, action: #selector(undoRewrite), for: .touchUpInside)
        let actions = UIStackView(arrangedSubviews: [refineButton, translateButton, compare, undoButton])
        actions.distribution = .equalSpacing; actions.spacing = 8
        cancelOperation.setTitle("Cancel", for: .normal); cancelOperation.isHidden = true
        cancelOperation.addTarget(self, action: #selector(cancelRewrite), for: .touchUpInside)
        let activity = UIStackView(arrangedSubviews: [spinner, status, cancelOperation]); activity.spacing = 8
        let stack = UIStackView(arrangedSubviews: [header, activity, draft, actions, copyButton, note])
        stack.axis = .vertical; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        let height = draft.heightAnchor.constraint(greaterThanOrEqualToConstant: 120); height.priority = .defaultHigh
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -12), height
        ])
        localizationBindings = [{ [weak self] in
            guard let self else { return }
            subtitle.text = M("A little clarity, wherever you write.")
            close.accessibilityLabel = M(self.isShare ? "Cancel" : "Clear draft")
            settings.accessibilityLabel = M("Settings")
            self.draft.accessibilityLabel = M("Your text")
            var config = self.copyButton.configuration
            config?.title = M(self.isShare ? "Copy & Close" : "Copy text")
            self.copyButton.configuration = config
            note.text = M("Copied only when you choose. Nothing is sent.")
            self.refineButton.setTitle(M("Refine"), for: .normal)
            compare.setTitle(M("Original"), for: .normal)
            self.undoButton.setTitle(M("Undo"), for: .normal)
            self.cancelOperation.setTitle(M("Cancel"), for: .normal)
        }]
        refreshLocalization()
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated); refreshLocalization()
    }
    func showStatus(_ key: String) { currentStatusKey = key; status.text = M(key) }
    private func refreshLocalization() {
        localizationBindings.forEach { $0() }
        view.semanticContentAttribute = MobilePreferences.shared.language.isRTL ? .forceRightToLeft : .forceLeftToRight
        draft.semanticContentAttribute = .unspecified
        draft.textAlignment = .natural
        status.text = M(currentStatusKey); updateTranslationMenu()
    }
    @objc private func showSettings() {
        let settings = MobileSettingsViewController()
        settings.onChange = { [weak self] in self?.refreshLocalization() }
        present(UINavigationController(rootViewController: settings), animated: true)
    }
    func receive(_ text: String) {
        stopOperation(); originalText = text; draft.text = text; undoPair = nil
        begin(.refine)
    }
    private func updateTranslationMenu() {
        let saved = MobilePreferences.shared.state.translationLanguage
        let target = SupportedLanguage(rawValue: saved) ?? .en
        translateButton.setTitle(M("Translate") + " ▾", for: .normal)
        let recent = UIAction(title: MF("Translate to %@", target.nativeName)) { [weak self] _ in self?.begin(.translate(target)) }
        let languages = SupportedLanguage.allCases.map { language in
            UIAction(title: language.nativeName, state: language == target ? .on : .off) { [weak self] _ in
                try? MobilePreferences.shared.update { $0.translationLanguage = language.rawValue }
                self?.updateTranslationMenu(); self?.begin(.translate(language))
            }
        }
        translateButton.menu = UIMenu(children: [recent, UIMenu(title: M("Choose language"), children: languages)])
        translateButton.showsMenuAsPrimaryAction = true
    }
    @objc private func refine() { begin(.refine) }
    private func begin(_ action: RewriteAction) {
        guard let source = draft.text, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, source.utf16.count <= 20_000 else {
            showStatus("Choose between 1 and 20,000 characters."); return
        }
        if originalText.isEmpty { originalText = source }
        learningCandidate = nil
        let previous = operation
        stopOperation()
        let current = revision
        setBusy(true)
        showStatus(action == .refine ? "Refining on your iPhone…" : "Translating on your iPhone…")
        let handler = rewrite
        operation = Task { [weak self] in
            // Do not overlap model sessions if cancellation is still draining.
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let output = try await handler(source, action)
                guard let self, !Task.isCancelled, self.revision == current, self.draft.text == source else { return }
                self.undoPair = output == source ? nil : (source, output)
                self.draft.text = output
                if action == .refine, output != source {
                    self.learningCandidate = (source, NLLanguageRecognizer.dominantLanguage(for: source)?.rawValue ?? "und")
                }
                self.showStatus(output == source ? "Already clear. No changes needed." : action == .refine ? "Refined. Make it yours before copying." : "Translated. Review before copying.")
                self.finishOperation()
            } catch {
                guard let self, !Task.isCancelled, self.revision == current else { return }
                self.showStatus(error.localizedDescription)
                self.finishOperation()
            }
        }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(45))
            guard !Task.isCancelled, let self, self.revision == current else { return }
            self.stopOperation(); self.showStatus("This is taking too long. Your text is unchanged. Tap Refine or Translate to retry.")
        }
    }
    private func setBusy(_ value: Bool) {
        busy = value
        value ? spinner.startAnimating() : spinner.stopAnimating()
        cancelOperation.isHidden = !value
        refineButton.isEnabled = !value; translateButton.isEnabled = !value
        copyButton.isEnabled = !value && !(draft.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        undoButton.isEnabled = !value && undoPair?.after == draft.text
    }
    private func finishOperation() { timeout?.cancel(); timeout = nil; operation = nil; setBusy(false) }
    private func stopOperation() { revision = UUID(); operation?.cancel(); timeout?.cancel(); timeout = nil; setBusy(false) }
    @objc private func cancelRewrite() { stopOperation(); showStatus("Cancelled. Your text is unchanged.") }
    func textViewDidChange(_ textView: UITextView) {
        let wasBusy = busy; stopOperation()
        if wasBusy { showStatus("Paused while you edit. Tap Refine when ready.") }
    }
    @objc func undoRewrite() {
        guard let pair = undoPair, draft.text == pair.after else { return }
        stopOperation(); draft.text = pair.before; undoPair = nil; learningCandidate = nil; setBusy(false); showStatus("Original wording restored.")
    }
    @objc private func showOriginal() {
        let controller = UIViewController(); controller.title = M("Original")
        let text = UITextView(); text.text = originalText; text.isEditable = false
        text.font = .preferredFont(forTextStyle: .body); text.adjustsFontForContentSizeCategory = true
        text.backgroundColor = .systemBackground; controller.view = text
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak controller] _ in controller?.dismiss(animated: true) })
        present(UINavigationController(rootViewController: controller), animated: true)
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true { stopOperation() }
    }
    deinit { operation?.cancel(); timeout?.cancel() }
    @objc func copyDraft() {
        guard !busy else { return }
        guard let text = draft.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 20_000 else {
            showStatus("Choose between 1 and 20,000 characters. Nothing was copied."); return
        }
        if let candidate = learningCandidate {
            try? MobilePreferences.shared.observeCopy(original: candidate.original, result: text, language: candidate.language)
            learningCandidate = nil
        }
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: [.localOnly: true])
        if isShare { draft.text = ""; onClose?() }
        else { showStatus("Copied on this device. Return to your app and paste.") }
    }
    @objc func cancelDraft() { stopOperation(); draft.text = ""; originalText = ""; undoPair = nil; learningCandidate = nil; setBusy(false); onClose?() }
}
private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
