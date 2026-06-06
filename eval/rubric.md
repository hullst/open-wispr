# Eval Rubric — Human Scoring Guide

## Quick workflow

```bash
# Run both models (takes ~3 min each)
python3 eval/run.py gemma2:9b
python3 eval/run.py qwen3:8b

# Generate comparison report
python3 eval/compare.py eval/results/gemma2-9b_<ts>.json eval/results/qwen3-8b_<ts>.json

# Open the markdown report and fill in the scoring tables
open eval/results/compare_*.md
```

---

## Scoring dimensions

### Meaning (1–5)
Did the rewrite preserve exactly what was said — including WHO did WHAT?

| Score | Meaning |
|-------|---------|
| 5 | Perfect. Every fact, attribution, and implication is intact. |
| 4 | Tiny omission or imprecision, but nothing that would mislead. |
| 3 | Some context lost or slightly reorganized in a way that changes nuance. |
| 2 | A fact is wrong or an attribution shifted (e.g., Amit sent the code vs. Yogi/James). |
| 1 | Meaning materially changed. Would cause confusion or misrepresent what happened. |

**Red flags to watch for:**
- Attribution shift: "they sent X" → "Amit sent X"
- Invented context: adding a reason, urgency, or next step that wasn't in the input
- Softening what should be direct ("we might want to…" instead of "we need to…")
- Hardening what should be soft (making a casual note sound like a directive)

---

### Voice (1–5)
Does it sound like Stephen wrote it — not like a cleaned-up chatbot output?

| Score | Voice |
|-------|-------|
| 5 | Indistinguishable from Stephen's actual writing. Signature devices feel natural. |
| 4 | Sounds right, maybe one word or phrase feels slightly generic. |
| 3 | Competent but generic. Could be anyone's professional email. |
| 2 | Noticeably AI-shaped: too smooth, too structured, corporate tone. |
| 1 | Clear AI tells: preamble, buzzwords, filler phrases, hype language. |

**Voice signatures to look for (positive signals):**
- Short punchy sentences mixed with slightly longer ones
- Sentence fragments used for emphasis
- `--` for flow, not for structure
- Numbers always digits
- "that one's on me" not "my apologies" or "my bad"
- Dry humor or directness ("what am I missing?")
- No exclamation points except for genuine warmth

---

### Would you send it? (Y / N / Edit)
The bottom line.

- **Y** — Send as-is, zero changes needed.
- **Edit** — Right direction but needs a tweak (note what you'd change).
- **N** — Would not use this output. Note why.

---

## What to do with the scores

After filling in the per-case tables in the comparison report, roll up to the "Overall Human Scores" table at the bottom.

**Decision criteria:**
- If one model has consistently higher Meaning scores → that's the floor, pick it
- If Meaning is tied → Voice scores and "Send rate" break the tie
- If both fail on the same cases → the system prompt may need tuning, not just a model swap

**If you want to switch the default model**, update `OllamaProvider.swift`:
```swift
init(selectedModel: String = "gemma2:9b") {  // ← change this
```

---

## Adding test cases

Add to `eval/corpus.json`. Required fields:
```json
{
  "id": "kebab-case-unique-id",
  "category": "meaning-preservation | structure | voice | rules | style | length",
  "style": "everyday | chat | companywide",
  "length": "same | shorten | expand",
  "notes": "What this case specifically tests. What failure looks like.",
  "input": "The raw voice-to-text to rewrite."
}
```

Good cases to add over time:
- Real inputs that produced bad outputs in production (most valuable)
- Edge cases in a specific style you use a lot
- Cases targeting a rule the current model keeps violating
