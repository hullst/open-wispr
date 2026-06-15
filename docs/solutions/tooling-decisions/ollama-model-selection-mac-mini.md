---
title: Ollama model selection and hardware limits for Wispr rewrite on Mac Mini
date: 2026-06-06
category: docs/solutions/tooling-decisions
module: rewrite/llm-eval
problem_type: tooling_decision
component: tooling
severity: medium
applies_when:
  - "Evaluating a new Ollama model for Wispr rewrite and deciding whether to make it the default"
  - "Pulling a large model for a benchmark run and unsure whether it fits Mac Mini hardware"
  - "Updating the fallback default model after an eval cycle"
  - "Cleaning up disk space after an eval run by removing non-contender models"
tags:
  - ollama
  - model-selection
  - apple-silicon
  - mac-mini
  - phi4
  - eval-harness
  - hardware-limits
---

# Ollama model selection and hardware limits for Wispr rewrite on Mac Mini

## Context

Wispr's rewrite feature runs Ollama models locally on a Mac Mini. The set of candidate models grows as new ones are pulled for evaluation, and without a documented size ceiling or a settled default, it is easy to accidentally pull a model that crashes the hardware or leave stale multi-gigabyte models consuming disk space between eval cycles.

The 2026-06-06 eval run tested qwen2.5:14b, phi4:14b, and llama3.3:70b against the 12-case corpus. `llama3.3:70b` (42GB) timed out on the first test case and left the Mac Mini unresponsive — a hard crash, not a graceful timeout. That run also surfaced a known false-positive in the eval rubric (see below) and settled phi4:14b as the new default.

## Guidance

**Hardware constraint: 14B maximum on Mac Mini**

70B-class models (≥40GB on disk) exceed Mac Mini memory capacity. Do not pull any model above the 14B class. A 14B quantized model runs at ~9GB on disk and stays within safe RAM bounds.

**Current recommended models**

| Model | Size | Role |
|-------|------|------|
| `phi4:14b` | ~9.1GB | Default — best quality, 7.2s avg latency |
| `qwen3:8b` | ~5.2GB | Lightweight alternative when disk or RAM is tight |

**How to update the fallback default**

The fallback model lives in one place — `Sources/OpenWisprLib/WisprDefaults.swift`, line 31:

```swift
get { defaults.string(forKey: "defaultOllamaModel") ?? "phi4:14b" }
```

The model list shown in the app's picker is dynamic (`OllamaProvider.probeModels()` queries Ollama at runtime), but the nil-coalescing fallback here applies to users who have never explicitly chosen a model. Update it manually after each eval cycle that changes the preferred default.

**How to clean up after an eval run**

```bash
ollama rm <model-name>

# Post-eval cleanup example (2026-06-06, freed ~61.3GB):
ollama rm llama3.3:70b   # 42GB — crashed hardware, never viable
ollama rm qwen2.5:14b    # 9GB  — lost to phi4:14b; also had Chinese-text leak in output
ollama rm llama3.1:8b    # 4.9GB — weakest 8B tested
ollama rm gemma2:9b      # 5.4GB — lost to qwen3:8b; was the prior default
```

Remove losers before closing the session. Each 14B model is ~9GB; they accumulate fast.

**Known eval rubric false positive: `number words`**

The `eval/run.py` auto-check flags any number word (one, two, three…) in the output as a style failure. This is too aggressive — it fires on idiomatic phrases like "that one's on me" and time expressions like "two weeks." A model that fails only `number words` cases may still be the better choice; read the actual outputs before concluding.

## Why This Matters

Pulling an oversized model does not fail gracefully — the machine becomes unresponsive. And stale eval models accumulate silently; the 2026-06-06 cleanup freed 61GB that had built up across two eval days. Keeping a documented size ceiling, a known-good default, and a cleanup habit prevents both hardware risk and silent disk bloat.

## When to Apply

- **Before pulling any model for evaluation**: confirm its on-disk size is ≤14B quantized (~9GB). Reject anything ≥40GB.
- **After each eval run**: prune the losers with `ollama rm` before closing the session.
- **When the preferred default changes**: update `WisprDefaults.swift` line 31 immediately so new installs get the right fallback.
- **When reviewing `number words` eval failures**: inspect the output before concluding the model is broken — the check may be flagging correct idiomatic usage.

## Examples

**WisprDefaults.swift:31 — updating the fallback default**

```swift
// Before — gemma2:9b was the prior default (removed after 2026-06-06 eval)
get { defaults.string(forKey: "defaultOllamaModel") ?? "gemma2:9b" }

// After — phi4:14b promoted after 2026-06-06 eval (8/12, 7.2s avg latency)
get { defaults.string(forKey: "defaultOllamaModel") ?? "phi4:14b" }
```

**Eval summary that drove this decision (2026-06-06, 12 cases, temperature 0.3)**

```
phi4:14b      8/12 passed   7.2s avg   ← winner, new default
qwen2.5:14b   7/12 passed   7.5s avg   Chinese text leak in banned-words-trap-01
llama3.3:70b  DNF            —          crashed Mac Mini on first test case (42GB)
```

**Prior eval (2026-06-05, 8B class)**

```
qwen3:8b      best 8B result   5.2GB   ← lightweight fallback, kept
llama3.1:8b   weakest 8B       4.9GB   removed
gemma2:9b     lost to qwen3    5.4GB   removed
```

## Related

- `docs/solutions/tooling-decisions/llm-rewrite-eval-harness.md` — how to run the corpus and compare models; read this before pulling a new model to benchmark
- `Sources/OpenWisprLib/WisprDefaults.swift:31` — the fallback default model (update here after an eval cycle)
- `eval/run.py` — the eval runner
- `eval/rubric.md` — human scoring guide for ambiguous auto-check results
