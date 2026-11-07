import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Inigo", sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = UINavigationController(rootViewController: PasteViewController())
        window.makeKeyAndVisible(); self.window = window
    }
}

final class PasteViewController: DraftViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Paste", style: .plain, target: self, action: #selector(pasteDraft))
    }
    @objc private func pasteDraft() {
        // Explicit user action only. No clipboard polling or automatic reads.
        guard let text = UIPasteboard.general.string, text.utf16.count <= 20_000 else {
            status.text = "Copy a text selection of up to 20,000 characters, then tap Paste."; return
        }
        receive(text)
    }
}
