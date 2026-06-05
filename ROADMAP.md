# Wispr — Roadmap

## v2.0 — Merge (current, `feature/merge-rewriter`)

The foundational merge of OpenWispr fork + VP Rewriter into a single native Swift app.

**Shipped:**
- [x] Globe-key dictation (from OpenWispr)
- [x] Live waveform pill overlay
- [x] Deterministic TextPolisher (filler removal, sentence capitalisation)
- [x] GRDB persistence: every dictation logged as Transcript
- [x] Multi-provider rewrite engine: Ollama (local), Claude Sonnet 4.6, Claude Haiku 4.5, GPT
- [x] Battle-tested style presets ported from VP Rewriter (everyday, chat, companywide)
- [x] Keychain integration for API keys (com.hull.wispr)
- [x] Rewriter SwiftUI panel (source, model/style pickers, result, copy/paste-to-app)
- [x] Silent rewrite hotkey (user-assignable, NSEvent-based, no external dependency)
- [x] Preferences pane (API keys + test, default model/style, hotkeys, auto-paste toggle)
- [x] History viewer (all transcripts + rewrites, searchable, copy/delete)
- [x] Menu bar: idle/recording/transcribing/rewriting/needs-attention states
- [x] Menu actions: Rewrite Last Transcript, Open History, Preferences
- [x] LaunchAgent (com.hull.wispr) for always-on startup with crash restart
- [x] Bundle ID: com.hull.wispr, macOS 14+ minimum

---

## v2.1 — Voice Quality

- [ ] **Evaluate Gemma 3 4B as local default.** Current default is `gemma2:9b` (the battle-tested VP Rewriter model). Run an eval against `gemma3:4b` — smaller, faster on Apple Silicon. Only switch if voice-preservation quality is equal or better. Run: `ollama pull gemma3:4b`, then compare outputs side-by-side in the rewrite sheet using the everyday style on 10 real dictations.
- [ ] **AI linter port.** Port `ai-blocklist.js` linter logic to Swift. On every rewrite, run the deterministic linter. If violations found: show yellow warning in result pane listing the offenders. Do NOT auto-reject — just flag.
- [ ] **Stream Ollama responses.** Switch OllamaProvider from blocking to streaming (`"stream": true`). Update RewriteView to show tokens as they arrive. Better perceived latency for long rewrites.
- [ ] **Rewrite sheet keyboard shortcut.** Bind `⌘↩` to trigger Rewrite (already done in the view — verify it works). Consider adding `⌘W` to close panel.
- [ ] **Onboarding flow.** On first launch (when `hasCompletedOnboarding == false`): show a one-time sheet that explains the two hotkeys (Globe = dictate, user-assigned = silent rewrite) and offers to open Preferences to assign the silent-rewrite hotkey. Mark complete on dismiss.

---

## v2.2 — Polish

- [ ] **Wispr Dock icon.** Use the VP Rewriter's green rewrite icon as the Dock icon (currently showing AppIcon.icns which is the OpenWispr waveform). Update `bundle-app.sh` + Resources.
- [ ] **Length control.** Add LENGTH selector to the rewrite sheet: Same / Shorten / Expand. Appends length prompt from VP Rewriter's `LENGTH_PROMPTS`. Default: Same.
- [ ] **Copy Last Dictation** menu item — already present from OpenWispr, confirm it still works after the GRDB wiring.
- [ ] **Rewrite history in the sheet.** After rewriting, show a "Rewrite again" button that lets you cycle through providers or re-run with a different style without closing the panel.
- [ ] **Silent rewrite with style override.** If the hotkey is held for >1s, show the style picker as a HUD before running. Instant tap = use default style.
- [ ] **Better error states.** When Ollama is unreachable on startup, set `statusBar.state = .needsAttention("Ollama not running")`. Clear when next rewrite succeeds.

---

## v2.3 — History & Search

- [ ] **Full-text search across rewrites.** The current search only hits transcript text; extend to search rewrite content too.
- [ ] **Export.** "Export History" menu item → JSON or Markdown file with all transcripts + rewrites.
- [ ] **Day grouping in history.** Section headers by date (Today, Yesterday, older by week).
- [ ] **Rewrite comparison view.** Side-by-side diff of original transcript vs. rewrite in History viewer.

---

## v2.4 — Providers

- [ ] **GPT-5 model id.** Verify the correct GPT-5 model identifier and update `OpenAIProvider.defaultModel`. Current placeholder is `gpt-4o`.
- [ ] **Anthropic prompt caching.** Enable cache_control on the system prompt (it's long and identical per style) to cut costs on Claude runs. Worth ~80% cache hit rate after the first call.
- [ ] **Apple Intelligence on-device.** Spike: use the Apple Foundation Models API (available on macOS 15.1+ / Apple Intelligence hardware) as a fourth provider. No API key, no network. Framed as "On-device (Apple)" in the picker. See `apple/python-apple-fm-sdk` for evaluation tooling.
- [ ] **Ollama model auto-select.** On startup after probeModels(), if default model (`gemma3:4b`) isn't in availableModels, show a `needsAttention` warning with a "Pull model" action.

---

## v3.0 — Future (out of scope for v2)

- RAG / web search context for rewrites
- Multi-language dictation (models beyond `.en`)
- Cross-device sync via iCloud
- Code signing + notarization for distribution outside Homebrew
- App Store distribution
