import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let service = "com.hull.wispr"
    // Same keychain created by scripts/setup-signing.sh — known password, no prompts.
    private let keychainPath = NSHomeDirectory() + "/Library/Keychains/wispr-signing.keychain-db"
    private let keychainPass = "wispr-dev"
    private init() {}

    private func account(for provider: String) -> String {
        "\(provider)_api_key"
    }

    private func openKeychain() -> SecKeychain? {
        var kc: SecKeychain?
        let path = keychainPath
        var status = SecKeychainOpen(path, &kc)
        if status != errSecSuccess { return nil }
        // Unlock with the known password so reads/writes never prompt.
        status = SecKeychainUnlock(kc!, UInt32(keychainPass.utf8.count),
                                   keychainPass, true)
        if status != errSecSuccess {
            print("KeychainService: unlock failed, status \(status)")
        }
        return kc
    }

    func setKey(_ key: String, provider: String) {
        guard let kc = openKeychain() else {
            print("KeychainService: could not open Wispr keychain")
            return
        }
        let data = key.data(using: .utf8)!
        let acct = account(for: provider)

        // Delete any existing item first.
        let deleteQuery: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: acct,
            kSecUseKeychain: kc,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let attrs: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: acct,
            kSecValueData: data,
            kSecUseKeychain: kc,
        ]
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status != errSecSuccess {
            print("KeychainService: setKey failed for \(provider), status \(status)")
            return
        }
        // Grant apple-tool: partition access so the security CLI and the app can
        // read this item without prompting — items added after keychain creation
        // don't inherit the partition list set by setup-signing.sh.
        setPartitionList()
    }

    private func setPartitionList() {
        let path = keychainPath
        let pass = keychainPass
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = [
            "set-key-partition-list",
            "-S", "apple-tool:,apple:,codesign:",
            "-k", pass,
            path,
        ]
        try? task.run()
        task.waitUntilExit()
    }

    func getKey(provider: String) -> String? {
        guard let kc = openKeychain() else { return nil }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
            kSecMatchSearchList: [kc] as CFArray,
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
        guard let kc = openKeychain() else { return }
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account(for: provider),
            kSecUseKeychain: kc,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
