---
title: Swift macro plugins require Xcode.app toolchain — not available with swift build CLI
date: 2026-06-05
category: docs/solutions/tooling-decisions
module: tooling
problem_type: tooling_decision
component: development_workflow
severity: high
applies_when:
  - Building a Swift SPM project with `swift build` from the CLI (not xcodebuild)
  - Considering SwiftData for persistence in a CLI-built app
  - Considering sindresorhus/KeyboardShortcuts or any SPM package that uses #Preview
  - Error contains "could not be found for macro" and "plugin for module ... not found"
symptoms:
  - "external macro implementation type 'SwiftDataMacros.PersistentModelMacro' could not be found for macro 'Model()'; plugin for module 'SwiftDataMacros' not found"
  - "external macro implementation type 'PreviewsMacros.SwiftUIView' could not be found for macro 'Preview(_:body:)'; plugin for module 'PreviewsMacros' not found"
  - "error: emit-module command failed with exit code 1"
root_cause: missing_tooling
resolution_type: dependency_update
tags:
  - swift
  - spm
  - swift-build
  - cli-build
  - xcode-macros
  - swiftdata
  - grdb
  - keyboard-shortcuts
  - macro-plugins
  - commandlinetools
---

# Swift macro plugins require Xcode.app toolchain — not available with swift build CLI

## Context

Building Wispr (a Swift SPM macOS app at `~/Documents/Claude/Projects/Wispr/`) using the REBUILD script, which calls `swift build -c release`. The active toolchain was CommandLineTools (`xcode-select -p` → `/Library/Developer/CommandLineTools`). Two separate attempts to add SPM dependencies failed with identical-looking errors:

1. Adding **SwiftData** (`@Model` macro) for persistence
2. Adding **sindresorhus/KeyboardShortcuts** for hotkey recording (failed in both v2.x and v1.x)

Both errors had the same shape — "macro plugin not found" — and were initially mistaken for build configuration issues. No amount of `rm -rf .build` or `-c release` flags fixed them. The cause was purely about the toolchain.

## Guidance

**Any SPM package or Apple framework that uses Swift macro annotations (`@Model`, `#Preview`, `@freestanding`, `@attached`) will fail to compile with `swift build` when CommandLineTools is the active toolchain.**

Macro plugins (`SwiftDataMacros`, `PreviewsMacros`, etc.) are compiled into `Xcode.app`'s toolchain. They are not included in CommandLineTools. This affects:

- First-party: SwiftData (`@Model`, `@Attribute`, `@Relationship`)
- Third-party: Any SPM package whose source contains `#Preview` macros (e.g., KeyboardShortcuts — version pinning to 1.x or 2.x makes no difference; both contain `#Preview`)
- Any future package using Swift's macro system

**Two fixes:**

**Option A — Switch to Xcode toolchain (if Xcode.app is installed):**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
swift build -c release  # now has access to macro plugins
```

**Option B — Eliminate macro dependencies (preferred for REBUILD-style CLI builds):**

For persistence: replace SwiftData with **GRDB**. For user-assignable hotkeys: replace KeyboardShortcuts with a native **NSEvent** monitor.

### Fix 1: GRDB instead of SwiftData

Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
],
targets: [
    .target(
        name: "WisprLib",
        dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
    )
]
```

Models — plain structs, no macros:

```swift
import GRDB

// Before (fails with CommandLineTools):
// @Model class Transcript { var id: UUID; var text: String }

// After (compiles anywhere):
struct Transcript: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var text: String
    var source: String
    var createdAt: Date

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
```

Migration (explicit SQL — no magic):

```swift
var migrator = DatabaseMigrator()
migrator.registerMigration("v1") { db in
    try db.create(table: "transcripts") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("text", .text).notNull()
        t.column("source", .text).notNull()
        t.column("createdAt", .datetime).notNull()
    }
}
try migrator.migrate(db)
```

### Fix 2: Native NSEvent hotkey instead of KeyboardShortcuts SPM

```swift
// Before (fails — KeyboardShortcuts uses #Preview in both v1.x and v2.x):
// .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0")

// After — native NSEvent, no dependency:
final class RewriteHotkeyManager {
    private var monitor: Any?

    // Store combo in UserDefaults (keyCode + modifierFlags rawValue)
    func start(onFire: @escaping () -> Void) {
        guard let combo = HotkeyCombo.load() else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == combo.keyCode else { return }
            let required = combo.modifiers.intersection([.command, .option, .shift, .control])
            let current = event.modifierFlags.intersection([.command, .option, .shift, .control])
            guard current == required else { return }
            onFire()
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }
}
```

Recording a hotkey in a preferences view:

```swift
// In an NSView subclass or NSViewRepresentable:
override func keyDown(with event: NSEvent) {
    guard isRecording else { return }
    let combo = HotkeyCombo(
        keyCode: event.keyCode,
        modifiers: event.modifierFlags.intersection([.command, .option, .shift, .control])
    )
    combo.save()           // writes to UserDefaults
    isRecording = false
    RewriteHotkeyManager.shared.reload()
}
```

## Why This Matters

The error messages ("macro plugin not found") look like build configuration issues. A developer will naturally try `rm -rf .build`, change build flags, or pin to older package versions — none of which help. The real issue is a toolchain gap that can only be fixed by either switching toolchains or eliminating the macro dependency. Knowing this upfront saves hours of debugging.

GRDB and native NSEvent are also better long-term choices for a CLI-built app:
- GRDB is explicit (migrations are real SQL, no hidden schema management), portable (no Apple-framework lock-in), and battle-tested
- Native NSEvent follows the existing `HotkeyManager` pattern already in the codebase and adds zero SPM dependencies

## When to Apply

- `xcode-select -p` returns a path under `/Library/Developer/CommandLineTools`
- Build script calls `swift build` (not `xcodebuild`)
- Error message contains: "could not be found for macro" + "plugin for module ... not found"
- Adding SwiftData, KeyboardShortcuts, or any SPM package that uses `@Model`, `#Preview`, or other Swift macros

## Examples

Diagnostic — confirm the toolchain issue:

```bash
xcode-select -p
# /Library/Developer/CommandLineTools  ← macro plugins NOT available
# /Applications/Xcode.app/Contents/Developer  ← macro plugins available

swift --version
# Should show "Apple Swift version 6.x" either way — version alone doesn't tell you
```

Quick switch if Xcode is installed and macros are needed:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

## Related

- `~/Documents/Claude/Projects/Wispr/CHANGELOG.md` — GRDB decision documented in v2.0.0 entry
- [GRDB.swift](https://github.com/groue/GRDB.swift) — the macro-free SQLite library
- [Apple Swift Macros documentation](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/macros/) — explains how macro plugins work
