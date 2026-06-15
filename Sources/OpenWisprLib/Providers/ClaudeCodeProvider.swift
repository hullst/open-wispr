import Foundation

// Routes rewrites through the Claude Code CLI (`claude -p`). Two auth modes, so
// the SAME app works on the user's personal Mac and his work Mac:
//
//   .subscription  — personal machine. claude uses the Max-plan OAuth token in
//                    the macOS Keychain ("Claude Code-credentials"). $0 incremental.
//   .bedrock       — work machine. Sets CLAUDE_CODE_USE_BEDROCK=1 + AWS region/
//                    profile so claude talks to Amazon Bedrock using the work AWS
//                    credentials (SSO cache or ~/.aws). Billed to the work AWS acct.
//
// The claude binary reads its own Keychain item and the ~/.aws config, so spawning
// it from Wispr does not trigger a Keychain prompt.
final class ClaudeCodeProvider: RewriteProvider {
    let id = "claude-code"
    let displayName = "Claude Code (subscription)"

    enum AuthMode: String { case subscription, bedrock }

    var isConfigured: Bool {
        ClaudeCodeProvider.findClaudeBinary() != nil
    }

    func rewrite(text: String, systemPrompt: String, maxTokens: Int, temperature: Double = 0.5) async throws -> RewriteResult {
        guard let claudePath = ClaudeCodeProvider.findClaudeBinary() else {
            throw RewriteError.notConfigured("Claude Code")
        }

        let defaults = WisprDefaults.shared
        let mode = AuthMode(rawValue: defaults.claudeCodeAuthMode) ?? .subscription
        let model: String = (mode == .bedrock)
            ? defaults.claudeCodeBedrockModel
            : defaults.defaultClaudeCodeModel

        if mode == .bedrock && model.isEmpty {
            throw RewriteError.notConfigured("Claude Code (Bedrock): set a model ID in Preferences")
        }

        let userPrompt = "Rewrite this voice-to-text:\n\n\(text)"
        let environment = ClaudeCodeProvider.buildEnvironment(mode: mode, defaults: defaults)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)
                process.arguments = [
                    "--print",
                    "--model", model,
                    "--system-prompt", systemPrompt,
                    "--strict-mcp-config",   // no MCP servers -> faster, no tool use
                ]
                process.environment = environment
                // Pin claude to an empty scratch dir on the internal disk. Without
                // this it inherits CWD=/ and scans for project context, which reaches
                // /Volumes and triggers the macOS removable-volume privacy prompt. An
                // empty dir also keeps stray CLAUDE.md/git context out of the rewrite.
                process.currentDirectoryURL = ClaudeCodeProvider.scratchDir()

                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardInput = stdinPipe
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                let start = Date()
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: RewriteError.serviceUnavailable(
                        "Couldn't launch Claude Code: \(error.localizedDescription)"))
                    return
                }

                // Feed the transcript via stdin so input starting with "-" is never
                // misread as a flag.
                stdinPipe.fileHandleForWriting.write(Data(userPrompt.utf8))
                stdinPipe.fileHandleForWriting.closeFile()

                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let latency = Int(Date().timeIntervalSince(start) * 1000)

                let output = String(data: outData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                guard process.terminationStatus == 0, !output.isEmpty else {
                    let stderr = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let msg = stderr.isEmpty ? "Claude Code exited with status \(process.terminationStatus)" : stderr
                    continuation.resume(throwing: RewriteError.serviceUnavailable("Claude Code: \(msg)"))
                    return
                }

                continuation.resume(returning: RewriteResult(
                    text: output,
                    modelUsed: model,
                    latencyMs: latency
                ))
            }
        }
    }

    // Inherit the parent environment (so anything already configured passes through),
    // then guarantee the vars claude needs and apply the mode-specific overrides.
    static func buildEnvironment(mode: AuthMode, defaults: WisprDefaults) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let home = NSHomeDirectory()
        let user = NSUserName()
        env["HOME"] = home
        env["USER"] = user
        env["LOGNAME"] = user
        // Ensure Homebrew + system bins are on PATH (LaunchAgent-spawned apps get a
        // minimal PATH, and claude may need node/aws on it).
        let basePath = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        if let existing = env["PATH"], !existing.isEmpty {
            env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + existing
        } else {
            env["PATH"] = basePath
        }

        switch mode {
        case .subscription:
            // Force off Bedrock in case the work env leaks in; use Keychain OAuth.
            env["CLAUDE_CODE_USE_BEDROCK"] = nil
        case .bedrock:
            env["CLAUDE_CODE_USE_BEDROCK"] = "1"
            let region = defaults.claudeCodeBedrockRegion
            if !region.isEmpty {
                env["AWS_REGION"] = region
                env["AWS_DEFAULT_REGION"] = region
            }
            let profile = defaults.claudeCodeBedrockProfile
            if !profile.isEmpty {
                env["AWS_PROFILE"] = profile
            }
            // Belt-and-suspenders: some claude versions key off ANTHROPIC_MODEL.
            let model = defaults.claudeCodeBedrockModel
            if !model.isEmpty {
                env["ANTHROPIC_MODEL"] = model
            }
        }
        return env
    }

    // Empty directory used as claude's working dir, created on first use.
    static func scratchDir() -> URL {
        let dir = Config.configDir.appendingPathComponent("claude-cwd")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func findClaudeBinary() -> String? {
        let candidates = [
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            NSHomeDirectory() + "/.local/bin/claude",
        ]
        for path in candidates where FileManager.default.fileExists(atPath: path) {
            return path
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["claude"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        try? which.run()
        which.waitUntilExit()
        let result = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let result, !result.isEmpty { return result }
        return nil
    }
}

// Model ALIASES, not full IDs -- these resolve on BOTH machines: subscription
// maps "opus"/"sonnet" to the current models; work Bedrock maps them via the
// ANTHROPIC_DEFAULT_{OPUS,SONNET}_MODEL settings. One string, both backends.
enum ClaudeCodeModel: String, CaseIterable {
    case opus   = "opus"
    case sonnet = "sonnet"

    var displayName: String {
        switch self {
        case .opus:   return "Opus (best — default)"
        case .sonnet: return "Sonnet (slightly faster)"
        }
    }
}
