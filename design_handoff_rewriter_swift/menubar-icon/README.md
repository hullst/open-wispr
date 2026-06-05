# Rewrite — macOS menu-bar icon

The "Rewrite" mark (squiggle → clean line + AI sparkle) packaged as a **template image**
for the macOS menu bar / status item. A template image is monochrome (black + transparency);
macOS reads only the **alpha channel** and tints it automatically — **black** on light menu
bars, **white** on dark — so you ship one file for both.

## Files
| File | Size | Use |
|---|---|---|
| `RewriteTemplate.svg` | vector | Master. SwiftUI (`Image("RewriteTemplate")`), web, or to regenerate PNGs. Uses `currentColor`. |
| `rewriteTemplate.png` | 16×16 | Menu-bar @1x |
| `rewriteTemplate@2x.png` | 32×32 | Menu-bar @2x (Retina) |
| `rewriteTemplate@3x.png` | 48×48 | @3x |
| `preview.html` | — | Shows it live on a light + dark menu bar at real size |

> ⚠️ The `@2x` / `@3x` files may have downloaded as `rewriteTemplate-2x.png` / `-3x.png`
> (a literal `@` can't be written by the exporter). **Rename them back to `@2x`/`@3x`** —
> macOS and Electron require the `@2x` suffix to pick the Retina variant.
> `mv rewriteTemplate-2x.png rewriteTemplate@2x.png` (and `-3x` → `@3x`).

## Use it — Electron (Tray)
The **`Template` suffix in the filename** makes Electron treat it as a template image
(auto light/dark). Just point `Tray` at the @1x file; it finds `@2x`/`@3x` automatically.
```js
const { Tray, nativeImage } = require('electron');
const icon = nativeImage.createFromPath('menubar-icon/rewriteTemplate.png');
const tray = new Tray(icon);            // 'Template' suffix → auto-inverts
// (or be explicit:)  icon.setTemplateImage(true);
```

## Use it — native AppKit / SwiftUI
```swift
// Add RewriteTemplate.svg (or the PNGs) to Assets.xcassets and mark
// "Render As: Template Image".
let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
item.button?.image = NSImage(named: "RewriteTemplate")
item.button?.image?.isTemplate = true   // honored automatically for *Template images
```
> Tip: for the crispest result on native, drop the **SVG into Xcode as a Single-Scale /
> Preserve-Vector asset**, or export a `RewriteTemplate.pdf` (vector PDF is Apple's
> preferred template format). Say the word and I'll generate the PDF too.

## Design
- 24×24 viewBox, optical weight tuned for 16–18px.
- Squiggle drawn at **55% alpha** (the "messy" input) over a **solid** line (the "polished"
  output); 4-point sparkle = the AI touch. Alpha is preserved in the template, so the
  squiggle stays a touch lighter than the line even after the OS tints it.
