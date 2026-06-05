# Rewriter — App Redesign Brief

A standalone Electron desktop app for rewriting garbled voice-to-text into clean prose. Runs entirely locally (Ollama + whisper.cpp). No cloud, no accounts.

---

## What to Remove (was a website, now an app)

- Page header: the "Local Tool · Ollama" eyebrow and "VP Message Rewriter" h1 title
- "Roadmap & Setup →" nav link
- Service worker registration (irrelevant in Electron)
- PWA `@media (display-mode: standalone)` override that hides the header — the header is gone entirely now

---

## Design System

**Colors (current)**
- `--bg` `#ffffff` — white background
- `--ink` `#0a0a0a` — primary text + borders
- `--ink-2` `#333` — secondary text
- `--mute` `#666` — labels, hints, placeholders
- `--line` `#e5e5e5` — subtle borders
- `--panel` `#fafafa` — surface backgrounds
- `--green` `#2a9d4e` — ready/online status dot
- `--red` `#c4392a` — error, recording state

**Typography**
- System font stack: `-apple-system, BlinkMacSystemFont, Inter, Helvetica Neue, Arial`
- Labels: 11px uppercase, 0.1em letter-spacing, 600 weight
- Body/textarea: 15px, 1.55 line-height
- Small text: 12–13px

**Style rules**
- No border-radius anywhere (square corners throughout)
- No shadows (except a subtle `box-shadow: 0 0 0 3px rgba(10,10,10,0.08)` on focus)
- Borders are either `--ink` (active/primary) or `--line` (subtle)
- Black and white only — color only for status dots (green/red) and recording state (red)

---

## Layout

Single-column, centered, max-width 720px. Top padding ~32px (was 64px when header was present). Content flows top to bottom:

```
[ Mic selector + Model status ]
[ Replying to (collapsible) ]
[ Input textarea + mic button ]
[ Style / Length dropdowns + style hint ]
[ Rewrite | Variants | Clear | Keyboard hint ]
[ Error message (conditional) ]
[ Output box ]
[ Copy | Auto-copy toggle ]
[ Variants panel (conditional, 3-col grid) ]
[ History (collapsible) ]
```

---

## Components

### 1. Mic Selector + Model Status Bar
A single row at the top with two items:

**Left:** `Mic` dropdown — lists available audio input devices. Default label "Default Microphone". Styled like all other selects (black border, custom arrow).

**Right:** Model status indicator — a colored dot + text label showing the current Ollama model name and connection state.
- Green dot + model name (e.g. "gemma2:9b") = ready
- Pulsing gray dot + "Generating..." = busy
- Red dot + "Offline" / "Connection failed" = error

---

### 2. Replying To (collapsible)
Collapsed by default. A clickable label "Replying to" with a down-arrow toggle. When expanded:
- Textarea for pasting the message being replied to
- Hint text: "Optional. Helps the model write a direct reply instead of a standalone message."
- Badge "· active" appears in the toggle label when the field has content

---

### 3. Input

Label row: `INPUT` (uppercase, muted) · character count (right-aligned, e.g. "142 chars")

**Recording indicator** (shown only during recording): Live waveform canvas (10 animated bars, red, bell-curve envelope) + "Recording" label + timer (e.g. "0:23"). Transitions to just a label during transcription.

**Textarea** with mic button inset top-right:
- Placeholder: "Paste your garbled voice-to-text here... or click the mic to dictate"
- Resizable, min-height 140px
- Left border turns red (3px) during active recording
- Bottom border pulses during transcription

**Mic button** (36×36, inset inside textarea):
- Default: mic icon, muted color, subtle border
- Recording: red fill, stop icon (square)
- Transcribing: pulsing opacity, wait cursor

---

### 4. Rewrite Controls

Two dropdowns side by side, each with an uppercase label above:

**Style dropdown**
- Informal (Everyday) ← default
- Casual (Slack)
- Text (iMessage)
- Formal (Customer / Co-Wide)
- [custom styles appear here if saved]

Next to the Style dropdown: a `+` icon button (34×34) to open the custom style modal. A trash icon button appears when a custom style is selected.

**Length dropdown**
- Same Length ← default
- Shorten
- Expand

Below the dropdowns: a **style hint** — 1-line italic description of the selected style (e.g. "Everyday internal messages -- warm, direct, uses contractions and ellipses").

---

### 5. Action Row

Three buttons + keyboard hint:

- **Rewrite** — primary (black fill, white text). Disabled + "Rewriting..." label during generation.
- **Variants** — secondary (white fill, black border). Disabled until a rewrite has been completed.
- **Clear** — ghost (no border, muted text).

Right side: a `?` circle button that toggles inline keyboard shortcut hints:
- `⌘ Enter` rewrite
- `⌘ Shift C` copy
- `⌘ Shift M` mic

---

### 6. Error Message (conditional)
Hidden by default. When shown: left-bordered panel (2px `--ink`) in `--panel` background. 13px text. Shows Ollama connection errors, whisper errors, mic permission errors.

---

### 7. Output

Label row: `OUTPUT` (uppercase, muted) · generation time (right-aligned, e.g. "3.2s") when populated.

**Output box:**
- `--panel` background, subtle border
- Min-height 100px, `pre-wrap` whitespace
- Empty state: muted italic "Clean version will appear here..."
- During streaming: bottom border pulses (solid ink → line color animation)

**Output action row (below box):**
- **Copy** button — secondary, disabled until output exists
- **Auto-copy** checkbox toggle — right-aligned, "Auto-copy" label. Checked by default. When on, copies to clipboard automatically after each rewrite and shows a toast.

---

### 8. Variants Panel (conditional)

Hidden until "Variants" is clicked. Shows above History.

Header: `VARIANTS` label + "Close" ghost button.

**3-column grid** of variant cards. Each card:
- Uppercase label: "Conservative (t=0.15)", "Balanced (t=0.4)", "Creative (t=0.7)"
- Text body (loading state: muted italic "Generating...")
- "Click to use" label appears on hover
- Clicking a card copies its text to the output box and highlights the card with a 2px border

All 3 variants generate in parallel. Clicking one updates the output and shows a toast.

---

### 9. Custom Style Modal

Triggered by the `+` button next to the Style dropdown. Full-screen overlay (dark scrim), centered panel with a `1px solid --ink` border.

Fields:
- **Name** — text input (e.g. "Board Summary")
- **Hint** — text input (short description shown below the dropdown)
- **Style Prompt** — textarea (instructions to the model, e.g. "Style: Board Summary\n- Executive audience...")

Hint text below prompt field: "Written as instructions to the model. Start with 'Style: Name' then bullet the rules."

Actions: Cancel (ghost) | Save Style (primary).

---

### 10. History (collapsible)

Separated from the main content by a top border. Collapsed by default.

**Header row (clickable):** `HISTORY (n)` with down-arrow toggle. Right side: Export + Clear All buttons (ghost, small).

**History list** (when expanded, max-height 500px, scrollable):

Each history item is a clickable card (`--panel` background, subtle border → ink on hover):
- Meta row: timestamp (e.g. "Jun 4, 2:14 PM") · mic icon if voice-recorded · style badge · model badge
- Input preview (2 lines, truncated)
- Dashed divider
- Output preview (3 lines, truncated)

Clicking a card reloads the input + output into the editor.

Empty state: muted italic "No rewrites yet"

Export produces a CSV file with all entries. Clear All prompts confirmation.

---

## Toast Notifications

Fixed, centered, bottom of screen. Black pill with white text. Slides up, fades in on show, fades out after 2s. Messages:
- "Copied to clipboard"
- "Auto-copied to clipboard"
- "Transcribed in 2.1s"
- "Style saved"
- "Style deleted"
- "Variant applied"
- "Loaded from history"
- "History exported"

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘ Enter` | Rewrite |
| `⌘ Shift C` | Copy output |
| `⌘ Shift M` | Toggle mic recording |
| `⌘ K` | Clear all |

---

## States to Design

| State | Where |
|---|---|
| Empty (fresh launch) | Input empty, output placeholder, buttons disabled |
| Input typed, not yet rewritten | Rewrite enabled, Variants disabled |
| Rewriting (streaming) | Button → "Rewriting...", output box pulsing border |
| Output ready | Copy + Variants enabled, timing shown |
| Recording | Red mic button, red left border on input, live waveform |
| Transcribing | Pulsing mic button, "Transcribing..." placeholder |
| Ollama offline | Red status dot, "Offline", Rewrite button still enabled (will error on click) |
| Variants open | 3-col card grid visible below output |
| Custom style modal open | Overlay + centered form |
| History expanded | Scrollable card list |
