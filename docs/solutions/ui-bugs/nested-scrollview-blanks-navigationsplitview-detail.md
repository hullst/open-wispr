---
title: Nested fixed-height ScrollView blanks the entire NavigationSplitView in SwiftUI Preferences
date: 2026-06-15
category: docs/solutions/ui-bugs
module: wispr/preferences
problem_type: ui_bug
component: rails_view
severity: medium
symptoms:
  - "Entire Preferences window goes blank white — both sidebar list and detail pane"
  - "Window becomes unrecoverable; cannot switch to other Preferences sections"
  - "App process stays alive; no crash report generated"
  - "Diagnostic print confirms the pane's onAppear work ran fine, ruling out a main-thread stall or data error"
root_cause: logic_error
resolution_type: code_fix
related_components:
  - PreferencesView
  - RewriteService
tags:
  - swiftui
  - navigationsplitview
  - scrollview
  - layout-collapse
  - preferences
  - macos
---

# Nested fixed-height ScrollView blanks the entire NavigationSplitView in SwiftUI Preferences

> Note: `component: rails_view` is a stand-in for "SwiftUI view layer" — the schema's component enum predates non-Rails projects and has no SwiftUI/AppKit value. `rails_view` is the only view-layer bucket.

## Problem
Adding a new "Voice" pane to the Wispr Preferences `NavigationSplitView` blanked the entire window — both the sidebar and the detail pane rendered solid white and stayed unrecoverable. The app process kept running with no crash log, so it read as catastrophic but was actually a layout failure.

## Symptoms
- Selecting the Voice tab painted the whole Preferences window white — sidebar included, not just the detail pane.
- The window never recovered; no way to navigate to other sections.
- App process stayed alive; no crash report was generated.
- The other panes (`generalSection`, `rewriterSection`) rendered fine.

## What Didn't Work
The first hypothesis was a main-thread stall: `voiceSection`'s `.onAppear` called `VoiceProfileSynthesizer.synthesize()`, which performs a GRDB SQLite read, synchronously on the main thread. The theory was that the blocking read starved the UI and left the window unpainted.

Fix attempted — move synthesis off the main thread:

```swift
.onAppear {
    Task.detached(priority: .userInitiated) {
        let profile = VoiceProfileSynthesizer.synthesize()   // GRDB read
        await MainActor.run { self.voiceProfile = profile }   // state update
    }
}
```

This did **not** fix the blank. A diagnostic `print` added inside the detached task then logged:

```
VoiceProfile: synthesizing…
VoiceProfile: done (1 edits)
```

The synthesis completed cleanly and the state update ran. That completing print was the key signal: it ruled out both a main-thread stall and a crash/hang in the data path. The blank had to be a **layout** problem, not a data or concurrency problem. (The async change was kept anyway as correct hygiene — it just wasn't the root cause.)

## Solution
The only structural difference between `voiceSection` and the working panes was the layout: the working panes used `Form { ... }.formStyle(.grouped)`, while `voiceSection` was a raw `VStack` containing a nested **fixed-height `ScrollView`** (`.frame(height: 150)`). Rebuilding the pane as a `Form` — and dropping the nested fixed-height ScrollView — fixed it.

Before:

```swift
var voiceSection: some View {
    VStack(alignment: .leading, spacing: 14) {
        Text(desc)
        HStack { /* ...edits count... */ }
        Text("Preview")
        ScrollView {
            Text(profilePreview)
                .textSelection(.enabled)
        }
        .frame(height: 150)                 // nested fixed-height ScrollView — the trap
        HStack { Button("Export…") { exportVoiceProfile() } }
    }
    .padding(16)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .onAppear { refreshVoiceProfile() }
}
```

After:

```swift
var voiceSection: some View {
    Form {
        SwiftUI.Section {
            Text(desc)
            LabeledContent("Edits captured") { Text("\(profileEditCount)") }
        }
        SwiftUI.Section("Preview — exactly what leaves the machine") {
            Text(profileEditCount == 0 ? "No edits…" : profilePreview)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
        }
        SwiftUI.Section {
            HStack {
                Button("Export…") { exportVoiceProfile() }
                    .disabled(profileEditCount == 0)
            }
        }
    }
    .formStyle(.grouped)
    .padding(.top, 4)
    .onAppear { refreshVoiceProfile() }
}
```

### Secondary fix: `SwiftUI.Section` name collision
The view declared its sidebar tabs with `enum Section: String, CaseIterable { ... }`, which **shadowed SwiftUI's own `Section`**. Inside the `Form`, a bare `Section { }` resolved to the enum rather than the SwiftUI view, producing misleading compiler errors that pointed nowhere near the real cause:

- `trailing closure passed to parameter of type 'FormStyleConfiguration' that does not accept a closure`
- `referencing initializer 'init(codingKey:)' ... requires that 'PreferencesView.Section' conform to 'CodingKeyRepresentable'`

The fix was to fully qualify every section inside the `Form` as `SwiftUI.Section`, leaving the local `Section` enum free to keep its name for the sidebar tabs.

## Why This Works
Root cause: a nested fixed-height `ScrollView` (`.frame(height: 150)`) placed inside a size-constrained `NavigationSplitView` detail — whose ancestor pinned the window to `.frame(width: 560, height: 360)` — collapses the split-view layout. When SwiftUI resolves the conflicting size constraints (a fixed inner scroll height fighting a fixed outer window frame across the split-view boundary), the layout degenerates and blanks the *whole* `NavigationSplitView`, sidebar included — not just the offending detail pane. That blast radius is why it looked like a crash rather than a localized glitch.

`Form { ... }.formStyle(.grouped)` avoids this because the grouped form manages its own internal scrolling and negotiates a flexible size with its container. There is no hard-coded inner scroll height fighting the outer window frame, so the split view resolves its layout normally.

## Prevention
- **Prefer `Form { ... }.formStyle(.grouped)` for `NavigationSplitView` detail panes.** It's the pattern the working panes already used — match it for consistent, free scrolling and sizing.
- **Avoid nested fixed-height `ScrollView`s inside size-constrained detail panes.** A `.frame(height:)` on an inner `ScrollView` living under a fixed outer window frame is the trap. Let the `Form`/`List` own scrolling, or use a flexible (`maxHeight:`) constraint if an inner scroll region is genuinely needed.
- **Watch for type-name collisions with SwiftUI types.** A local `enum Section` (or `Group`, `Text`, `List`, etc.) silently shadows the SwiftUI view and surfaces as bizarre, misdirecting compiler errors (`FormStyleConfiguration`, `CodingKeyRepresentable`). When the errors don't match the code you wrote, suspect shadowing and qualify with `SwiftUI.` (or rename the local type).
- **Debugging heuristic: a `print` that runs to completion rules out the data/concurrency path.** If your diagnostic log fires and the async work finishes but the UI is still broken, stop chasing threading/data and look at layout. A completed print is strong evidence the problem is in view composition, not in the work the view triggers.

## Related Issues
- `docs/solutions/tooling-decisions/swift-macro-plugins-require-xcode-not-cli.md` — the only other SwiftUI-adjacent doc in this repo (build-toolchain, not runtime layout); listed only as a topical neighbor.
