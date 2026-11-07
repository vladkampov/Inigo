import Foundation
import Darwin
import InigoCore

struct MobilePreferenceState: Codable {
    var interfaceLanguage = "system"
    var translationLanguage = "en"
    var learning = true
    var profile = StyleProfile()
    mutating func sanitize() {
        if SupportedLanguage(rawValue: interfaceLanguage) == nil { interfaceLanguage = "system" }
        if SupportedLanguage(rawValue: translationLanguage) == nil { translationLanguage = "en" }
        profile.evidence = profile.evidence.filter { SupportedLanguage(rawValue: $0.key) != nil }.mapValues { scores in
            scores.filter { StylePreference(rawValue: $0.key) != nil }.mapValues { min(20, max(0, $0)) }
        }
    }
}

/// App and extension read fresh state under the same cross-process file lock.
/// Only closed-vocabulary preferences and counters are serialized, never writing.
final class MobilePreferences {
    static let group = "group.app.inigo.mobile"
    static let shared: MobilePreferences = {
        let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)
        let fallback = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let store = MobilePreferences(directory: (container ?? fallback).appendingPathComponent("Preferences"), isShared: container != nil)
        try? store.initializeLegacySettings()
        return store
    }()
    let directory: URL
    let isShared: Bool
    init(directory: URL, isShared: Bool = true) { self.directory = directory; self.isShared = isShared }
    var state: MobilePreferenceState { (try? read()) ?? MobilePreferenceState() }
    var language: SupportedLanguage { SupportedLanguage.resolve(override: state.interfaceLanguage, preferred: Locale.preferredLanguages) }
    private func locked<T>(_ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.appendingPathComponent("settings.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { close(fd) }
        guard flock(fd, LOCK_EX) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { flock(fd, LOCK_UN) }
        return try body()
    }
    private var file: URL { directory.appendingPathComponent("settings.json") }
    private func readUnlocked() throws -> MobilePreferenceState {
        guard FileManager.default.fileExists(atPath: file.path) else { return MobilePreferenceState() }
        var state = try JSONDecoder().decode(MobilePreferenceState.self, from: Data(contentsOf: file))
        state.sanitize(); return state
    }
    func read() throws -> MobilePreferenceState { try locked { try readUnlocked() } }
    func update(_ change: (inout MobilePreferenceState) -> Void) throws {
        try locked {
            var state = try readUnlocked(); change(&state); state.sanitize()
            try JSONEncoder().encode(state).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
    private func initializeLegacySettings() throws {
        try locked {
            guard !FileManager.default.fileExists(atPath: file.path) else { return }
            var state = MobilePreferenceState()
            state.interfaceLanguage = UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "system"
            state.translationLanguage = UserDefaults.standard.string(forKey: "translationTarget") ?? "en"
            state.sanitize()
            try JSONEncoder().encode(state).write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        }
    }
    func observeCopy(original: String, result: String, language: String) throws {
        try update { state in
            guard state.learning else { return }
            state.profile.observe(original: original, revision: result, language: language, weight: 1)
        }
    }
    func resetStyle() throws { try update { $0.profile = StyleProfile() } }
}
