import XCTest
@testable import WisprLib

// Tests that don't require live network — validates provider config logic.
final class RewriteProviderTests: XCTestCase {

    func testOllamaProviderIdAndName() {
        let p = OllamaProvider()
        XCTAssertEqual(p.id, "local")
        XCTAssertFalse(p.displayName.isEmpty)
    }

    func testOllamaNotConfiguredWhenNoModels() {
        let p = OllamaProvider()
        // Fresh provider has no probed models — isConfigured should be false.
        XCTAssertFalse(p.isConfigured)
    }

    func testAnthropicNotConfiguredWithoutKey() {
        // Ensure test key is absent.
        KeychainService.shared.deleteKey(provider: "anthropic")
        let p = AnthropicProvider()
        XCTAssertFalse(p.isConfigured)
    }

    func testOpenAINotConfiguredWithoutKey() {
        KeychainService.shared.deleteKey(provider: "openai")
        let p = OpenAIProvider()
        XCTAssertFalse(p.isConfigured)
    }

    func testAnthropicConfiguredWithKey() {
        KeychainService.shared.setKey("sk-ant-test", provider: "anthropic")
        let p = AnthropicProvider()
        XCTAssertTrue(p.isConfigured)
        KeychainService.shared.deleteKey(provider: "anthropic")
    }

    func testRewriteErrorDescriptions() {
        let e1 = RewriteError.notConfigured("Claude")
        XCTAssertTrue(e1.localizedDescription.contains("Claude"))

        let e2 = RewriteError.apiError(401, "Unauthorized")
        XCTAssertTrue(e2.localizedDescription.contains("401"))

        let e3 = RewriteError.serviceUnavailable("Ollama is down")
        XCTAssertTrue(e3.localizedDescription.contains("Ollama"))
    }
}
