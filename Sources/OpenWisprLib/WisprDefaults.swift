import Foundation

// User-facing preferences, backed by UserDefaults.
// API keys are NOT stored here — they live in Keychain via KeychainService.
final class WisprDefaults {
    static let shared = WisprDefaults()
    private let defaults = UserDefaults.standard
    private init() {}

    var defaultProviderId: String {
        get { defaults.string(forKey: "defaultProviderId") ?? "local" }
        set { defaults.set(newValue, forKey: "defaultProviderId") }
    }

    var defaultStyleId: String {
        get { defaults.string(forKey: "defaultStyleId") ?? "everyday" }
        set { defaults.set(newValue, forKey: "defaultStyleId") }
    }

    var defaultAnthropicModel: String {
        get { defaults.string(forKey: "defaultAnthropicModel") ?? AnthropicModel.sonnet46.rawValue }
        set { defaults.set(newValue, forKey: "defaultAnthropicModel") }
    }

    var defaultOpenAIModel: String {
        get { defaults.string(forKey: "defaultOpenAIModel") ?? OpenAIProvider.defaultModel }
        set { defaults.set(newValue, forKey: "defaultOpenAIModel") }
    }

    var defaultOllamaModel: String {
        get { defaults.string(forKey: "defaultOllamaModel") ?? "gemma2:9b" }
        set { defaults.set(newValue, forKey: "defaultOllamaModel") }
    }

    // When true, the rewrite sheet auto-pastes the result to the active app.
    var autoPasteRewrites: Bool {
        get { defaults.object(forKey: "autoPasteRewrites") == nil ? true : defaults.bool(forKey: "autoPasteRewrites") }
        set { defaults.set(newValue, forKey: "autoPasteRewrites") }
    }

    var dictationEnabled: Bool {
        get { defaults.object(forKey: "dictationEnabled") == nil ? true : defaults.bool(forKey: "dictationEnabled") }
        set { defaults.set(newValue, forKey: "dictationEnabled") }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: "hasCompletedOnboarding") }
        set { defaults.set(newValue, forKey: "hasCompletedOnboarding") }
    }
}
