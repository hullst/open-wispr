import Foundation
import FluidAudio

/// On-device speech-to-text via NVIDIA Parakeet running on the Apple Neural
/// Engine (FluidAudio). Faster and more accurate on English than the whisper
/// base model in local A/B testing, and runs in-process (no subprocess).
///
/// FluidAudio's `AsrManager` is an actor with an async API; the dictation
/// pipeline calls ``transcribe(audioURL:)`` synchronously off the main thread,
/// so we bridge async→sync with a semaphore. The CoreML models are loaded once
/// and kept warm — loading is expensive and must not happen per call.
public final class ParakeetTranscriber: TranscriptionEngine {
    /// Parakeet emits punctuation natively; the flag is accepted for protocol
    /// conformance but has no effect (whisper-only behavior).
    public var spokenPunctuation: Bool = false

    private let version: AsrModelVersion
    private var manager: AsrManager?
    private let initLock = NSLock()

    /// - Parameter english: v2 is English-only with better recall; v3 covers
    ///   25 languages. Defaults to v2 since the daily driver dictates English.
    public init(english: Bool = true) {
        self.version = english ? .v2 : .v3
    }

    /// Download (first run only) and load the CoreML models, caching the
    /// manager. Safe to call repeatedly; subsequent calls return the cached
    /// manager. MUST be called off the main thread (it blocks).
    public func warmup() throws {
        _ = try loadedManager()
    }

    public func transcribe(audioURL: URL) throws -> String {
        let manager = try loadedManager()
        return try runBlocking {
            var state = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
            let result = try await manager.transcribe(audioURL, decoderState: &state)
            return result.text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    // MARK: - Internals

    private func loadedManager() throws -> AsrManager {
        initLock.lock()
        defer { initLock.unlock() }
        if let manager { return manager }
        let version = self.version
        let manager = try runBlocking {
            let models = try await AsrModels.downloadAndLoad(version: version)
            let manager = AsrManager(config: .default)
            try await manager.loadModels(models)
            return manager
        }
        self.manager = manager
        return manager
    }

    /// Run an async throwing closure and block the current (background) thread
    /// until it completes. The work runs on the Swift cooperative pool, which is
    /// independent of the blocked GCD thread, so there is no deadlock as long as
    /// this is never called on the main thread.
    private func runBlocking<T: Sendable>(_ body: @escaping @Sendable () async throws -> T) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox<T>()
        Task {
            do { box.result = .success(try await body()) }
            catch { box.result = .failure(error) }
            semaphore.signal()
        }
        semaphore.wait()
        return try box.result!.get()
    }

    private final class ResultBox<T>: @unchecked Sendable {
        var result: Result<T, Error>?
    }
}
