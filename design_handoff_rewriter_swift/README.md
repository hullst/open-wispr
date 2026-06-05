# Handoff: Rewriter — macOS app (SwiftUI / AppKit)

## Overview
Rewriter is a standalone, fully-local macOS app that turns garbled voice-to-text into clean, polished prose (local LLM via Ollama + on-device transcription). No cloud, no accounts. This package is the **visual redesign**, re-specified for **native Swift**.

Pairs with **`REDESIGN-BRIEF.md`** (functional spec — components, behavior, states, shortcuts, toasts) and the HTML/React design references in **`design-references/`**. This README is the **visual + platform spec for Swift**. Where the brief describes a square / monochrome look, **it is superseded** by the approved redesign documented here (rounded, one blue accent, light + dark, SF Pro).

## About the design files
`design-references/` are **HTML/React-via-Babel prototypes** showing the intended look and behavior. They are **not code to port** — the canvas, the fake macOS window chrome, and the CDN/Babel setup are presentation scaffolding only. **Recreate the UI natively in SwiftUI** (drop to AppKit only where noted). Pull exact values from this README + `Tokens.swift`; pull behavior/copy/state from `REDESIGN-BRIEF.md`.

## Recommended framework
**SwiftUI**, targeting a recent macOS. The layout is a `VStack` of sections — a near 1:1 port. Use AppKit (`NSViewRepresentable`) only if a control needs behavior SwiftUI can't reach (unlikely here). The content column is **max-width 600px**, centered; the window chrome (traffic lights, titlebar) is OS-provided — build only the content area.

---

## Color → Asset Catalog
Define **one color set per token** in `Assets.xcassets`, each with **Any Appearance + Dark Appearance**, so the OS swaps automatically — never branch on `colorScheme` for palette. Hex values for both appearances are in `Tokens.swift` (and the table below). `Tokens.swift` also gives a code-only fallback for prototyping.

| Token | Light | Dark |
|---|---|---|
| `AppBg` | `#FFFFFF` | `#1C1C1E` |
| `Surface` | `#FFFFFF` | `#242426` |
| `InputBg` | `#FFFFFF` | `#212123` |
| `Panel` | `#F5F5F7` | `#2C2C2E` |
| `PanelSoft` | `#FAFAFA` | `#202022` |
| `Border` | `#000` @ 8% | `#FFF` @ 10% |
| `BorderMid` | `#000` @ 13% | `#FFF` @ 16% |
| `Hair` | `#000` @ 6% | `#FFF` @ 7% |
| `Text` | `#1D1D1F` | `#F5F5F7` |
| `Text2` | `#6E6E73` | `#A1A1A6` |
| `Text3` | `#9B9BA1` | `#6E6E73` |
| `Accent` | `#0A6CFF` | `#0A6CFF` |
| `AccentSoft` | `#0A6CFF` @ 10% | `#0A6CFF` @ 22% |
| `AccentLine` | `#0A6CFF` @ 35% | `#0A6CFF` @ 50% |
| `Online` | `#30D158` | `#30D158` |
| `Recording` | `#FF453A` | `#FF453A` |

> Set the app **accent color** to `Accent` in the target settings so system focus rings / selection match. Default `.tint(Color("Accent"))` on the root.

## Typography
SF Pro **is** the system font — use system text styles; they already match our scale and give Dynamic Type + optical sizing for free. Reach for explicit sizes only where we diverge. Mono (`.monospaced`) for char counts, model name, timers, timing, and `⌘↵` hints — SF Mono ships with the OS.

| Role | SwiftUI | Notes |
|---|---|---|
| Output | `.system(size: 15)` | lineSpacing ≈ 6 |
| Body / input | `.system(size: 14.5)` | lineSpacing ≈ 5 |
| Control / button | `.system(size: 13.5, weight: .semibold)` | tracking −0.1 |
| Section label | `.system(size: 10.5, weight: .semibold)` | `.textCase(.uppercase)` + `.tracking(0.9)`, color `Text3` |
| Badge | `.system(size: 10, weight: .semibold)` | uppercase |
| Mono detail | `.system(size: 12, design: .monospaced)` | counts, `⌘↵`, `gemma2:9b`, `3.2s` |

## Radius / shadow / spacing
Radii in `Tokens.swift` (`Radii`). Cards/input/output **12**, controls **9**, active segment pill **7**, pills **8**, badges **5**, toast **capsule**. Apply via `.clipShape(RoundedRectangle(cornerRadius:style:.continuous))` — use **`.continuous`** for Apple's squircle curvature.
- Primary button: fill `Accent`, `.shadow(color: accent@35%, radius: 1, y: 1)`.
- Cards / input (light): hairline `Border`/`BorderMid` via `.overlay(RoundedRectangle().stroke(...))`; skip soft shadows in dark.
- Toast: `.shadow(color: .black.opacity(0.22), radius: 12, y: 8)`.
- Content padding **22 top / 28 sides**; section gap **18–20**; label→control **9**; button row **10**; card grid **10**.

---

## Controls → native mappings
| Our control | SwiftUI |
|---|---|
| Length (Shorter · Same · Longer) | `Picker(...) { … }.pickerStyle(.segmented)` |
| Style dropdown | `Menu` or `Picker(.menu)` with the style list + custom styles |
| `+` add custom style | trailing `Button` w/ SF Symbol `plus`, opens the sheet |
| Auto-copy | `Toggle` (style as a checkbox row, label trailing) |
| Rewrite / Variants / Clear | `Button` w/ custom `ButtonStyle` (primary/secondary/ghost — see specs) |
| `?` help | `Button` + `.help("…")` for the tooltip; reveals shortcuts inline |
| Input field | `TextEditor` (min height 92) with placeholder overlay |
| Replying-to | `DisclosureGroup` or custom collapsible |
| Custom-style editor | `.sheet { … }` |
| Toasts | overlay `Capsule` at bottom, `.transition(.move(edge:.bottom).combined(with:.opacity))`, auto-dismiss 2s |
| Model status / mic selector | `HStack` in the header; mic selector = `Menu` |

**Materials:** use real `.regularMaterial` for the modal scrim/blur and (if you add one) the menu-bar popover — replaces the CSS `backdrop-filter` in the mocks. Keep it restrained to match the minimal direction; Liquid Glass on the latest OS is optional and easy to overdo.

**Window vs. menu bar:** SwiftUI's **`MenuBarExtra`** makes a "click the menu-bar icon → popover holding the whole Column" pattern trivial. Strong fit for a quick-rewrite tool — consider it as the primary surface with the full `Window` optional. The menu-bar icon is ready (see Assets).

---

## Iconography → SF Symbols + custom
Most utility glyphs map to **SF Symbols** (auto-weight, auto-align to text, free light/dark). Use `Image(systemName:)` with `.font()`/`.symbolRenderingMode(.monochrome)` tinted `Text`/`Text2`. The **Rewrite mark and the app icon stay custom** — there is no SF Symbol for "squiggle → clean line".

| In-app use | SF Symbol | Notes |
|---|---|---|
| Mic / dictation | `mic` / `mic.fill` | `.fill` while recording |
| Recording (stop) | `stop.fill` | inside the red circle |
| Waveform / level | `waveform` | live input meter |
| **Rewrite** | **custom** | `RewriteTemplate.pdf` / SF-Symbol-style custom symbol |
| Variants | `sparkles` | |
| Copy | `doc.on.doc` | |
| Success / done | `checkmark` / `checkmark.circle.fill` | |
| Reply / context | `arrowshape.turn.up.left` | |
| History | `clock` / `clock.arrow.circlepath` | |
| Export | `square.and.arrow.up` (share) or `arrow.down.circle` | pick per behavior |
| Send | `paperplane` | |
| Undo | `arrow.uturn.backward` | |
| Clear / delete | `trash` | |
| Help | `questionmark.circle` | pair with `.help()` |
| Settings | `gearshape` | |
| Light / Dark toggle | `sun.max` / `moon` | |
| Add custom style | `plus` | |
| Menu-bar status item | **custom** | `RewriteTemplate.pdf` as template image |

> **Best practice:** make the Rewrite mark a **custom SF Symbol** — open `RewriteTemplate.svg` in Apple's *SF Symbols* app → "Import Custom Symbol" → name it `rewrite.mark`. Then it behaves like any system symbol: `Image("rewrite.mark")`, auto-scales with text, inherits weight/color. The PDF is the fallback if you'd rather drop a vector asset straight into the catalog.

## Motion (SwiftUI)
| Element | Animation |
|---|---|
| Generating status dot | opacity 1→0.25, `.easeInOut(1.1).repeatForever()` |
| Recording equalizer | 5 bars `scaleEffect(y:)` 0.4↔1, 0.8s repeatForever, stagger `i*0.12` |
| Recording / streaming caret | blink 1s `.repeatForever(autoreverses:false)` |
| Transcribing mic | opacity pulse 1.1s |
| Rewrite spinner | `ProgressView().controlSize(.small)` (native) or rotate 0.8s linear |
| Output streaming border | animate bottom-edge accent alpha 0.15↔0.7, 1.2s |
| Toast | move(.bottom)+opacity in; dismiss after 2s |
| Disclosure chevrons | rotate 180° |

SwiftUI honors **Reduce Motion** automatically when you use `.animation` with `accessibilityReduceMotion`-gated values — drop loops and show end states.

## Keyboard shortcuts
`⌘↵` Rewrite · `⌘⇧C` Copy · `⌘⇧M` Toggle recording · `⌘K` Clear. Wire via `.keyboardShortcut(...)` on the buttons / `Commands`. The `?` button reveals these inline.

## State
`@Observable` model: `inputText`, `replyingTo` + open flag, `style` + custom styles, `length`, `output`, `generationTime`, `status (.ready/.generating/.offline)`, recording/transcribing flags + timer, `variants` + selected, `history`, `autoCopy`, `modalOpen`, active `toast`. See the "States to Design" table in `REDESIGN-BRIEF.md`.

---

## Assets
- **App icon** — `app-icon/` : `Rewriter.iconset/` (16→1024, 1×/2×) + flat `png/`. macOS app icons are **raster PNG** (Asset Catalog `AppIcon`, or Apple's *Icon Composer* for the latest OS) — **PNG is correct here, not vector**. Concept #4 "Transform": ink squircle, squiggle→clean-line, blue sparkle. (The Electron `build-icon.sh`/`.icns` step is irrelevant for native — just add the PNGs to the `AppIcon` set.)
- **Rewrite mark / menu-bar** — `menubar-icon/` : **`RewriteTemplate.pdf`** (vector — preferred for Asset Catalog template image, scales crisply), `RewriteTemplate.svg` (for the *SF Symbols* app → custom symbol), and template PNGs `@1x/2x/3x`. Drawn as a **template image** (black + alpha) so the OS tints it black/white per appearance — set **Render As: Template Image** in the catalog. For `MenuBarExtra`, pass it as the label image.
- **In-app glyphs** — prefer **SF Symbols** per the table above; only the Rewrite mark is custom.

## Files
`Tokens.swift` — Color / Font / Radii in Swift (paste in, or use as the catalog reference).
`design-references/` — `VP Rewriter - States.html` (primary), `VP Rewriter - Icons.html`, plus source `screen.jsx` / `chrome.jsx` (read for exact values). `design-canvas.jsx` + window chrome = scaffolding, don't port.
`REDESIGN-BRIEF.md` — functional spec.
`app-icon/`, `menubar-icon/` — assets above.
