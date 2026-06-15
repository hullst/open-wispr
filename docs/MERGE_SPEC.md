# Dictation + Rewriter Merge — Spec

**the author · 2026-06-05**

A consolidated brief for merging two existing apps — the **OpenWispr fork** (Swift, native dictation) and **VP Rewriter** (Electron, semantic rewriter) — into a **single native Swift macOS app** called **Wispr**.

End-state goal: one always-on menu-bar app that handles dictation, transcription, history, and on-demand semantic rewriting (local + paid-API) without the user thinking about it.

---

## Why this exists

Two separate apps today, both built by the user with Claude help:

- **OpenWispr fork** — Swift, native macOS, menu bar app. Hold Globe key → records → whisper.cpp (Metal) transcribes → types at cursor. Recent work added a live waveform pill overlay.
- **VP Rewriter** — Electron 35 + Node, runs an HTTP server on localhost:3002, SQLite history, Ollama (`gemma2:9b`) for local rewriting, Cmd+Shift+Space hotkey, has a built .dmg.

They solve adjacent problems and the user shouldn't have to run two apps. Native is the right home (OpenWispr already wins at hotkey/audio/typing; Electron only buys faster UI iteration and a heavier always-on footprint we don't want).

**End state:** single Swift `.app` bundle. No Electron in production. No Node service in production (Ollama still runs separately as a system-level dependency).

---

## Source repositories

### OpenWispr fork (the foundation — merge into this)
- Path: `~/Documents/Claude/Projects/Wispr/` (was `open-wispr-fork/` before rename 2026-06-05)
- Stack: Swift, `Package.swift`, `Sources/`, `Tests/`
- Native macOS app, menu bar, whisper.cpp + Metal
- Hold-Globe-key dictation that types at cursor
- Git remotes:
  - `fork` → `https://github.com/hullst/open-wispr.git` (the user's fork — push here)
  - `origin` → `https://github.com/human37/open-wispr.git` (upstream — don't push)

### VP Rewriter (port relevant code from this; retire afterwards)
- Path: `~/Documents/Claude/Projects/Rewriter/`
- Stack: Electron 35 + Node, `server.js` HTTP server on localhost:3002, SQLite via `better-sqlite3`, whisper.cpp via `/opt/homebrew/bin/whisper-cli` with `ggml-small.en.bin`, Ollama at `http://localhost:11434/api/generate` (default model `gemma2:9b`)
- Tone/style presets at `tone/style-prompts.js` and `tone/ai-blocklist.js`
- After the Swift merge ships, VP Rewriter stays around as a reference repo; nothing new should be built into it.

---

## Architecture decisions (settled — don't relitigate)

1. **Single Swift `.app` bundle.** Native AppKit + SwiftUI. No Electron. No Node.
2. **Build on the OpenWispr fork.** It already has the hardest parts. Port rewriter functionality into it.
3. **macOS 14+ minimum.** SwiftData is available; modern concurrency is fine.
4. **Local-first.** Default model is local (Ollama Gemma 3 4B). Paid APIs are opt-in via Preferences.
5. **Globe key stays the recording hotkey.**
6. **A separate global hotkey** triggers silent rewrite of the last transcript. Default unbound; user assigns in Preferences.
7. **Keychain** for API keys. Service: `com.hull.wispr`. Accounts: `anthropic_api_key`, `openai_api_key`.
8. **Bundle ID:** `com.hull.wispr`. App name: **Wispr**.
9. **LaunchAgent** for always-on startup with crash restart.

---

## Model recommendations

| Tier | Pick | Why |
|---|---|---|
| Free / local default | **Gemma 3 4B** via Ollama | Faster than the old `gemma2:9b`. Sub-second latency on Apple Silicon. |
| Important / paid | **Claude Sonnet 4.6** (`claude-sonnet-4-6`) | Best voice preservation on short rewrites. |
| Fast cloud | **Claude Haiku 4.5** (`claude-haiku-4-5-20251001`) | Sub-second TTFT, default cloud option. |
| Optional | **GPT-5** | Verify exact model id at impl time. |
| Future | Apple Intelligence on-device Foundation Model | `apple/python-apple-fm-sdk` — worth a phase-14 spike. |

---

## Implementation phases

See CHANGELOG.md `[Unreleased]` section for what is done. Phases below are the full plan:

1. Repo setup (MERGE_SPEC, Package.swift, CHANGELOG, README, CLAUDE.md)
2. SwiftData persistence (`Transcript`, `Rewrite` models; wire transcription)
3. Provider layer (`RewriteProvider` protocol + Ollama/Anthropic/OpenAI + `RewriteService`)
4. Keychain integration
5. Style/tone presets (ported from `tone/style-prompts.js` + `tone/ai-blocklist.js`)
6. Rewriter SwiftUI sheet
7. Silent rewrite hotkey (KeyboardShortcuts)
8. Preferences pane
9. History viewer
10. Menu bar polish (idle/recording/rewriting/needs-attention states)
11. LaunchAgent always-on
12. Unit tests
13. README, ROADMAP, docs

---

## Acceptance criteria

- Single `.app` bundle. No Electron. No Node service.
- Globe-key dictation works exactly as before.
- Every dictation is logged to SwiftData before being typed at cursor.
- Menu bar shows status (idle / recording / rewriting / needs-attention).
- "Rewrite Last Transcript" menu action opens SwiftUI sheet pre-filled.
- Model picker shows only configured providers (local always; Claude/OpenAI only when key in Keychain).
- Silent rewrite hotkey runs end-to-end without showing UI.
- Preferences accepts API keys and writes them to Keychain.
- App restarts on crash via LaunchAgent.
- No regressions to current dictation behavior.

---

## Philosophy

Voice preservation matters more than polish. When the user dictates and asks for a rewrite, the result should still sound like the user — just clearer. If a model or prompt makes the output sound like AI, that's a regression.

Always on, always works, feels native, gets out of the way.
