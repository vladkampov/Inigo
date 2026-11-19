import XCTest
import UniformTypeIdentifiers

final class ShareTextLoaderTests: XCTestCase {
    func testDirectAttributedShareKeepsUnicode() async throws {
        let item = NSExtensionItem(); item.attributedContentText = NSAttributedString(string: "Привіт 👋 مرحبا\nhello")
        let text = try await load([item]); XCTAssertEqual(text, item.attributedContentText?.string)
    }
    func testPlainTextProvider() async throws {
        let item = NSExtensionItem(); item.attachments = [NSItemProvider(item: "Hello 👋" as NSString, typeIdentifier: UTType.plainText.identifier)]
        let text = try await load([item]); XCTAssertEqual(text, "Hello 👋")
    }
    func testUnsupportedAndMultipleSelectionsFail() async {
        let first = NSExtensionItem(); first.attributedContentText = NSAttributedString(string: "First")
        let second = NSExtensionItem(); second.attributedContentText = NSAttributedString(string: "Second")
        for items in [[], [first,second]] as [[NSExtensionItem]] {
            do { _ = try await load(items); XCTFail("Expected safe rejection") } catch {}
        }
    }
    func testBoundaries() {
        XCTAssertThrowsError(try ShareTextLoader.validate(" \n"))
        XCTAssertThrowsError(try ShareTextLoader.validate(String(repeating: "🙂", count: 10_001)))
        XCTAssertNoThrow(try ShareTextLoader.validate(String(repeating: "a", count: 20_000)))
    }
    private func load(_ items: [NSExtensionItem]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            ShareTextLoader.load(items) { continuation.resume(with: $0) }
        }
    }
}
