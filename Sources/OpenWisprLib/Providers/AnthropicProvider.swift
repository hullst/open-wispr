import Foundation

final class AnthropicProvider: RewriteProvider {
    let id = "anthropic"
    let displayName = "Claude (Anthropic)"

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    var isConfigured: Bool {
        KeychainService.shared.getKey(provider: "anthropic") != nil
    }

    func rewrite(text: String, systemPrompt: String, maxTokens: Int) async throws -> RewriteResult {
        guard let apiKey = KeychainService.shared.getKey(provider: "anthropic") else {
            throw RewriteError.notConfigured("Claude")
        }

        let model = WisprDefaults.shared.defaultAnthropicModel

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [["role": "user", "content": text]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        guard let http = response as? HTTPURLResponse else { throw RewriteError.invalidResponse }
        guard http.statusCode == 200 else {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errObj = json["error"] as? [String: Any],
               let msg = errObj["message"] as? String {
                throw RewriteError.apiError(http.statusCode, msg)
            }
            throw RewriteError.apiError(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw RewriteError.invalidResponse
        }

        return RewriteResult(text: text.trimmingCharacters(in: .whitespacesAndNewlines), modelUsed: model, latencyMs: latency)
    }
}

// Available Anthropic models for the picker.
enum AnthropicModel: String, CaseIterable {
    case sonnet46 = "claude-sonnet-4-6"
    case haiku45 = "claude-haiku-4-5-20251001"

    var displayName: String {
        switch self {
        case .sonnet46: return "Claude Sonnet 4.6"
        case .haiku45: return "Claude Haiku 4.5 (fast)"
        }
    }
}
