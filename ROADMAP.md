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

## v2.1 — Voice Quality & Polish ✓ shipped

- [x] **Native floating panel** — vibrancy, borderless, rounded corners, auto-sizing height animation
- [x] **Result animation** — source fades to 45%, result slides in with spring physics
- [x] **Word-level diff** — "What changed?" toggle, LCS algorithm, strikethrough + highlight
- [x] **AI linter** — post-rewrite check against banned word list, yellow warning in card
- [x] **Variants chip** — compact pill button instead of full button
- [x] **Onboarding** — first launch modal, one-time
- [x] **Startup error states** — Ollama unreachable or model missing → needsAttention in menu bar
- [x] **Anthropic prompt caching** — `cache_control: ephemeral` on system prompt (~80% cost reduction)
- [x] **Hold-to-talk only** — toggle mode removed
- [x] **Prompt quality fix** — hard stop, input wrapper, temperature 0.3

- [ ] **Evaluate Gemma 3 4B as local default.** Run against `gemma3:4b` — smaller, faster. Only switch if voice-preservation is equal or better. `ollama pull gemma3:4b`, compare 10 real dictations in everyday style.
- [ ] **Stream Ollama responses.** `"stream": true`, token-by-token display in result card. Better perceived latency for longer rewrites.
- [ ] **⌘W to close panel.** Currently only escapable by clicking outside. Add keyboard dismiss.

---

## v2.2 — History & Export

- [ ] **Full-text search across rewrites.** Current search only hits transcript text; extend to rewrite content.
- [ ] **Export history.** Menu item → JSON or Markdown with all transcripts + rewrites.
- [ ] **Day grouping in History viewer.** Section headers: Today, Yesterday, by week.
- [ ] **Wispr Dock icon.** Use VP Rewriter green icon for the Dock. Update `bundle-app.sh` + Resources.
- [ ] **Silent rewrite style override.** Hold hotkey >1s → style picker HUD. Instant tap = default style.
- [ ] **Rewrite-again in sheet.** Button to re-run with different style/provider without clearing the panel.

---

## v2.3 — Providers

- [ ] **GPT-5 model id.** Verify exact model identifier, update `OpenAIProvider.defaultModel` from `gpt-4o`.
- [ ] **Apple Intelligence on-device.** Spike: use the Apple Foundation Models API (available on macOS 15.1+ / Apple Intelligence hardware) as a fourth provider. No API key, no network. Framed as "On-device (Apple)" in the picker. See `apple/python-apple-fm-sdk` for evaluation tooling.
- [ ] **Ollama model auto-select.** On startup after probeModels(), if default model (`gemma3:4b`) isn't in availableModels, show a `needsAttention` warning with a "Pull model" action.

---

## v3.0 — Future (out of scope for v2)

- RAG / web search context for rewrites
- Multi-language dictation (models beyond `.en`)
- Cross-device sync via iCloud
- Code signing + notarization for distribution outside Homebrew
- App Store distribution
