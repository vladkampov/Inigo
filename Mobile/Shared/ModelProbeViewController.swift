import UIKit

final class ModelProbeViewController: UIViewController {
    var contextName = "Main app"
    private var runCount = 0
    private let result = UITextView()
    private var task: Task<Void, Never>?
    override func viewDidLoad() {
        super.viewDidLoad(); title = "On-device feasibility probe"
        result.isEditable = false; result.font = .preferredFont(forTextStyle: .body)
        view = result
        result.text = "Runs a synthetic English draft only. Record the first and repeated run times. This does not establish multilingual quality. No writing is uploaded."
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Run", style: .plain, target: self, action: #selector(run))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(done))
    }
    @objc private func run() {
        if task != nil {
            task?.cancel(); task = nil
            navigationItem.rightBarButtonItem?.title = "Run"
            result.text = "Cancelled. Your draft and clipboard are unchanged."
            return
        }
        navigationItem.rightBarButtonItem?.title = "Cancel"
        runCount += 1
        task = Task { [weak self] in
            self?.result.text = "Testing local model…"
            do {
                let (text, seconds) = try await ModelProbe().run()
                guard !Task.isCancelled else { return }
                self?.result.text = "\(self?.contextName ?? "Probe") · run \(self?.runCount ?? 0)\n" + String(format: "%.2f seconds\n\n", seconds) + text
            } catch {
                guard !Task.isCancelled else { return }
                self?.result.text = error.localizedDescription
            }
            self?.task = nil
            self?.navigationItem.rightBarButtonItem?.title = "Run"
        }
    }
    @objc private func done() { task?.cancel(); dismiss(animated: true) }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); task?.cancel() }
    deinit { task?.cancel() }
}
