import XCTest
import InigoCore
@testable import Inigo

final class ProcessingFeedbackTests: XCTestCase {
    func testCloudGenerationIdentifiesChatGPTForRefineAndTranslation() {
        XCTAssertEqual(ProcessingCategory.cloud.generationMessage(for: .refine), "Refining with ChatGPT…")
        for language in SupportedLanguage.allCases {
            XCTAssertEqual(ProcessingCategory.cloud.generationMessage(for: .translate(language)), "Translating with ChatGPT…")
        }
    }

    func testManagedAndImportedModelsKeepOnMacFeedback() {
        for category: ProcessingCategory in [.managed2B, .managed4B, .managed9B, .customLocal] {
            XCTAssertEqual(category.generationMessage(for: .refine), "Refining on your Mac…")
            XCTAssertEqual(category.generationMessage(for: .translate(.uk)), "Translating on your Mac…")
        }
    }

    func testExternalServerFeedbackDoesNotClaimWhereInferenceRuns() {
        XCTAssertEqual(ProcessingCategory.externalLocal.generationMessage(for: .refine), "Refining with your local server…")
        XCTAssertEqual(ProcessingCategory.externalLocal.generationMessage(for: .translate(.pl)), "Translating with your local server…")
    }

    func testLocalCategoryReflectsTheActualEngineConfiguration() {
        XCTAssertEqual(ProcessingCategory.local(.init(kind: .server, modelID: "custom")), .externalLocal)
        XCTAssertEqual(ProcessingCategory.local(.init(kind: .file, modelID: "custom")), .customLocal)
        for (id, expected): (String, ProcessingCategory) in [("2B", .managed2B), ("4B", .managed4B), ("9B", .managed9B)] {
            XCTAssertEqual(ProcessingCategory.local(.init(modelID: id)), expected)
        }
    }
}
