import AppKit
import Combine
import Sparkle

@MainActor
final class UpdateManager: NSObject, ObservableObject {
    @Published private(set) var canCheck = false
    @Published var automaticChecks = true {
        didSet { if configured { controller.updater.automaticallyChecksForUpdates = automaticChecks } }
    }
    let configured: Bool
    private var observation: AnyCancellable?
    private lazy var controller = SPUStandardUpdaterController(startingUpdater:false,updaterDelegate:nil,userDriverDelegate:nil)
    var version: String { Bundle.main.object(forInfoDictionaryKey:"InigoDisplayVersion") as? String ?? "Development" }
    override init() {
        let feed = Bundle.main.object(forInfoDictionaryKey:"SUFeedURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey:"SUPublicEDKey") as? String ?? ""
        configured = URL(string:feed)?.scheme == "https" && Data(base64Encoded:key)?.count == 32
        super.init()
    }
    func start() {
        guard configured else { return }
        controller.startUpdater()
        automaticChecks = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.publisher(for:\.canCheckForUpdates)
            .receive(on:DispatchQueue.main).sink { [weak self] in self?.canCheck = $0 }
    }
    func check() {
        guard configured else { return }
        controller.checkForUpdates(nil)
    }
}
