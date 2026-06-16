---
title: "Cancel known corrections before learning from edit diffs — normalize both sides first"
date: 2026-06-16
category: design-patterns
module: VoiceProfile
problem_type: design_pattern
component: assistant
severity: high
applies_when:
  - "A learning or analytics loop diffs machine output against user-edited output to infer intent or style"
  - "Two distinct edit classes share one edit surface (e.g. transcription corrections vs. genuine style rewrites) and must not be conflated"
  - "A known, deterministic correction map exists that should cancel out before semantic comparison"
  - "Corrections must apply retroactively so past data stops polluting the moment a rule is added"
tags:
  - voice-profile
  - learning-signal
  - diff-normalization
  - canonicalize-before-compare
  - personal-dictionary
  - signal-contamination
  - swift
  - privacy
---

# Cancel known corrections before learning from edit diffs — normalize both sides first

## Context

Wispr has a compounding voice-learning loop. When the user edits an AI rewrite before pasting, `VoiceProfile.synthesize()` ([Sources/OpenWisprLib/VoiceProfile.swift](../../../Sources/OpenWisprLib/VoiceProfile.swift)) diffs the AI's original text against the user's edited text and learns *style* patterns: which AI-tell words they delete, how much they shorten, their punctuation habits (em-dashes out, ellipses in), whether they cut opening/closing sentences. That signal is content-free and feeds the product's #1 goal — never sound AI ([[voice-never-sound-ai]]).

The capture layer this depends on was built in an earlier session: an `editedText` column on `WisprRewrite`, written when the user clicks Copy/Insert, with three signal states — `NULL` (auto-pasted, no review), `== rewrittenText` (accepted as-is, a *success* signal), and `!= rewrittenText` (a *correction* signal). That session deliberately did **not** normalize the diff through any dictionary before comparing — the gap this doc closes. (session history)

Then a **personal dictionary** was added that corrects Whisper's misheard proper nouns ("Carrie" → "Keri") via `TextPolisher.applyDictionary` — a whole-word, case-insensitive, longest-key-first replacement. This created a contamination risk: if the user fixes a misheard name *inside* a rewrite they're editing, the voice loop sees "Carrie" on the AI side and "Keri" on theirs and learns a bogus style rule — "this user replaces Carrie with Keri." A **transcription correction** masquerades as a **voice/style edit**.

The root issue is general: **one user action (editing-and-pasting) emits two different kinds of signal**, and a naive diff conflates them.

## Guidance

When a single user action produces two kinds of signal and only one belongs in your learning model, there are two clean options, in order of preference:

1. **Cancel the known signal before learning.** If the unwanted signal is *attributable* — you can name exactly what it was — subtract it by normalizing **both sides** of the diff through the same transformation, then compare. Whatever cancels was the known correction; whatever survives is the genuine signal.
2. **Separate the signals at the source.** Capture each kind through its own dedicated path (here, a personal-dictionary entry) so the two never enter the same diff in the first place.

Wispr uses both together: the cancellation is the contamination guard; the capture UX populates the map the guard relies on.

The cancellation, in `synthesize()`:

```swift
let dictionary = Config.load().dictionary ?? [:]
for r in rows {
    let ai   = TextPolisher.applyDictionary(r.rewrittenText, dictionary)
    let mine = TextPolisher.applyDictionary(r.editedText ?? "", dictionary)
    // ...diff ai vs mine exactly as before...
}
```

Because the dictionary maps wrong→right, applying it to the AI text turns "Carrie" into "Keri", while the user's already-correct "Keri" stays "Keri". The two sides become identical at that word and the edit cancels — it never reaches the banned-word counts, the length delta, or the uncategorized-reword bucket. Only genuine rewordings survive.

Three properties make this clean:

- **Reuse the live transform, don't reimplement it.** `TextPolisher.applyDictionary` was made `public` specifically so the learning loop applies the *exact same* normalization the paste pipeline applies. A second, drifting copy of the rule would reintroduce the bug it was meant to kill.
- **Normalize both sides identically.** Cancellation only works because the same map runs over AI text and user text. Apply it to one side only and you manufacture a spurious diff instead of erasing one.
- **It's retroactive — and that's the whole point.** The guard reads the *current* dictionary at analysis time, not a flag stored per-edit. The moment a "Carrie → Keri" entry exists, *every past edit* containing that correction stops being polluted, automatically. No per-edit boolean, no migration, no bookkeeping you can forget to set.

For the capture side, be **conservative**. `DictionaryCapture.candidate(...)` ([Sources/OpenWisprLib/DictionaryCapture.swift](../../../Sources/OpenWisprLib/DictionaryCapture.swift)) only fires when the user's *sole* change is a single one-word swap where both sides look like names (≥2 chars, capitalized, letters/`-`/`'` only, not a stopword, not already mapped). Anything ambiguous returns `nil`. The asymmetry is deliberate: a missed offer costs nothing, a wrong one is noise.

## Why This Matters

- **Protects the highest-value signal in the product.** The voice profile is what makes rewrites not sound AI. Polluting it with fake "style rules" degrades the one thing the app exists to do — and the corruption is silent and cumulative.
- **Retroactive correction beats per-event tagging.** A flag-at-write-time scheme ("mark this edit as a name fix") fails for every edit made before the dictionary entry existed and depends on the capture firing perfectly every time. Recomputing against the current map fixes the past for free and degrades gracefully.
- **One source of truth prevents drift.** Sharing `applyDictionary` means the normalization the learner subtracts can never diverge from the normalization the pipeline applies. Two implementations of "the same rule" is how the original contamination would sneak back.
- **It keeps the cross-machine privacy guarantee honest.** The voice profile is the only thing that crosses machines, as a content-free synthesis — raw transcripts never leave ([[privacy-cross-machine-learning]]). A signal corrupted by transcription noise would export that noise too; cleaning it at the diff keeps the exported statistics meaningful.
- **Conservative capture keeps the dictionary trustworthy.** Because the dictionary now also drives the contamination guard, a wrong entry does double damage — it mis-corrects live text *and* cancels real edits. The high bar in `isNameLike` / single-word-swap detection is what keeps that map clean.

## When to Apply

Reach for this pattern when:

- **One user action carries mixed intent** — an edit that's part typo-fix, part rephrase; a label that's part correction, part preference; a click that's part navigation, part selection.
- **You're learning from diffs or behavioral deltas** and some of the delta is attributable to a known, non-signal cause (autocorrect, a lookup table, a deterministic transform, a feature flag).
- **The unwanted signal is enumerable and reversible** — you can express it as a transform (a map, a normalizer, a canonicalizer) and run it over both sides. If you can name it, you can cancel it.
- **You want past data cleaned by future knowledge** — prefer recompute-against-current-state over store-a-flag-at-event-time whenever the analysis is cheap enough to redo.

Prefer **source separation** when the two signals can be captured through genuinely different paths cheaply. Prefer **cancellation** when they unavoidably arrive together. Use both when, as here, the separation channel (the dictionary) is itself what powers the cancellation.

Be cautious when the unwanted signal is *not* attributable (you can't name the transform — then you can only heuristically detect it, not cancel it), or when normalizing both sides could mask a difference you actually wanted to learn (e.g. a user who intends a non-standard spelling stylistically — the conservative capture rules guard against treating a style choice as a correction).

## Examples

**Contamination without the guard (the Carrie/Keri walk-through):**

- Whisper transcribes a name as "Carrie." The AI rewrite keeps "Carrie."
- User edits to "Keri" and pastes.
- Naive diff: AI says "...met Carrie at...", user says "...met Keri at...". The differ sees a word changed, finds no banned-word/filler/punctuation match, and increments the uncategorized-reword count. The voice profile now carries phantom evidence that this user "rewords proper nouns" — a rule that means nothing and dilutes the real style stats.

**The canceling diff (with the guard, once "Carrie → Keri" is in the dictionary):**

```
ai   = applyDictionary("met Carrie at", ["Carrie":"Keri"])  // -> "met Keri at"
mine = applyDictionary("met Keri at",   ["Carrie":"Keri"])  // -> "met Keri at"
ai == mine  // diff empty at that word: no length delta, no banned-word hit, no reword bump
```

The correction has been subtracted; only true rewordings elsewhere still register.

**Conservative detection (the capture that populates the map):**

`DictionaryCapture.candidate` drives the one-tap "Remember Carrie → Keri?" chip in `RewriteView`. It fires only on clean signal:

- ✅ AI `"I saw Carrie today"` → edited `"I saw Keri today"` — exactly one word differs, both name-like → returns `(from: "Carrie", to: "Keri")`.
- ❌ Two words changed → `nil`. Ambiguous: which change is the correction?
- ❌ Swap involves a stopword or lowercase word (`"the"`→`"a"`, `"meeting"`→`"call"`) → `nil` via `isNameLike`. Not a proper-noun correction.
- ❌ `"Carrie"` already mapped → `nil`. Nothing to offer.

Each accepted candidate becomes a dictionary entry, which (a) fixes the current text and (b) immediately and retroactively cancels that same correction across all past edits in the learning loop. The capture point and the contamination guard live on the same map.

## Related

- [llm-rewrite-eval-harness.md](../tooling-decisions/llm-rewrite-eval-harness.md) — the output-quality counterpart. This doc keeps the learning *input* clean; the eval harness measures the rewrite *output*. Two halves of the same rewrite/voice quality loop.
- Memory: [[voice-never-sound-ai]], [[privacy-cross-machine-learning]] — the goal the signal serves and the privacy constraint on exporting it.
- Prior groundwork (session history, 2026-06-10→15): the `editedText` capture column, the three signal states, and the content-free synthesis allowlist were established before this fix; the diff-normalization step was the missing piece.
