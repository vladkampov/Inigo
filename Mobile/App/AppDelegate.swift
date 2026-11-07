import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: PasteViewController())
        window.makeKeyAndVisible(); self.window = window
        return true
    }
}

final class PasteViewController: DraftViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Paste", style: .plain, target: self, action: #selector(pasteDraft))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Model probe", style: .plain, target: self, action: #selector(probe))
    }
    @objc private func pasteDraft() {
        // Explicit user action only. No clipboard polling or automatic reads.
        guard let text = UIPasteboard.general.string, text.utf16.count <= 20_000 else {
            status.text = "Copy a text selection of up to 20,000 characters, then tap Paste."; return
        }
        draft.text = text
    }
    @objc private func probe() {
        let probe = ModelProbeViewController()
        navigationController?.pushViewController(probe, animated: true)
    }
}
