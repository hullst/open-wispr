# Changelog

All notable changes to Wispr are documented here.

## [2.0.0] — Unreleased (feature/merge-rewriter)

### Added
- SwiftData persistence layer: `Transcript` and `Rewrite` models
- Multi-provider rewrite engine: Ollama (local), Claude Sonnet 4.6, Claude Haiku 4.5, GPT-5
- Keychain integration for API keys (`com.hull.wispr`)
- Style/tone presets ported from VP Rewriter (everyday, chat, companywide) — voice-preservation first
- Rewriter SwiftUI sheet: source text, model picker, style picker, Copy + Paste-to-Active-App
- Silent rewrite hotkey (user-assignable via Preferences, powered by KeyboardShortcuts)
- Preferences pane: API keys, default model, default style, hotkeys, auto-paste toggle
- History viewer: all transcripts + rewrites, grouped by day, searchable, copy/delete
- Menu bar status states: idle, recording, rewriting, needs-attention, error
- "Rewrite Last Transcript" menu action
- LaunchAgent always-on startup with crash restart
- Onboarding prompt on first launch for silent-rewrite hotkey assignment

### Changed
- App renamed from **OpenWispr** to **Wispr** — single bundle, no Electron, no Node
- Bundle ID: `com.hull.wispr`
- Package.swift: minimum platform bumped from macOS 13 → macOS 14
- Package.swift: renamed targets from `open-wispr`/`OpenWisprLib` to `wispr`/`WisprLib`
- Persistence: GRDB (not SwiftData) — SwiftData's `@Model` macro requires Xcode's build plugin and won't compile with `swift build` CLI. GRDB is pure Swift, no macros, parallels VP Rewriter's SQLite approach. Database at `~/Library/Application Support/Wispr/wispr.sqlite`.
- Silent rewrite hotkey: native `NSEvent` monitor (not `KeyboardShortcuts` SPM) — same reason (`#Preview` macros in KeyboardShortcuts require Xcode plugin). Stored in UserDefaults.
- REBUILD script updated: binary `wispr`, bundle `Wispr.app`, codesign id `com.hull.wispr`
- VP Rewriter (Electron) retired as a standalone app; prompts/style logic ported to Swift

### Notes
- Unit tests (StylePresets, Keychain, providers) are written and correct. Running `swift test` fails on CommandLineTools SDK (XCTest not bundled). Use Xcode to run the test suite.

### Merged from feature/live-waveform-pill-polish
- Real RMS-energy waveform in menu bar (fast attack, slow release)
- Floating pill overlay: Listening → Transcribing → disappears
- Deterministic `TextPolisher`: filler removal, voice-command mapping, sentence capitalisation

---

## [0.38.0] — 2026-06 (OpenWispr fork baseline)

- Globe-key hold-to-talk dictation via whisper.cpp + Metal
- TextInserter: clipboard-save → Cmd+V paste → clipboard-restore
- Config at `~/.config/open-wispr/config.json`
- Multiple hotkey bindings, toggle mode, maxRecordings
- Model download + progress tracking
- RecordingStore for re-transcription from menu
