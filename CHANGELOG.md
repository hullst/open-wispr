# Changelog

All notable changes to Wispr are documented here.

## [2.1.0] — Unreleased (feature/merge-rewriter)

### Added
- **Native floating panel** — borderless, vibrancy-backed (`.sidebar` material, `.behindWindow`), 16px rounded corners, no title bar, `animationBehavior = .utilityWindow`. Follows all Spaces.
- **Panel auto-sizing** — panel height animates smoothly as content changes (source only → rewrite result → variants → diff).
- **Source text fade** — source area drops to 45% opacity when result arrives, keeping visual focus on the rewrite.
- **Result slide-in animation** — result card slides up with spring physics when rewrite completes.
- **Word-level diff view** (`WordDiff.swift`) — "What changed?" toggle shows LCS diff: removed words in ~~strikethrough red~~, added words highlighted green.
- **AI linter** (`WisprLinter.swift`) — deterministic post-rewrite check against banned word list from `ai-blocklist.js`. Yellow warning in result card if AI tells detected.
- **Variants chip** — "Get 3 variants" is now a compact pill/chip instead of a full button. Appears in the result action row.
- **Onboarding** (`OnboardingView.swift`) — first launch modal explaining Globe key, rewrite panel, and silent hotkey. One-time, marks `hasCompletedOnboarding` in UserDefaults.
- **Startup error states** — on launch, probes Ollama; if unreachable or default model missing, shows `needsAttention` in menu bar with explanatory message.
- **Anthropic prompt caching** — `cache_control: ephemeral` on system prompt. After first call, ~80% cost reduction on the 1500-token system prompt for all subsequent Claude rewrites.
- **Hold-to-talk only** — toggle mode removed. Globe key always means hold to dictate, release to stop.

### Changed
- Rewrite panel width: 500px → 560px
- Segmented control labels: Shorter/Longer → Short/Long (fit in picker frame)
- Temperature lowered 0.5 → 0.3 for more consistent output on local models
- System prompt: hard stop added at top — model no longer responds conversationally when source text looks like a question
- Input wrapper: all providers now send `"Rewrite this voice-to-text:\n\n[text]"` — eliminates the root cause of the conversational response bug

### Fixed
- REBUILD was spawning two instances: LaunchAgent `KeepAlive=true` + manual `open` call racing. Removed the manual launch step — LaunchAgent is the sole launch authority.

---

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
