import Foundation

final class GeminiProvider: RewriteProvider {
    let id = "gemini"
    let displayName = "Gemini (Google)"

    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models"

    var isConfigured: Bool {
        KeychainService.shared.getKey(provider: "gemini") != nil
    }

    func rewrite(text: String, systemPrompt: String, maxTokens: Int, temperature: Double = 0.5) async throws -> RewriteResult {
        guard let apiKey = KeychainService.shared.getKey(provider: "gemini") else {
            throw RewriteError.notConfigured("Gemini")
        }

        let model = WisprDefaults.shared.defaultGeminiModel
        let encodedKey = apiKey.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? apiKey
        let urlString = "\(baseURL)/\(model):generateContent?key=\(encodedKey)"
        guard let url = URL(string: urlString) else { throw RewriteError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": [["text": "Rewrite this voice-to-text:\n\n\(text)"]]]],
            "generationConfig": [
                "maxOutputTokens": maxTokens,
                "temperature": temperature,
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
              let candidates = json["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let part = parts.first,
              let outputText = part["text"] as? String else {
            throw RewriteError.invalidResponse
        }

        return RewriteResult(
            text: outputText.trimmingCharacters(in: .whitespacesAndNewlines),
            modelUsed: model,
            latencyMs: latency
        )
    }
}

enum GeminiModel: String, CaseIterable {
    case flashLatest = "gemini-flash-latest"
    case flash35     = "gemini-3.5-flash"
    case flash25     = "gemini-2.5-flash"
    case flash20     = "gemini-2.0-flash"

    var displayName: String {
        switch self {
        case .flashLatest: return "Gemini Flash (latest)"
        case .flash35:     return "Gemini 3.5 Flash"
        case .flash25:     return "Gemini 2.5 Flash"
        case .flash20:     return "Gemini 2.0 Flash"
        }
    }
}
