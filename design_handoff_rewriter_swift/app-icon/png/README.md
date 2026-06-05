# Rewriter — App Icon (Transform)

Production PNGs for the macOS app icon, concept **#4 · Transform** (ink background,
squiggle → clean line, blue AI sparkle).

## Folders
- `Rewriter.iconset/` — Apple iconset (all required sizes incl. Retina @2x).
- `app-icon-png/` — flat, friendly-named copies (`Transform-16.png` … `Transform-1024.png`)
  for Figma, the web build, Electron `BrowserWindow` icons, etc.

## Build the .icns (macOS)
```bash
chmod +x build-icon.sh
./build-icon.sh        # fixes @2x names + runs iconutil → Rewriter.icns
```

## Electron
Point your build config at the compiled icon:
```js
// electron-builder (package.json → "build")
"mac": { "icon": "Rewriter.icns" }
// or a BrowserWindow: icon: 'app-icon-png/Transform-512.png'
```

Sizes included: 16, 32, 64, 128, 256, 512, 1024 px (1x + 2x).
