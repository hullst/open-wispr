import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.hull.wispr"
    private init() {}

    private func account(for provider: String) -> String {
        "\(provider)_api_key"
    }

    func setKey(_ key: String, provider: String) {
        let data = key.data(using: .utf8)!
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
        ]
        SecItemDelete(query as CFDictionary)
        let attrs = query.merging([kSecValueData: data]) { $1 }
        SecItemAdd(attrs as CFDictionary, nil)
    }

    func getKey(provider: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else { return nil }
        return key
    }

    func deleteKey(provider: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
        ]
        SecItemDelete(query as CFDictionary)
    }
}
