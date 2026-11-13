import AppKit
import Carbon
import Combine
import InigoCore

@MainActor
final class InputSourceCatalog: ObservableObject {
    struct Source: Identifiable {
        let id: String
        let name: String
        let language: String?
        let source: TISInputSource
        let keys: [UInt32: Character]
        var supported: Bool { language != nil && !keys.isEmpty }
    }
    @Published private(set) var sources: [Source] = []
    var onChange: (() -> Void)?
    private var observers: [NSObjectProtocol] = []
    init() {
        refresh()
        for name in [kTISNotifySelectedKeyboardInputSourceChanged!, kTISNotifyEnabledKeyboardInputSourcesChanged!] {
            observers.append(DistributedNotificationCenter.default().addObserver(forName: Notification.Name(name as String), object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh(); self?.onChange?() }
            })
        }
    }
    deinit { for observer in observers { DistributedNotificationCenter.default().removeObserver(observer) } }
    private func property<T>(_ source: TISInputSource, _ key: CFString) -> T? {
        guard let pointer = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(pointer).takeUnretainedValue() as? T
    }
    var selectedID: String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return property(source, kTISPropertyInputSourceID)
    }
    func select(_ id: String) -> Bool {
        guard let source = sources.first(where: { $0.id == id }), source.supported else { return false }
        return TISSelectInputSource(source.source) == noErr && selectedID == id
    }
    func refresh() {
        let languages = NSSpellChecker.shared.availableLanguages
        let list = TISCreateInputSourceList([kTISPropertyInputSourceIsEnabled!: true, kTISPropertyInputSourceIsSelectCapable!: true] as CFDictionary, false).takeRetainedValue() as! [TISInputSource]
        sources = list.compactMap { source in
            guard let id: String = property(source, kTISPropertyInputSourceID),
                  let type: String = property(source, kTISPropertyInputSourceType),
                  type == kTISTypeKeyboardLayout as String || type == kTISTypeKeyboardInputMode as String else { return nil }
            let intended: [String] = property(source, kTISPropertyInputSourceLanguages) ?? []
            let primary = intended.first ?? ""
            let language = languages.first(where: { $0 == primary }) ?? languages.first(where: { $0.split(whereSeparator: { $0 == "_" || $0 == "-" }).first == primary.split(separator: "-").first })
            return Source(id: id, name: property(source, kTISPropertyLocalizedName) ?? id, language: language, source: source, keys: keyMap(source))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    private func keyMap(_ source: TISInputSource) -> [UInt32: Character] {
        guard let data: Data = property(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
        return data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return [:] }
            let layout = base.assumingMemoryBound(to: UCKeyboardLayout.self)
            var keys: [UInt32: Character] = [:]
            for shift in [UInt32(0), UInt32(shiftKey >> 8)] {
                for key in UInt16(0)..<128 {
                    var dead: UInt32 = 0, length = 0
                    var characters = [UniChar](repeating: 0, count: 8)
                    let status = UCKeyTranslate(layout, key, UInt16(kUCKeyActionDown), shift, UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask), &dead, 8, &length, &characters)
                    guard status == noErr, dead == 0, length == 1,
                          let scalar = UnicodeScalar(characters[0]), !CharacterSet.controlCharacters.contains(scalar) else { continue }
                    keys[UInt32(key) | (shift << 16)] = Character(String(scalar))
                }
            }
            return keys
        }
    }
    func mapping(from source: Source, to target: Source) -> [Character: Character] {
        var possibilities: [Character: Set<Character>] = [:]
        for (key, character) in source.keys {
            if let converted = target.keys[key] { possibilities[character, default: []].insert(converted) }
        }
        let unique = possibilities.compactMapValues { $0.count == 1 ? $0.first : nil }
        let inverse = Dictionary(grouping: unique.keys, by: { unique[$0]! })
        return unique.filter { inverse[$0.value]?.count == 1 }
    }
}

@MainActor
protocol LayoutRecognizing {
    func recognition(_ text: String, language: String) async -> Double?
}

struct LayoutDetectionTarget {
    let id: String
    let language: String
    let mapping: [Character: Character]
}

@MainActor
enum LayoutRepairDetector {
    static func detect(_ draft: String, caret: Int, language: String, targets: [LayoutDetectionTarget],
                       recognizer: LayoutRecognizing, isCurrent: () -> Bool) async -> LayoutRepairCandidate? {
        guard isCurrent(), !Task.isCancelled,
              let original = await recognizer.recognition(draft, language: language), original <= 0.2 else { return nil }
        var candidates: [LayoutRepairCandidate] = []
        for target in targets {
            guard isCurrent(), !Task.isCancelled else { return nil }
            guard let conversion = LayoutConversion(draft, caret: caret, mapping: target.mapping) else { continue }
            guard let score = await recognizer.recognition(conversion.text, language: target.language) else { return nil }
            candidates.append(LayoutRepairCandidate(sourceID: target.id, conversion: conversion, recognition: score))
        }
        guard isCurrent(), !Task.isCancelled else { return nil }
        return LayoutRepairPolicy.winner(original: draft, recognition: original, candidates: candidates)
    }
}

@MainActor
final class SystemLayoutRecognizer: LayoutRecognizing {
    private final class Reply {
        var continuation: CheckedContinuation<[NSTextCheckingResult]?, Never>?
        func finish(_ results: [NSTextCheckingResult]?) { continuation?.resume(returning: results); continuation = nil }
    }
    func recognition(_ text: String, language: String) async -> Double? {
        guard !Task.isCancelled else { return nil }
        let words = LayoutConversion.proseWords(text)
        let letters = words.joined().lowercased().filter { $0.unicodeScalars.allSatisfy { CharacterSet.letters.contains($0) } }
        guard !letters.isEmpty else { return nil }
        // An unavailable service can report no spelling errors, indistinguishable from
        // perfect prose. Require it to reject a synthetic nonword in the same alphabet.
        let probe = String(String(repeating: String(letters.reversed()), count: 16).prefix(17))
        let prose = probe + " " + words.joined(separator: " "), ns = prose as NSString
        let tag = NSSpellChecker.uniqueSpellDocumentTag(), checker = NSSpellChecker.shared
        defer { checker.closeSpellDocument(withTag: tag) }
        let results: [NSTextCheckingResult]? = await withCheckedContinuation { continuation in
            let reply = Reply(); reply.continuation = continuation
            let timeout = Task { @MainActor in
                do { try await Task.sleep(for: .seconds(2)) } catch { return }; reply.finish(nil)
            }
            checker.requestChecking(of: prose, range: NSRange(location: 0, length: ns.length), types: NSTextCheckingResult.CheckingType.spelling.rawValue,
                options: [.orthography: NSOrthography.defaultOrthography(forLanguage: language)], inSpellDocumentWithTag: tag) { _, results, _, _ in
                Task { @MainActor in timeout.cancel(); reply.finish(results) }
            }
        }
        guard !Task.isCancelled, let results else { return nil }
        let misspelled = results.filter { $0.resultType == .spelling }.map(\.range)
        guard misspelled.contains(where: { NSIntersectionRange($0, NSRange(location: 0, length: probe.utf16.count)).length > 0 }) else { return nil }
        var offset = probe.utf16.count + 1, total = 0, recognized = 0
        for word in words {
            let range = NSRange(location: offset, length: word.utf16.count)
            let letters = word.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            total += letters
            if !misspelled.contains(where: { NSIntersectionRange($0, range).length > 0 }) { recognized += letters }
            offset += range.length + 1
        }
        return total > 0 ? Double(recognized) / Double(total) : nil
    }
}
