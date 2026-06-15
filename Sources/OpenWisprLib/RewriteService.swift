import Foundation

@MainActor
final class RewriteService {
    static let shared = RewriteService()

    let claudeCode = ClaudeCodeProvider()
    let ollama = OllamaProvider()
    let anthropic = AnthropicProvider()
    let openai = OpenAIProvider()
    let gemini = GeminiProvider()

    var allProviders: [any RewriteProvider] { [claudeCode, ollama, anthropic, openai, gemini] }
    var configuredProviders: [any RewriteProvider] { allProviders.filter { $0.isConfigured } }

    private init() {}

    func probe() async {
        await ollama.probeModels()
    }

    func rewrite(
        text: String,
        providerId: String? = nil,
        styleId: String? = nil,
        lengthId: String = "same",
        variantIndex: Int = 0,
        transcriptId: Int64? = nil
    ) async throws -> RewriteResult {
        let id = providerId ?? WisprDefaults.shared.defaultProviderId
        guard let provider = allProviders.first(where: { $0.id == id }) else {
            throw RewriteError.notConfigured(id)
        }

        let style = styleId ?? WisprDefaults.shared.defaultStyleId
        let systemPrompt = StylePresets.buildPrompt(styleId: style, lengthId: lengthId, variantIndex: variantIndex)

        // Ramp temperature per variant so outputs genuinely differ.
        // Single rewrite (index 0) stays conservative; variants 1 and 2 explore wider.
        let temperature: Double = [0.3, 0.58, 0.78][min(variantIndex, 2)]

        let result = try await provider.rewrite(text: text, systemPrompt: systemPrompt, maxTokens: 1024, temperature: temperature)

        let rewriteId = PersistenceContainer.shared.logRewrite(
            transcriptId: transcriptId,
            originalText: text,
            rewrittenText: result.text,
            modelId: result.modelUsed,
            provider: provider.id,
            styleId: style,
            latencyMs: result.latencyMs
        )

        var out = result
        out.rewriteId = rewriteId
        return out
    }
}
