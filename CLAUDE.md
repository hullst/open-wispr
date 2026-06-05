# CLAUDE.md — Wispr

Stephen Hull's always-on dictation + rewrite tool. Native Swift macOS app. Hold Globe key to dictate; use the rewrite sheet or silent hotkey to clean up prose in Stephen's voice.

Part of the larger backup architecture at **~/Documents/Claude/CLAUDE.md** — read that first.

---

## What this is

A merge of two prior apps:
- **OpenWispr fork** — Globe-key dictation, whisper.cpp + Metal, pill overlay (the foundation)
- **VP Rewriter** — Electron semantic rewriter with Ollama + Claude, now retired

See `docs/MERGE_SPEC.md` for the full architecture brief.

---

## Don't break

- **Depends on Ollama running locally** (`http://localhost:11434`). Ollama is on internal SSD as of 2026-06-05. Don't bundle it; it's shared infrastructure.
- **Globe-key dictation is the primary UX.** Any change to `HotkeyManager`, `AudioRecorder`, or `TextInserter` needs careful testing — this is what Stephen uses every hour.
- **Voice preservation is the #1 prompt requirement.** The style presets in `Sources/OpenWisprLib/StylePresets.swift` encode Stephen's voice rules. Do not simplify or generalize them.
- **API keys live in Keychain only.** Service: `com.hull.wispr`. Never write keys to UserDefaults, plist, or source.

## Don't delete

- Move unwanted files to `_trash/` for Stephen to review.
- Never delete files matching `*MASTER*` in Backups/.

## Don't commit

- No API keys, no `.env`, no credentials.

---

## Architecture

```
Sources/
  OpenWisprLib/       — shared library (all app logic)
    AppDelegate.swift     — app lifecycle, hotkey dispatch, transcription pipeline
    AudioRecorder.swift   — mic capture, RMS level feed
    TextInserter.swift    — clipboard-save → Cmd+V paste → clipboard-restore
    TextPolisher.swift    — deterministic pre-paste cleanup (no AI)
    PillOverlay.swift     — floating Listening/Transcribing pill near cursor
    StatusBarController.swift — menu bar icon + menu
    Transcriber.swift     — whisper.cpp subprocess wrapper
    HotkeyManager.swift   — CGEventTap hotkey listener
    KeychainService.swift — Keychain read/write (com.hull.wispr)
    StylePresets.swift    — tone/style prompt definitions (ported from VP Rewriter)
    RewriteProvider.swift — protocol + OllamaProvider/AnthropicProvider/OpenAIProvider
    RewriteService.swift  — picks provider, dispatches, logs to SwiftData
    PersistenceContainer.swift — SwiftData ModelContainer setup
    Models/
      Transcript.swift    — SwiftData model: id, text, source, timestamps
      Rewrite.swift       — SwiftData model: id, FK to transcript, model_id, etc.
    Views/
      RewriteView.swift   — rewrite sheet (source, model/style pickers, result)
      HistoryView.swift   — searchable history of transcripts + rewrites
      PreferencesView.swift — Settings scene (API keys, hotkeys, defaults)
  OpenWispr/
    main.swift            — entry point
Tests/
  OpenWisprTests/         — unit tests for providers, Keychain, presets
docs/
  MERGE_SPEC.md           — full architecture brief
  install-guide.md        — install/permissions walkthrough
```

---

## Build

```bash
cd ~/Documents/Claude/Projects/Wispr
swift build -c release
bash REBUILD   # re-signs and launches for local dev
```

Requires: `brew install whisper-cpp`, Ollama running at localhost:11434.

---

## Backups happening behind your back

- **Cowork task `vp-rewriter-nightly-backup`** — currently still pointing at `Rewriter/`; update to point here once VP Rewriter is fully retired.
- **`com.hull.local-backups`** (02:30 nightly) — handles this folder.
- **`com.hull.sync-reference`** (03:30 nightly) — mirrors to `/Volumes/x10/Master/Reference/Claude/Projects/Wispr/`.

---

## Git remotes

- `fork` → `https://github.com/hullst/open-wispr.git` ← push here
- `origin` → `https://github.com/human37/open-wispr.git` ← upstream, don't push

Active branch: `feature/merge-rewriter`

---

## Documented solutions

`docs/solutions/` — documented solutions to past problems (build errors, runtime issues, tooling decisions, workflow patterns), organized by category with YAML frontmatter (`module`, `tags`, `problem_type`). Relevant when implementing features or debugging in documented areas.
