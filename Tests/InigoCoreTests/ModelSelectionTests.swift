import XCTest
@testable import InigoCore

final class ModelSelectionTests: XCTestCase {
    func testRecommendationsReflectQualityBenchmarkAndMemory() {
        XCTAssertEqual(ManagedModel.recommended(memoryGB:8).id,"2B")
        XCTAssertEqual(ManagedModel.recommended(memoryGB:32).id,"9B")
        XCTAssertEqual(ManagedModel.recommended(memoryGB:128).id,"9B")
        XCTAssertEqual(ManagedModel.recommended(memoryGB:16).id,"4B")
        XCTAssertEqual(ManagedModel.recommended(memoryGB:24).id,"9B")
        for model in ManagedModel.all {
            XCTAssertEqual(model.sha256.count,64)
            XCTAssertTrue(model.downloadURL.absoluteString.contains(model.revision))
        }
    }
    func testOnlyLoopbackEndpointsAccepted() throws {
        XCTAssertEqual(try LocalEndpoint.validated("http://localhost:11434/v1").host,"127.0.0.1")
        XCTAssertNoThrow(try LocalEndpoint.validated("http://[::1]:1234/v1"))
        for endpoint in ["https://api.example.com/v1","http://127.0.0.1.example.com","http://user:password@localhost","file:///tmp/model","http://192.168.1.2:8080/v1","http://localhost/v1?redirect=external"] {
            XCTAssertThrowsError(try LocalEndpoint.validated(endpoint))
        }
    }
    func testTranslationCarriesExplicitTargetWithoutRefinementTask() {
        let request = RewriteRequest(draft:"Привіт командо",action:.translate(.pl))
        XCTAssertTrue(request.instructions.contains("Polish (pl)"))
        XCTAssertFalse(request.instructions.contains("Improve clarity"))
        XCTAssertTrue(request.input.contains("target_language"))
        XCTAssertTrue(request.input.contains("Polish"))
    }
    func testDeletionIntermediateWaitsButSubstantiveEditsStop() async {
        var values = ["Before old after","Before  after","Before new after"]
        let result = await WriteVerification.verify(read: {
            EditorTextEquivalence.observation(current:values.removeFirst(),original:"Before old after",expected:"Before new after",deletionIntermediate:"Before  after")
        },pause:{})
        XCTAssertEqual(result,.confirmed)
        XCTAssertEqual(EditorTextEquivalence.observation(current:"Before my new edit after",original:"Before old after",expected:"Before new after",deletionIntermediate:"Before  after"),.different)
    }
    func testReadbackNormalizationDoesNotHideEdits() {
        XCTAssertTrue(EditorTextEquivalence.matches("a\r\nb","a\nb"))
        XCTAssertTrue(EditorTextEquivalence.matches("cafe\u{301}","café"))
        XCTAssertFalse(EditorTextEquivalence.matches("Hello  team","Hello team"))
        XCTAssertFalse(EditorTextEquivalence.matches("Maybe Friday","Friday"))
        XCTAssertFalse(EditorTextEquivalence.matches("text\n","text"))
    }
}
