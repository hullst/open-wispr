import Foundation

// User-facing preferences, backed by UserDefaults.
// API keys are NOT stored here — they live in Keychain via KeychainService.
final class WisprDefaults {
    static let shared = WisprDefaults()
    private let defaults = UserDefaults.standard
    private init() {}

    var defaultProviderId: String {
        get { defaults.string(forKey: "defaultProviderId") ?? "claude-code" }
        set { defaults.set(newValue, forKey: "defaultProviderId") }
    }

    var defaultClaudeCodeModel: String {
        get { defaults.string(forKey: "defaultClaudeCodeModel") ?? ClaudeCodeModel.opus.rawValue }
        set { defaults.set(newValue, forKey: "defaultClaudeCodeModel") }
    }

    // "subscription" (personal Mac, Max-plan OAuth) or "bedrock" (work Mac, AWS).
    var claudeCodeAuthMode: String {
        get { defaults.string(forKey: "claudeCodeAuthMode") ?? "subscription" }
        set { defaults.set(newValue, forKey: "claudeCodeAuthMode") }
    }

    var claudeCodeBedrockRegion: String {
        get { defaults.string(forKey: "claudeCodeBedrockRegion") ?? "us-east-1" }
        set { defaults.set(newValue, forKey: "claudeCodeBedrockRegion") }
    }

    // AWS named profile (from ~/.aws/config). Empty = default credential chain.
    var claudeCodeBedrockProfile: String {
        get { defaults.string(forKey: "claudeCodeBedrockProfile") ?? "" }
        set { defaults.set(newValue, forKey: "claudeCodeBedrockProfile") }
    }

    // Bedrock model ID or inference-profile ARN, e.g.
    // "us.anthropic.claude-sonnet-4-5-20250929-v1:0". Work-specific — no default.
    var claudeCodeBedrockModel: String {
        get { defaults.string(forKey: "claudeCodeBedrockModel") ?? "" }
        set { defaults.set(newValue, forKey: "claudeCodeBedrockModel") }
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
        get { defaults.string(forKey: "defaultOllamaModel") ?? "phi4:14b" }
        set { defaults.set(newValue, forKey: "defaultOllamaModel") }
    }

    var defaultGeminiModel: String {
        get { defaults.string(forKey: "defaultGeminiModel") ?? GeminiModel.flashLatest.rawValue }
        set { defaults.set(newValue, forKey: "defaultGeminiModel") }
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
