import Foundation
import CryptoKit
import Darwin
import InigoCore

/// Verifies away from the main actor, then stages on the destination filesystem.
/// Only the current download may commit. Abandoned stages are always removed.
final class VerifiedModelDownload {
    private let staged: URL
    private let destination: URL

    init(source: URL, destination: URL, expectedBytes: Int64, sha256: String) throws {
        self.destination = destination
        let size = try source.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard size == Int(expectedBytes) else { throw InigoError.message("Model integrity check failed. Please retry the download.") }
        let handle = try FileHandle(forReadingFrom: source)
        defer { try? handle.close() }
        var hash = SHA256()
        while let bytes = try handle.read(upToCount: 4 * 1024 * 1024), !bytes.isEmpty { hash.update(data: bytes) }
        guard hash.finalize().map({ String(format: "%02x", $0) }).joined() == sha256 else {
            throw InigoError.message("Model integrity check failed. Please retry the download.")
        }
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        staged = folder.appendingPathComponent(".download-\(UUID().uuidString)")
        try FileManager.default.moveItem(at: source, to: staged)
    }

    deinit { try? FileManager.default.removeItem(at: staged) }

    @MainActor
    func install(ifCurrent: Bool) throws {
        guard ifCurrent else { return }
        // Same-filesystem rename atomically replaces an old or damaged download.
        guard rename(staged.path, destination.path) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
    }
}
