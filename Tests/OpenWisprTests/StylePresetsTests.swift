import XCTest
@testable import WisprLib

final class StylePresetsTests: XCTestCase {

    func testAllStylesPresent() {
        let ids = Set(StylePresets.all.map { $0.id })
        XCTAssertTrue(ids.contains("everyday"))
        XCTAssertTrue(ids.contains("chat"))
        XCTAssertTrue(ids.contains("companywide"))
    }

    func testBuildPromptContainsBase() {
        let prompt = StylePresets.buildPrompt(styleId: "everyday")
        XCTAssertTrue(prompt.contains("VP of Engineering"), "Base prompt must identify Stephen's role")
        XCTAssertTrue(prompt.contains("voice-to-text"), "Must describe the use case")
    }

    func testBannedWordsInPrompt() {
        let prompt = StylePresets.buildPrompt(styleId: "everyday")
        XCTAssertTrue(prompt.contains("delve"), "Banned words list must be present in prompt")
        XCTAssertTrue(prompt.contains("leverage"), "Banned words list must be present in prompt")
    }

    func testNoEmDashInPrompts() {
        for style in StylePresets.all {
            let prompt = StylePresets.buildPrompt(styleId: style.id)
            XCTAssertFalse(prompt.contains("—"), "No literal em-dash in \(style.id) prompt")
            XCTAssertFalse(prompt.contains("–"), "No en-dash in \(style.id) prompt")
        }
    }

    func testUnknownStyleFallsBackToEveryday() {
        let fallback = StylePresets.buildPrompt(styleId: "nonexistent")
        let everyday = StylePresets.buildPrompt(styleId: "everyday")
        XCTAssertEqual(fallback, everyday)
    }
}
