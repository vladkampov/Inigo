import UIKit

final class ModelProbeViewController: UIViewController {
    private let result = UITextView()
    private var task: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad(); title = "On-device feasibility probe"
        result.isEditable = false; result.font = .preferredFont(forTextStyle: .body)
        view = result
        result.text = "Runs a synthetic English draft only. This does not establish extension viability or multilingual quality. No writing is uploaded."
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Run", style: .plain, target: self, action: #selector(run))
    }
    @objc private func run() {
        task?.cancel()
        task = Task { [weak self] in
            self?.result.text = "Testing local model…"
            do {
                let (text, seconds) = try await ModelProbe().run()
                guard !Task.isCancelled else { return }
                self?.result.text = String(format: "%.2f seconds\n\n", seconds) + text
            } catch {
                guard !Task.isCancelled else { return }
                self?.result.text = error.localizedDescription
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); task?.cancel() }
    deinit { task?.cancel() }
}
