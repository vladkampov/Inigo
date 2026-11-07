import UIKit
import InigoCore

final class MobileSettingsViewController: UITableViewController {
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
        title = M("Settings")
        view.semanticContentAttribute = preferences.language.isRTL ? .forceRightToLeft : .forceLeftToRight
        tableView.reloadData(); onChange?()
    }
    override func numberOfSections(in tableView: UITableView) -> Int { 3 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 2 : section == 1 ? 5 : 1 }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { M(["General", "Writing Style", "Privacy"][section]) }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 0 { return M(preferences.isShared ? "Settings are shared with the Inigo Share extension on this iPhone." : "Shared settings are unavailable. Changes stay in this app.") }
        if section == 1 { return M("Learns from repeated patterns in rewrites you copy. Only writing preferences are saved, separately by language. No drafts or conversation facts are stored.") }
        return M("Writing stays on your iPhone. Copying is local-only. No accounts, analytics or cloud fallback.")
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.numberOfLines = 0; cell.detailTextLabel?.numberOfLines = 0
        let state = preferences.state
        switch (indexPath.section,indexPath.row) {
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
            cell.textLabel?.text = M("Style language"); cell.detailTextLabel?.text = profileLanguage.nativeName; cell.accessoryType = .disclosureIndicator
        case (1,2...4):
            let preference = StylePreference.allCases[indexPath.row - 2]
            let labels: [StylePreference:String] = [.shorterSentences:"Shorter sentences", .paragraphBreaks:"Paragraph breaks", .fewerExclamations:"Fewer exclamation marks"]
            cell.textLabel?.text = M(labels[preference]!)
            let score = state.profile.evidence[profileLanguage.rawValue]?[preference.rawValue] ?? 0
            cell.detailTextLabel?.text = M(score >= 3 ? "Active" : score > 0 ? "Learning" : "No preferences learned yet.")
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
        if indexPath.section == 0 || indexPath == IndexPath(row: 1, section: 1) {
            let picker = MobileLanguagePicker(style: .insetGrouped)
            picker.includeSystem = indexPath == IndexPath(row: 0, section: 0)
            picker.choose = { [weak self] value in
                guard let self else { return }
                if indexPath.section == 1 { self.profileLanguage = SupportedLanguage(rawValue: value) ?? .en; self.refresh() }
                else { self.save { if indexPath.row == 0 { $0.interfaceLanguage = value } else { $0.translationLanguage = value } } }
            }
            navigationController?.pushViewController(picker, animated: true)
        } else if indexPath.section == 2 {
            let alert = UIAlertController(title: M("Reset learned preferences"), message: M("This removes learned writing preferences for every language. Your other settings stay the same."), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: M("Cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: M("Reset"), style: .destructive) { [weak self] _ in self?.save { $0.profile = StyleProfile() } })
            present(alert, animated: true)
        }
    }
}
private final class MobileLanguagePicker: UITableViewController {
    var includeSystem = false
    var choose: ((String) -> Void)?
    private var values: [String] { (includeSystem ? ["system"] : []) + SupportedLanguage.allCases.map(\.rawValue) }
    override func viewDidLoad() { super.viewDidLoad(); title = M("Choose language") }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { values.count }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(); cell.textLabel?.text = SupportedLanguage(rawValue: values[indexPath.row])?.nativeName ?? M("Follow system"); return cell
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) { choose?(values[indexPath.row]); navigationController?.popViewController(animated: true) }
}
