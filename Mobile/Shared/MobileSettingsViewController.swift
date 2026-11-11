import UIKit
import InigoCore

final class MobileSettingsViewController: UITableViewController {
    var showsStyleDetails = false
    var onChange: (() -> Void)?
    private let preferences = MobilePreferences.shared
    private var profileLanguage = SupportedLanguage.resolve(override: "", preferred: Locale.preferredLanguages)
    init() { super.init(style: .insetGrouped) }
    required init?(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
        refresh()
    }
    private func refresh() {
        title = M(showsStyleDetails ? "Writing Style" : "Settings")
        view.semanticContentAttribute = preferences.language.isRTL ? .forceRightToLeft : .forceLeftToRight
        tableView.reloadData(); onChange?()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { showsStyleDetails ? 1 : 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { showsStyleDetails ? 5 : 2 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { showsStyleDetails ? nil : M(["General", "Writing Style"][section]) }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if showsStyleDetails { return M("Only style preferences are saved. You can reset them anytime.") }
        if section == 0 { return preferences.isShared ? nil : M("Shared settings are unavailable. Changes stay in this app.") }
        return M("Adapts to rewrites you copy. Turn off to pause learning.")
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: showsStyleDetails ? .subtitle : .value1, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0; cell.detailTextLabel?.numberOfLines = 0
        let state = preferences.state
        let section = showsStyleDetails ? (indexPath.row == 4 ? 2 : 1) : indexPath.section
        let row = showsStyleDetails ? indexPath.row + 1 : indexPath.row
        switch (section,row) {
        case (0,0):
            cell.textLabel?.text = M("Interface language")
            cell.detailTextLabel?.text = SupportedLanguage(rawValue: state.interfaceLanguage)?.nativeName ?? M("Follow system")
            cell.accessoryType = .disclosureIndicator
        case (0,1):
            cell.textLabel?.text = M("Translate to")
            cell.detailTextLabel?.text = SupportedLanguage(rawValue: state.translationLanguage)?.nativeName
            cell.accessoryType = .disclosureIndicator
        case (1,0):
            cell.textLabel?.text = M("Learn from rewrites I copy")
            let toggle = UISwitch(); toggle.isOn = state.learning
            toggle.accessibilityLabel = M("Learn from rewrites I copy")
            toggle.addAction(UIAction { [weak self] _ in self?.save { $0.learning = toggle.isOn } }, for: .valueChanged)
            cell.accessoryView = toggle; cell.selectionStyle = .none
        case (1,1):
            cell.textLabel?.text = M(showsStyleDetails ? "Style language" : "Learned preferences"); cell.detailTextLabel?.text = showsStyleDetails ? profileLanguage.nativeName : nil; cell.accessoryType = .disclosureIndicator
        case (1,2...4):
            let preference = StylePreference.allCases[row - 2]
            let labels: [StylePreference:String] = [.shorterSentences:"Shorter sentences", .paragraphBreaks:"Paragraph breaks", .fewerExclamations:"Fewer exclamation marks"]
            cell.textLabel?.text = M(labels[preference]!)
            let score = state.profile.evidence[profileLanguage.rawValue]?[preference.rawValue] ?? 0
            cell.detailTextLabel?.text = M(score >= 3 ? "Active" : score > 0 ? "Learning" : "Not learned")
            cell.selectionStyle = .none
        default:
            cell.textLabel?.text = M("Reset learned preferences"); cell.textLabel?.textColor = .systemRed
        }
        return cell
    }
    private func save(_ change: (inout MobilePreferenceState) -> Void) {
        do { try preferences.update(change); refresh() }
        catch { let alert = UIAlertController(title: M("Could not save settings"), message: M("Please try again. Your writing is unchanged."), preferredStyle: .alert); alert.addAction(UIAlertAction(title: M("OK"), style: .default)); present(alert, animated: true) }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if !showsStyleDetails && indexPath == IndexPath(row: 1, section: 1) {
            let detail = MobileSettingsViewController(); detail.showsStyleDetails = true; detail.onChange = onChange
            navigationController?.pushViewController(detail, animated: true)
            return
        }
        if (!showsStyleDetails && indexPath.section == 0) || (showsStyleDetails && indexPath.row == 0) {
            let picker = MobileLanguagePicker(style: .insetGrouped)
            picker.translationOnly = !showsStyleDetails && indexPath.row == 1
            picker.includeSystem = !showsStyleDetails && indexPath == IndexPath(row: 0, section: 0)
            picker.choose = { [weak self] value in
                guard let self else { return }
                if self.showsStyleDetails { self.profileLanguage = SupportedLanguage(rawValue: value) ?? .en; self.refresh() }
                else { self.save { if indexPath.row == 0 { $0.interfaceLanguage = value } else { $0.translationLanguage = value } } }
            }
            navigationController?.pushViewController(picker, animated: true)
        } else if showsStyleDetails && indexPath.row == 4 {
            let alert = UIAlertController(title: M("Reset learned preferences"), message: M("This removes learned writing preferences for every language. Your other settings stay the same."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: M("Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: M("Reset"), style: .destructive) { [weak self] _ in self?.save { $0.profile = StyleProfile() } })
            present(alert, animated: true)
        }
    }
}
final class MobileLanguagePicker: UITableViewController {
    var loadTranslationLanguages: () async -> [SupportedLanguage] = { await MobileTranslationService.supportedTargets() }
    var translationOnly = false
    private var translationLanguages: [SupportedLanguage] = []
    var selected: String?
    var includeSystem = false
    var choose: ((String) -> Void)?
    private var values: [String] { (includeSystem ? ["system"] : []) + (translationOnly ? translationLanguages : SupportedLanguage.allCases).map(\.rawValue) }
    override func viewDidLoad() {
        super.viewDidLoad(); title = M("Choose language")
        if translationOnly {
            let progress = UIActivityIndicatorView(style: .medium); progress.startAnimating(); tableView.backgroundView = progress
            Task { [weak self] in
                let languages = await self?.loadTranslationLanguages() ?? []
                guard let self else { return }
                self.translationLanguages = languages; self.tableView.backgroundView = nil; self.tableView.reloadData()
            }
        }
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { values.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(); cell.accessoryType = values[indexPath.row] == selected ? .checkmark : .none; cell.textLabel?.text = SupportedLanguage(rawValue: values[indexPath.row])?.nativeName ?? M("Follow system"); return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { guard values.indices.contains(indexPath.row) else { return }; choose?(values[indexPath.row]); if (navigationController?.viewControllers.count ?? 0) > 1 { navigationController?.popViewController(animated: true) } }
}
