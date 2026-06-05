import Foundation

final class OllamaProvider: RewriteProvider {
    let id = "local"
    let displayName = "Local (Ollama)"

    private let baseURL = URL(string: "http://localhost:11434")!
    private(set) var availableModels: [String] = []
    var selectedModel: String

    init(selectedModel: String = "gemma2:9b") {
        self.selectedModel = selectedModel
    }

    var isConfigured: Bool {
        // Considered configured if Ollama is reachable — checked at startup via probeModels().
        !availableModels.isEmpty
    }

    // Called at startup to populate the model list.
    func probeModels() async {
        guard let url = URL(string: "\(baseURL)/api/tags") else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            availableModels = models.compactMap { $0["name"] as? String }
        }
    }

    func rewrite(text: String, systemPrompt: String, maxTokens: Int, temperature: Double = 0.3) async throws -> RewriteResult {
        let url = baseURL.appendingPathComponent("/api/generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": selectedModel,
            "prompt": "Rewrite this voice-to-text:\n\n\(text)",
            "system": systemPrompt,
            "stream": false,
            "options": ["num_predict": maxTokens, "temperature": temperature],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let latency = Int(Date().timeIntervalSince(start) * 1000)

        guard let http = response as? HTTPURLResponse else { throw RewriteError.invalidResponse }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 404 {
                throw RewriteError.serviceUnavailable("Ollama model '\(selectedModel)' not found. Run: ollama pull \(selectedModel)")
            }
            throw RewriteError.apiError(http.statusCode, msg)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["response"] as? String else {
            throw RewriteError.invalidResponse
        }

        return RewriteResult(text: result.trimmingCharacters(in: .whitespacesAndNewlines), modelUsed: selectedModel, latencyMs: latency)
    }
}
