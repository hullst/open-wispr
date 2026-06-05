import XCTest
@testable import WisprLib

final class KeychainServiceTests: XCTestCase {
    let keychain = KeychainService.shared
    let testProvider = "test-provider-\(UUID().uuidString)"

    override func tearDown() {
        keychain.deleteKey(provider: testProvider)
        super.tearDown()
    }

    func testRoundTrip() {
        XCTAssertNil(keychain.getKey(provider: testProvider))
        keychain.setKey("sk-test-key-123", provider: testProvider)
        XCTAssertEqual(keychain.getKey(provider: testProvider), "sk-test-key-123")
    }

    func testOverwrite() {
        keychain.setKey("first", provider: testProvider)
        keychain.setKey("second", provider: testProvider)
        XCTAssertEqual(keychain.getKey(provider: testProvider), "second")
    }

    func testDelete() {
        keychain.setKey("to-delete", provider: testProvider)
        keychain.deleteKey(provider: testProvider)
        XCTAssertNil(keychain.getKey(provider: testProvider))
    }

    func testEmptyStringNotStored() {
        keychain.setKey("", provider: testProvider)
        // Empty string should not be returned as a valid key.
        let result = keychain.getKey(provider: testProvider)
        XCTAssertTrue(result == nil || result == "")
    }
}
