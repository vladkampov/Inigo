import XCTest
import CryptoKit
@testable import Inigo

final class VerifiedModelDownloadTests: XCTestCase {
    private func fixture(_ body: (URL, URL, URL, Data, String) throws -> Void) throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("source")
        let target = folder.appendingPathComponent("model")
        let bytes = Data("verified model fixture".utf8)
        try bytes.write(to: source)
        let digest = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
        try body(folder, source, target, bytes, digest)
    }
    @MainActor func testVerifiedRetryReplacesDamagedExistingFile() throws {
        try fixture { folder, source, target, bytes, digest in
            try Data("damaged".utf8).write(to: target)
            let download = try VerifiedModelDownload(source: source, destination: target, expectedBytes: Int64(bytes.count), sha256: digest)
            try download.install(ifCurrent: true)
            XCTAssertEqual(try Data(contentsOf: target), bytes)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["model"])
        }
    }
    @MainActor func testCancelledOrSupersededDownloadCannotReplaceModel() throws {
        try fixture { folder, source, target, bytes, digest in
            let original = Data("existing model".utf8)
            try original.write(to: target)
            var download: VerifiedModelDownload? = try VerifiedModelDownload(source: source, destination: target, expectedBytes: Int64(bytes.count), sha256: digest)
            try download?.install(ifCurrent: false)
            download = nil
            XCTAssertEqual(try Data(contentsOf: target), original)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["model"])
        }
    }
    func testCorruptOrTruncatedDownloadPreservesExistingModel() throws {
        for truncated in [false, true] {
            try fixture { _, source, target, bytes, digest in
                let original = Data("existing model".utf8)
                try original.write(to: target)
                XCTAssertThrowsError(try VerifiedModelDownload(source: source, destination: target, expectedBytes: Int64(bytes.count + (truncated ? 1 : 0)), sha256: truncated ? digest : String(repeating: "0", count: 64)))
                XCTAssertEqual(try Data(contentsOf: target), original)
            }
        }
    }
    @MainActor func testFailedInstallPreservesDestinationAndCleansStage() throws {
        try fixture { folder, source, target, bytes, digest in
            try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
            let sentinel = target.appendingPathComponent("keep")
            try Data("original".utf8).write(to: sentinel)
            var download: VerifiedModelDownload? = try VerifiedModelDownload(source: source, destination: target, expectedBytes: Int64(bytes.count), sha256: digest)
            XCTAssertThrowsError(try download?.install(ifCurrent: true))
            download = nil
            XCTAssertEqual(try Data(contentsOf: sentinel), Data("original".utf8))
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["model"])
        }
    }
    func testAbandonedVerifiedDownloadLeavesNoStagedFile() throws {
        try fixture { folder, source, target, bytes, digest in
            var download: VerifiedModelDownload? = try VerifiedModelDownload(source: source, destination: target, expectedBytes: Int64(bytes.count), sha256: digest)
            XCTAssertNotNil(download)
            download = nil
            XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
            XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
        }
    }

}
