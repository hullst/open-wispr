---
title: LLM Rewrite Eval Harness — systematic model comparison for the Wispr rewrite pipeline
date: 2026-06-05
category: docs/solutions/tooling-decisions
module: eval
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "Evaluating a new Ollama model for rewrite quality before switching the default"
  - "A quality regression is suspected in the current model (meaning changes, attribution errors, rule violations)"
  - "Adding or changing a style preset in StylePresets.swift and wanting to verify prompt adherence"
  - "Comparing speed/quality tradeoffs between quantized model variants"
  - "Investigating a user-reported rewrite quality complaint with a reproducible case"
root_cause: missing_tooling
resolution_type: tooling_addition
related_components:
  - StylePresets
  - RewriteProvider
  - OllamaProvider
tags:
  - eval
  - ollama
  - model-comparison
  - rewrite-quality
  - voice-preservation
  - automated-checks
  - corpus
  - gemma2
---

# LLM Rewrite Eval Harness — systematic model comparison for the Wispr rewrite pipeline

## Context

Model selection for the Wispr rewrite pipeline was ad-hoc. The app uses a ~900-token system prompt encoding the user's writing style rules (`StylePresets.swift`), served to Ollama local models (default: `gemma2:9b`). A known quality regression — gemma2 reassigning attribution (e.g., "they/Yogi-and-James sent the code" becoming "Amit sent the code") — had no reproducible test harness. There was no way to systematically compare models, validate a prompt change, or confirm whether a newly pulled model regressed or improved on specific voice rules.

Small 8B models degrade on instruction adherence when context is dense. Without a harness, the degradation was anecdotal — visible in production outputs but impossible to quantify or compare.

The `eval/` directory fills that gap.

## Guidance

The harness has four components:

**`eval/corpus.json`** — 12 named test cases covering the failure modes that matter most:

| Case ID | Category | Tests |
|---------|----------|-------|
| `attribution-01` | meaning-preservation | Who sent what — attribution must not shift |
| `ask-first-01` | structure | Ask leads, context follows |
| `own-mistake-01` | voice | "that one's on me" not "my bad" |
| `numbers-01` | rules | Digits rule — no "five", "two" as words |
| `chat-quick-01` | style | Chat: terse, fragment-friendly |
| `chat-pushback-01` | voice | Soft pushback with one-clause reason |
| `companywide-01` | style | Point → stake → next step (owner + date) |
| `em-dash-trap-01` | rules | ` -- ` not `—` or `–` |
| `banned-words-trap-01` | rules | No leverage/utilize/robust/streamline |
| `external-delay-01` | voice | Name the external blocker — don't own it |
| `shorten-01` | length | Compress while preserving all facts |
| `expand-01` | length | Flesh out without inventing specifics |

**`eval/run.py`** — calls `POST http://localhost:11434/api/generate` with the same system prompt as `StylePresets.swift` (keep in sync when prompts change). Python 3 stdlib only.

```bash
# Full corpus
python3 eval/run.py gemma2:9b

# Targeted cases
python3 eval/run.py qwen3:8b --cases attribution-01,numbers-01

# Custom temperature
python3 eval/run.py llama3.1:8b --temperature 0.5
```

Auto-checks run on every output: em-dash presence, banned words, number-as-words, preamble detection ("Here is...", "Certainly..."), double-dash after period, filler phrases. Results save to `eval/results/<model>_<timestamp>.json`.

**`eval/compare.py`** — takes 2+ result files, emits a markdown report with: summary table (pass/fail/latency per model), per-category breakdown, per-case side-by-side outputs with auto-check badges, and human scoring tables.

```bash
python3 eval/compare.py \
  eval/results/gemma2-9b_20260605.json \
  eval/results/qwen3-8b_20260605.json
open eval/results/compare_*.md
```

**`eval/rubric.md`** — human scoring guide. 3 dimensions per case: Meaning (1–5), Voice (1–5), Would-send (Y/N/Edit). Fill in the scoring tables in the compare output after reading each case.

## Why This Matters

**Auto-checks are a floor, not a ceiling.** The three 8B models tested (gemma2:9b, qwen3:8b, llama3.1:8b) all scored 7–8/12 on mechanical checks — but gemma2:9b's `attribution-01` output passes every auto-check while silently changing who sent the code. Attribution and voice fidelity require human eval; the automated checks only catch mechanical rule violations.

If the system prompt changes (`StylePresets.swift`), re-run the full corpus against the current default model before shipping — a prompt improvement can break a previously-passing case.

**First-run findings (2026-06-05):**
- gemma2:9b: 8/12 auto-pass, ~5s/case — fastest, attribution bug invisible to auto-checks
- qwen3:8b: 7/12 auto-pass, ~30s/case — used actual em-dash on `attribution-01`; 6× slower than gemma2
- llama3.1:8b: 7/12 auto-pass, ~4s/case
- Universal failure across all three: numbers-as-words rule on number-heavy inputs

**2026-06-06 update:** phi4:14b (8/12, 7.2s avg) is the settled default. See `docs/solutions/tooling-decisions/ollama-model-selection-mac-mini.md` for hardware constraints (70B models crash Mac Mini) and model cleanup guidance. Claude Haiku via `AnthropicProvider` (already plumbed in) remains the quality ceiling reference if needed.

## When to Apply

- **Pulling a new model** (`ollama pull <model>`): run the full corpus, compare against the current baseline result file
- **Changing the system prompt** in `StylePresets.swift`: run all 12 cases against the current default model before and after
- **Investigating a quality complaint**: add a new case to `corpus.json` reproducing the bad output, then run it across models
- **Benchmarking Claude API vs local**: run the corpus against `AnthropicProvider` to establish a quality ceiling
- **After an Ollama version bump**: models can change behavior on upgrades; a baseline result file enables direct comparison

## Examples

**Add a regression case from a production failure:**
```json
{
  "id": "regression-2026-06-05",
  "category": "meaning-preservation",
  "style": "everyday",
  "length": "same",
  "notes": "Model invented that Amit sent code — 'they' (Yogi/James) sent it.",
  "input": "the raw voice-to-text that produced the bad output"
}
```
Then: `python3 eval/run.py gemma2:9b --cases regression-2026-06-05`

**Switch the default model** after a winning eval:
```swift
// Sources/OpenWisprLib/WisprDefaults.swift, line 31
get { defaults.string(forKey: "defaultOllamaModel") ?? "phi4:14b" }  // was gemma2:9b
```

**What to look for in human scoring:**
- `attribution-01`: does "they" / "Yogi and James" survive, or does the model invent an attribution?
- `own-mistake-01`: "that one's on me" present, "my bad" / "I apologize" absent?
- `ask-first-01`: is the ask in sentence 1, not buried after context?
- Any case that auto-passed: check it manually — mechanical pass ≠ meaning preserved

## Related

- `Sources/OpenWisprLib/StylePresets.swift` — source of truth for the system prompt; `eval/run.py` must stay in sync
- `Sources/OpenWisprLib/Providers/OllamaProvider.swift` — change `selectedModel` default to switch the app's model
- `Sources/OpenWisprLib/RewriteService.swift` — provider dispatch, temperature ramp per variant
