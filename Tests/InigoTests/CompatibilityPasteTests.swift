import XCTest
import AppKit
@testable import Inigo

@MainActor
final class CompatibilityPasteTests: XCTestCase {
    func testRestoresAllRepresentationsAndMultipleItems() async throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        let first = NSPasteboardItem()
        first.setString("Previous clipboard", forType: .string)
        first.setData(Data([0, 1, 255]), forType: .init("app.inigo.test-binary"))
        let second = NSPasteboardItem(); second.setString("Second item", forType: .string)
        board.writeObjects([first, second])
        let transaction = try CompatibilityPaste(pasteboard: board)
        try transaction.stage("Rewrite")
        XCTAssertEqual(board.string(forType: .string), "Rewrite")
        XCTAssertNotNil(board.data(forType: .init("org.nspasteboard.TransientType")))
        transaction.restore()
        XCTAssertEqual(board.pasteboardItems?.count, 2)
        XCTAssertEqual(board.pasteboardItems?.first?.string(forType: .string), "Previous clipboard")
        XCTAssertEqual(board.pasteboardItems?.first?.data(forType: .init("app.inigo.test-binary")), Data([0,1,255]))
        XCTAssertEqual(board.pasteboardItems?.last?.string(forType: .string), "Second item")
    }
    func testDoesNotOverwriteNewUserClipboardContent() async throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let transaction = try CompatibilityPaste(pasteboard: board)
        try transaction.stage("Rewrite")
        board.clearContents(); board.setString("New user copy", forType: .string)
        transaction.restore()
        XCTAssertEqual(board.string(forType: .string), "New user copy")
    }
    func testChangedClipboardBeforeStagingAborts() async throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        board.setString("Original", forType: .string)
        let transaction = try CompatibilityPaste(pasteboard: board)
        board.clearContents(); board.setString("New user copy", forType: .string)
        XCTAssertThrowsError(try transaction.stage("Rewrite"))
        XCTAssertEqual(board.string(forType: .string), "New user copy")
    }
    func testRestoresEmptyClipboard() async throws {
        let board = NSPasteboard.withUniqueName(); defer { board.releaseGlobally() }
        board.clearContents()
        let transaction = try CompatibilityPaste(pasteboard: board)
        try transaction.stage("Rewrite"); transaction.restore()
        XCTAssertNil(board.string(forType: .string))
    }
}
