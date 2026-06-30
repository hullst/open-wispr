# Architecture — Wispr

Wispr is a **native Swift macOS menu-bar app** (Swift Package Manager, *not* Electron) — the
[`open-wispr`](https://github.com/human37/open-wispr) fork with VP Rewriter's semantic
rewriting merged in. It is the eventual successor to VP Rewriter. One always-on `.accessory`
process does everything: hold the Globe key to dictate, release to transcribe locally, and
optionally clean the text up in the user's voice — all on-device by default.

This file is the **how it fits together** map. It does not duplicate:
- [`docs/MERGE_SPEC.md`](docs/MERGE_SPEC.md) — *why* the two apps merged + the settled decisions (don't relitigate).
- [`README.md`](README.md) — install, config keys, model table, menu-bar states.
- [`CLAUDE.md`](CLAUDE.md) — the file-by-file source-tree map + "don't break / don't delete" rules.
- [`docs/install-guide.md`](docs/install-guide.md) — permissions walkthrough.
- [`ROADMAP.md`](ROADMAP.md) / [`CHANGELOG.md`](CHANGELOG.md) — what's done and planned.

## Two pipelines, one process

Everything runs inside the single `wispr` executable (`Sources/OpenWispr/main.swift` →
`AppDelegate`). There are two independent user paths that share the same store and providers.

### A. Dictation pipeline (the primary, hourly-use path)

```
  Globe key held              (HotkeyManager — CGEventTap, key-down)
        │
        ▼
  AudioRecorder ──────────────  AVFoundation mic capture → temp .wav
        │   (live RMS level → PillOverlay + StatusBarController waveform)
        ▼
  Globe key released          (key-up; taps < 0.5 s are discarded — accidental press)
        │
        ▼
  Transcriber ────────────────  whisper.cpp subprocess on Metal (GGML model)
        │
        ▼
  TextPostProcessor + TextPolisher  deterministic, NO AI
        │   (spoken-punctuation, number-words → digits, filler strip, user dictionary)
        ▼
  PersistenceContainer.insertTranscript(source: "dictation")   → wispr.sqlite
        │
        ▼
  TextInserter ───────────────  save clipboard → synth ⌘V paste at cursor → restore clipboard
```

Whisper output is logged to SQLite **before** anything is pasted, so a dictation is never
lost even if the paste target misbehaves. If the rewrite panel is the key window, the
transcript is appended into its source field instead of pasted (`RewritePanel.vm.appendOrSet`).

### B. Rewrite pipeline (on-demand polish)

```
  Silent-rewrite hotkey  OR  "Rewrite Last Transcript" / RewriteView sheet
        │   (RewriteHotkeyManager — separate, user-assigned global hotkey)
        ▼
  RewriteService.rewrite(text, providerId, styleId, lengthId, variantIndex)
        │
        ├── StylePresets.buildPrompt() ── basePrompt + style suffix + length modifier
        │
        ▼
  RewriteProvider (the chosen one) ── async rewrite(systemPrompt, maxTokens, temperature)
        │
        ▼
  PersistenceContainer.logRewrite(...)   → wispr.sqlite (rewrites table, FK → transcript)
        │
        ▼
  silent path: TextInserter pastes at cursor   ·   sheet path: shown for edit/accept
```

The silent path takes the **most recent transcript** from SQLite, rewrites it with the
default provider/style, pastes the result, and shows nothing — a single keypress turns the
last dictation into clean prose. The sheet path (`Views/RewriteView.swift`) exposes provider,
style, length, and per-variant temperature ramp (`[0.3, 0.58, 0.78]`) for deliberate rewriting.

## Components

| Component | File(s) | Role |
|---|---|---|
| Lifecycle + dispatch | `AppDelegate.swift` | Owns both pipelines, the `.accessory` app, the hidden Edit menu, audio device re-resolution on sleep/wake. |
| Dictation hotkey | `HotkeyManager.swift` | `CGEventTap` key-down/up for the Globe (or configured) key(s). |
| Rewrite hotkey | `RewriteHotkeyManager.swift` | Separate global hotkey for silent rewrite (default unbound). |
| Capture | `AudioRecorder.swift` | Mic capture + live RMS level; reloads on `AVAudioEngineConfigurationChange` / wake. |
| Transcription | `Transcriber.swift`, `ModelDownloader.swift` | whisper.cpp subprocess (Metal), GGML model fetch/validate. |
| Deterministic cleanup | `TextPolisher.swift`, `TextPostProcessor.swift`, `NumberWords.swift` | Punctuation, number-words, fillers, dictionary — **no AI**. |
| Insertion | `TextInserter.swift` | Clipboard-preserving synthetic ⌘V. |
| Provider abstraction | `RewriteProvider.swift`, `RewriteService.swift`, `Providers/` | Protocol + a provider per backend; service picks, dispatches, logs. |
| Style prompts | `StylePresets.swift` | The user's voice rules — base prompt, 3 styles, length modifiers, banned-word list. |
| Store | `PersistenceContainer.swift`, `Models/` | GRDB SQLite — transcripts + rewrites. |
| Secrets | `KeychainService.swift` | API keys in the macOS Keychain (`com.hull.wispr`). |
| UI | `StatusBarController.swift`, `PillOverlay.swift`, `Views/` | Menu-bar icon/states, floating pill, sheet/history/preferences. |

### Provider abstraction

`RewriteService` holds five `RewriteProvider` implementations and exposes only the
**configured** ones (`configuredProviders`) so the UI never offers a provider without a key:

- **`OllamaProvider`** — the local default (`http://localhost:11434`, `gemma2:9b`). Always "configured" if Ollama is up; probed at launch and surfaced as a menu-bar warning if the daemon or model is missing.
- **`ClaudeCodeProvider`** — local Claude via the Claude Code CLI (no API key needed).
- **`AnthropicProvider`** — Claude over the API (prompt caching enabled). Needs `anthropic_api_key`.
- **`OpenAIProvider`** — GPT. Needs `openai_api_key`.
- **`GeminiProvider`** — Google Gemini. Needs `gemini_api_key`.

Adding a backend = one file in `Providers/` conforming to the protocol, registered in
`RewriteService`. Everything downstream (logging, UI, style prompts) is provider-agnostic.

## Data & storage

| Path | What | Lifecycle |
|---|---|---|
| `~/.config/open-wispr/config.json` | Hotkeys, model size, language, dictionary, toggles (`Config.swift`) | User-editable; reloaded live via the menu. Note the **`open-wispr`** dir name (fork heritage), not `wispr`. |
| `~/.config/open-wispr/models/` | GGML whisper models | Downloaded + checksum-validated on first use; regenerable. |
| `~/Library/Application Support/Wispr/wispr.sqlite` | GRDB DB — `transcripts` + `rewrites` (with `editedText`) | **The permanent record.** Migrated by `DatabaseMigrator`. |
| temp `.wav` (in `RecordingStore`) | Recorded audio | **Deleted right after transcription** when `maxRecordings == 0` (default). Set 1–100 to retain N for re-transcribe. |
| macOS Keychain `com.hull.wispr` | `anthropic_api_key`, `openai_api_key`, `gemini_api_key` | Read/written through a known-password dev keychain so the daemon never prompts. |
| `/tmp/wispr.log` | LaunchAgent stdout/stderr | Diagnostic. |

**Design decision — GRDB, not SwiftData.** SwiftData's `@Model` macro needs Xcode's build
plugin and won't compile under `swift build` (which `REBUILD` uses). GRDB is pure Swift, builds
from the CLI, and parallels VP Rewriter's `better-sqlite3` store. (MERGE_SPEC and some older
notes still say "SwiftData" — that was the plan; GRDB is the reality. See the comment atop
`PersistenceContainer.swift`.)

**Design decision — audio is ephemeral.** Privacy and disk both win: the temp `.wav` exists only
long enough for whisper.cpp to read it, then it's deleted. Only the text survives.

## macOS 26 (Tahoe) Gatekeeper reality

This is the operational gotcha worth knowing before you touch the build:

- macOS 26 **silently refuses to launch ad-hoc-signed apps from Finder, Spotlight, or Raycast** — no error, just nothing. Wispr is a background service, so this rarely matters in practice, but double-clicking `Wispr.app` will appear to do nothing.
- The supported start path is the **`com.hull.wispr` LaunchAgent** (`RunAtLoad` + `KeepAlive`, runs `/Applications/Wispr.app/Contents/MacOS/wispr start`, logs to `/tmp/wispr.log`). It restarts on crash.
- **Build + install** via `swift build -c release` then `bash REBUILD`, which bundles `Wispr.app`, strips quarantine xattrs (`xattr -cr`), and **codesigns** with a persistent dev cert (`Wispr Dev Signing`, set up once by `scripts/setup-signing.sh`) under a designated-requirement of `identifier "com.hull.wispr"`. If the cert is missing it falls back to ad-hoc signing. The persistent identity is what lets the Keychain grant the app stable access without re-prompting.
- `main.swift` re-launches through the app bundle (`AppBundleLaunch.relaunchThroughAppBundleIfNeeded`) so TCC permissions (Accessibility, Microphone) attach to the bundle identity, not a bare binary.

See [`README.md` → Troubleshooting](README.md) and `REBUILD` for the canonical commands.

## Cross-project coupling — the Rewriter prompt mirror

`StylePresets.swift` is a **hand-copied mirror** of VP Rewriter's `tone/style-prompts.js` plus
the first 34 words of its `tone/ai-blocklist.js` (inlined into `promptBannedWords` so the Swift
app has no JS dependency). `Tokens.swift` likewise copies Rewriter's design tokens. **There is no
runtime link — the two will silently drift** when either side's prompts are tuned. This is
coupling **#6** in [`../DEPENDENCIES.md`](../DEPENDENCIES.md) (status: ⚠ FRAGILE / will drift) — the
active P1 of the merge, since Wispr supersedes Rewriter. Harden until Rewriter is retired:
generate the banned-word constant from `ai-blocklist.js` at build time, or add an equality test.

The voice rules in this file encode the user's actual writing voice. Per `CLAUDE.md`: **do not
simplify or generalize them.**

## Fork / upstream remote model

Two remotes, and pushing the wrong one would land the user's private prompts on a public fork:

- **`fork` → `github.com/hullst/open-wispr.git`** — the user's fork. **Push here.**
- **`origin` → `github.com/human37/open-wispr.git`** — the original upstream. **Fetch-only; never push.**

Active branch: `feature/merge-rewriter`. (Note: `APP.yaml` labels these the other way around —
`git_remote`/`deploy` there call hullst `fork`/push-target and human37 `origin`/upstream, which
matches MERGE_SPEC and `CLAUDE.md`. The MERGE_SPEC/CLAUDE.md naming is authoritative.)

## Failure modes the design tolerates

- **Tap too short (< 0.5 s)** → whisper is skipped entirely, pill dismissed, no empty transcript.
- **Ollama down or model missing** → probed at launch; menu bar shows a transient "needs attention" warning; cloud providers (if keyed) still work. Local rewrite simply unavailable, dictation unaffected.
- **Audio device reassigned on sleep/wake** → `AVAudioEngineConfigurationChange` + `didWake` observers re-resolve the device by **stable UID** (not the volatile numeric `AudioDeviceID`) and reload the engine, so the waveform doesn't go silently dead.
- **Corrupt/missing GGML model** → validated after download; a bad file surfaces an error state with the re-download command instead of crashing transcription.
- **Rewrite provider error** → caught in `AppDelegate.handleSilentRewrite` / `RewriteService`; menu bar shows the error for a few seconds then returns to idle. The transcript is already saved, so nothing is lost.
- **Crash** → the LaunchAgent's `KeepAlive` restarts the process (ThrottleInterval 5).
- **Missing Accessibility/Microphone permission** → menu bar enters a waiting state and the app opens the relevant System Settings pane rather than failing silently.
