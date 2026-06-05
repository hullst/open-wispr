import Foundation

struct RewriteResult {
    let text: String
    let modelUsed: String
    let latencyMs: Int
}

protocol RewriteProvider {
    var id: String { get }
    var displayName: String { get }
    var isConfigured: Bool { get }
    func rewrite(text: String, systemPrompt: String, maxTokens: Int) async throws -> RewriteResult
}

enum RewriteError: LocalizedError {
    case notConfigured(String)
    case serviceUnavailable(String)
    case apiError(Int, String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured(let name): return "\(name): not configured. Add an API key in Preferences."
        case .serviceUnavailable(let msg): return msg
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        case .invalidResponse: return "Unexpected response from model."
        }
    }
}
