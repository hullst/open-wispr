import Foundation

final class OpenAIProvider: RewriteProvider {
    let id = "openai"
    let displayName = "GPT (OpenAI)"

    private let baseURL = URL(string: "https://api.openai.com/v1/chat/completions")!

    // Verify the exact GPT-5 model id when this is wired up.
    static let defaultModel = "gpt-4o"

    var isConfigured: Bool {
        KeychainService.shared.getKey(provider: "openai") != nil
    }

    func rewrite(text: String, systemPrompt: String, maxTokens: Int) async throws -> RewriteResult {
        guard let apiKey = KeychainService.shared.getKey(provider: "openai") else {
            throw RewriteError.notConfigured("OpenAI")
        }

        let model = WisprDefaults.shared.defaultOpenAIModel

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": text],
            ],
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
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw RewriteError.invalidResponse
        }

        return RewriteResult(text: content.trimmingCharacters(in: .whitespacesAndNewlines), modelUsed: model, latencyMs: latency)
    }
}
