import Foundation

/// A speech-to-text backend. Both the whisper.cpp subprocess engine
/// (``Transcriber``) and the on-device Parakeet/ANE engine
/// (``ParakeetTranscriber``) conform to this so ``AppDelegate`` can swap
/// engines from config without touching the transcription pipeline.
public protocol TranscriptionEngine: AnyObject {
    /// When true the engine should suppress punctuation so the user can speak
    /// it explicitly ("comma", "period"). Only whisper honors this; Parakeet
    /// emits punctuation natively and ignores the flag.
    var spokenPunctuation: Bool { get set }

    /// Transcribe a 16 kHz mono WAV file. Called off the main thread.
    func transcribe(audioURL: URL) throws -> String

    /// Optional eager model load. whisper is a no-op (it loads per subprocess
    /// call); Parakeet uses this to download + warm the CoreML models so the
    /// first dictation isn't slow. Called off the main thread.
    func warmup() throws
}

public extension TranscriptionEngine {
    func warmup() throws {}
}

/// Which transcription backend to use. Persisted in `config.json` as `engine`.
public enum TranscriptionEngineKind: String, Codable {
    case whisper
    case parakeet

    public static let `default`: TranscriptionEngineKind = .whisper

    public init(configValue: String?) {
        self = TranscriptionEngineKind(rawValue: (configValue ?? "").lowercased()) ?? .default
    }
}
