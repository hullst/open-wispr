import Foundation

@MainActor
final class RewriteService {
    static let shared = RewriteService()

    let ollama = OllamaProvider()
    let anthropic = AnthropicProvider()
    let openai = OpenAIProvider()

    var allProviders: [any RewriteProvider] { [ollama, anthropic, openai] }
    var configuredProviders: [any RewriteProvider] { allProviders.filter { $0.isConfigured } }

    private init() {}

    func probe() async {
        await ollama.probeModels()
    }

    func rewrite(
        text: String,
        providerId: String? = nil,
        styleId: String? = nil,
        transcriptId: Int64? = nil
    ) async throws -> RewriteResult {
        let id = providerId ?? WisprDefaults.shared.defaultProviderId
        guard let provider = allProviders.first(where: { $0.id == id }) else {
            throw RewriteError.notConfigured(id)
        }

        let style = styleId ?? WisprDefaults.shared.defaultStyleId
        let systemPrompt = StylePresets.buildPrompt(styleId: style)

        let result = try await provider.rewrite(text: text, systemPrompt: systemPrompt, maxTokens: 1024)

        PersistenceContainer.shared.logRewrite(
            transcriptId: transcriptId,
            originalText: text,
            rewrittenText: result.text,
            modelId: result.modelUsed,
            provider: provider.id,
            styleId: style,
            latencyMs: result.latencyMs
        )

        return result
    }
}
