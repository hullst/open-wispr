# Dictation Rewriter — Model Research

*Compiled June 4, 2026 — for the task of cleaning up 1–3 paragraphs of dictated text while preserving the speaker's voice. Target latency: sub-2-second feel. Short context (~few hundred input/output tokens).*

---

## Executive summary — three concrete picks

| Tier | Pick | One-line reason |
|---|---|---|
| **Free / local (default)** | **Gemma 3 4B** (via Ollama or MLX) | Still the right answer. Disciplined instruction-following at a size where M-series latency feels instant. Nothing has clearly passed it for *this* task. |
| **Free / local (worth trying)** | **Apple's on-device Foundation Model** via `python-apple-fm-sdk` | Apple literally fine-tuned its ~3B model for "writing and refining text." If quality lands, it's the most native, cheapest, fastest option. Caveats below. |
| **Paid (important messages)** | **Claude Sonnet 4.6** ($3 / $15 per M tokens) | Best preservation of voice and idiom on short rewrites. Sub-2s for a paragraph. Use Haiku 4.5 as the bulk-traffic default. |

The honest read: **you have not been left behind by staying on Gemma.** The 2025–2026 small-model race has moved benchmarks forward, but the rewriter task rewards instruction discipline and stylistic restraint, not raw IQ. Gemma 3's tuning is well-matched to that. Where it's worth your time to experiment: Apple Intelligence's foundation model (new and purpose-built for this exact task), and Qwen 3 8B if you have 16 GB+ and want to see if a more recent model gives you a noticeable lift.

---

## Tier A — Free, local on Apple Silicon

| Model | Params | Recommended quant | Memory footprint | Expected tok/s (M-series) | Fit for rewriter task |
|---|---|---|---|---|---|
| **Gemma 3 4B-it** | 4B | Q4_K_M | ~3 GB | 60–100 tok/s on M2–M4 | **Excellent.** Strong instruction-following, conservative rephrasing, multilingual. Sweet spot. |
| **Gemma 3 12B-it** | 12B | Q4_K_M | ~8 GB | 25–40 tok/s | **Excellent +** if you have headroom. Better at subtle voice preservation than 4B. |
| **Gemma 3n E4B** | ~4B effective (8B raw) | Q4 | ~3 GB | ~100+ tok/s | Optimized for on-device, but tuned more for multimodal/audio. Slight edge for transcript pipelines if you also use its audio encoder; otherwise no advantage over 3 4B for text-only rewrite. |
| **Qwen 3 4B** | 4B | Q4_K_M | ~2.5 GB | 80–120 tok/s | **Very good.** Slightly stronger raw capability than Gemma 3 4B in benchmarks; sometimes overconfident in rewrites (adds words). Worth A/B testing against Gemma. |
| **Qwen 3 8B** | 8B | Q4_K_M | ~5 GB | 40–60 tok/s | **Very good.** The "I have 16 GB+" recommended default per most 2026 Mac LLM guides. Punches above weight; can occasionally drift in tone. |
| **Phi-4 Mini** | 3.8B | Q4_K_M | ~3 GB | 70–100 tok/s | Good. Microsoft tunes Phi for "writing assistance and rephrasing." Reasoning is strong, voice fidelity is middling — it tends toward formal/neutral register. |
| **Ministral 3 8B** | 8B | Q4_K_M | ~5 GB | 50–60 tok/s | Good. Mistral lists "rewrite for clarity" as a first-class use case. Quality close to Qwen 3 8B; slightly drier voice. |
| **Llama 3.2 3B** | 3B | Q4_K_M | ~2 GB | 80–120 tok/s | Adequate. Fast and stable, but a generation behind Gemma 3 4B in nuance. |
| **Llama 4 Scout** | 109B MoE (17B active) | Q4_K_M | ~65 GB | — | **Skip** unless you have an M3 Max 96 GB or M4 Max 128 GB. Overkill for the task. |
| **Apple Intelligence Foundation Model** | ~3B | n/a (native) | Built into macOS | Native Neural Engine | **Potentially excellent — try it.** Apple literally trained this model to refine and rewrite text. Caveats below. |

### Per-model reasoning that matters

**Gemma 3 4B-it** — Still the right default. Google's instruction tuning on Gemma is conservative: when you tell it "preserve voice, tighten, fix grammar," it actually does that rather than rewriting in its own voice. At ~3 GB Q4 it leaves your Mac wide-open for everything else, and on any M-series chip the latency for a 200-token rewrite is effectively zero (sub-second). Ollama support is mature. There's no compelling reason to abandon this unless you specifically want to try Apple's model. ([Gemma 3 on Mac install guide](https://codersera.com/blog/how-to-run-gemma-3-on-a-mac-a-comprehensive-guide/), [Apple Silicon LLM benchmarks](https://llmcheck.net/benchmarks))

**Apple Intelligence Foundation Model** — The new contender. Apple ships a ~3B parameter model on every Apple Silicon Mac running macOS 26+ with Apple Intelligence enabled. They have fine-tuned it specifically for "writing and refining text" — the exact task you're doing. The [python-apple-fm-sdk](https://github.com/apple/python-apple-fm-sdk) gives you Python access. **The catch:** Apple positions the Python SDK as primarily for *evaluating* your Swift app's behavior, not as a production runtime — the supported production path is Swift via the Foundation Models framework. So expect some friction if you want this in a long-running Python service. If you're shelling out from Python to a small Swift helper or to the `shortcuts` CLI, that's a fine pattern. Quality-wise: unproven at the paragraph-rewrite level, but if it works, it's the right answer because it's free, on-device, native, and *purpose-built for this task*. ([Apple Foundation Models framework](https://developer.apple.com/documentation/FoundationModels), [Apple ML research](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates))

**Qwen 3 4B / 8B** — The honest competition for Gemma in 2026. Qwen 3 4B is reported to rival Qwen 2.5 72B on some benchmarks, which is impressive but mostly reflects reasoning gains, not stylistic improvements. The 8B model is the typical 2026 recommendation for 16–24 GB Macs. Where Qwen sometimes loses to Gemma on rewrite tasks: it has a slight tendency to *improve* prose beyond what was asked, which is bad if you're preserving someone's voice. Worth a real A/B test before switching. ([Qwen 3 Mac install guide](https://codersera.com/blog/run-qwen-3-8b-on-mac-an-installation-guide/), [Best Qwen models May 2026](https://insiderllm.com/guides/qwen-models-guide/))

**Gemma 3n E4B** — Worth knowing about only because if you ever want to add audio understanding to the same pipeline (so the LLM sees the original audio, not just the Whisper transcript, and can preserve emphasis), Gemma 3n has a built-in audio encoder. For pure text-in / text-out, no advantage over Gemma 3 4B. ([Gemma 3n developer guide](https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/))

**Phi-4 Mini** — Microsoft's small model. Strong for its size, runs on 8 GB Macs, but it has a "corporate writing assistant" feel: the voice it produces is neutral, slightly formal. Bad fit if your dictated text has personality you want preserved. Good fit if you're cleaning up dry technical notes. ([Phi-4 Mini guide](https://localaimaster.com/models/phi-4-mini))

**Ministral 3 (3B / 8B / 14B)** — Mistral's edge family. The 8B is comparable to Qwen 3 8B. Mistral explicitly markets text rewriting as a first-class use case, but in practice the voice it produces is similar to Phi — clean, professional, slightly dry. ([Mistral 3 announcement](https://mistral.ai/news/mistral-3/))

---

## Tier B — Paid API

| Model | Input $/M | Output $/M | Median TTFT | Throughput | Fit for rewriter task |
|---|---|---|---|---|---|
| **Claude Haiku 4.5** (`claude-haiku-4-5-20251001`) | $1.00 | $5.00 | ~0.6–0.8s | ~91 tok/s | **Excellent default.** Sub-second feel, Claude-grade writing quality. |
| **Claude Sonnet 4.6** (`claude-sonnet-4-6`) | $3.00 | $15.00 | ~1.4s | ~70 tok/s | **Best quality for the price.** Best voice preservation on short rewrites. |
| **Claude Opus 4.6** (`claude-opus-4-6`) | $5.00 | $25.00 | ~2.0s | ~50 tok/s | Overkill for this task. Use only when "important" really means *important*. |
| **GPT-5** | $1.25 | $10.00 | ~0.8s | ~90 tok/s | Strong but stylistically more "polished" — sometimes overwrites your voice. |
| **GPT-5.1** | $1.25 | $10.00 | similar | similar | Iteration; same tradeoff. |
| **Gemini 2.5 Flash** | $0.30 | $2.50 | ~0.6–0.8s | ~110 tok/s | **Cheapest by a mile.** Quality is close to Haiku 4.5; voice fidelity is decent. |
| **Gemini 2.5 Pro** | $1.00 | $10.00 | ~3–20s | — | Tuned as a reasoning model; latency is bad for live dictation. Skip. |

### Per-model reasoning that matters

**Claude Sonnet 4.6** — My pick for "important messages." Anthropic's training emphasis on faithful instruction-following pays off here: when you say "preserve my voice, tighten only," Sonnet does that better than GPT-5 (which tends to elevate register) and better than Gemini Flash (which sometimes paraphrases too aggressively). For a typical 200-token in / 200-token out rewrite, you're paying ~$0.0036 per call. Even at 1000 rewrites a day that's $3.60. ([Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing))

**Claude Haiku 4.5** — My pick for the *default* paid path. Sub-second TTFT is the headline: Artificial Analysis shows ~597 ms TTFT, ~91 tok/s, with p95 latency barely drifting from median (so it feels consistently snappy, not intermittently). At $1 / $5 it's still 5x cheaper than Sonnet and the quality gap on short rewrites is small. If you're routing 95% of dictations to Haiku and 5% to Sonnet for "important," you'll be happy. ([Artificial Analysis – Claude Haiku 4.5](https://artificialanalysis.ai/models/claude-4-5-haiku/providers))

**Gemini 2.5 Flash** — The price champion. $0.30 input / $2.50 output is ~3x cheaper than Haiku 4.5. Time to first token from Google AI Studio is ~600 ms — same league as Haiku. For pure cost-sensitive bulk, this is the right call. Voice preservation is decent but Claude is meaningfully better at it for nuanced/personal prose. ([Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing), [Artificial Analysis – Gemini 2.5 Flash](https://artificialanalysis.ai/models/gemini-2-5-flash/providers))

**GPT-5 / 5.1** — Strong models, but for the rewriter task specifically, GPT has a long-standing tendency to "improve" the user's prose into something that sounds more like ChatGPT. Bad fit when you want *your* voice cleaner, not GPT's voice instead. ([OpenAI API pricing](https://openai.com/api/pricing/))

---

## Implementation notes

### Local (Ollama) — Python

Install once: `brew install ollama && ollama pull gemma3:4b-it-q4_K_M` (or `gemma3:12b-it-q4_K_M`).

```python
import requests

def rewrite(text: str, model: str = "gemma3:4b-it-q4_K_M") -> str:
    prompt = (
        "Rewrite the following dictated text. Preserve the speaker's voice and meaning. "
        "Tighten only — fix grammar, remove filler words, add punctuation, fix self-corrections. "
        "Do not add new content. Do not change vocabulary unless required for clarity.\n\n"
        f"Text:\n{text}\n\nRewritten:"
    )
    r = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": model, "prompt": prompt, "stream": False,
              "options": {"temperature": 0.2, "num_predict": 400}},
        timeout=30,
    )
    return r.json()["response"].strip()
```

Tips: keep `temperature` low (0.1–0.3) for rewrite tasks; set `num_ctx` only as large as you need (default 2048 is fine here); preload the model with `ollama run gemma3:4b ""` or by setting `OLLAMA_KEEP_ALIVE=1h`.

### Apple Intelligence — Python

```bash
pip install apple-fm-sdk  # requires macOS 26+, Apple Silicon, Apple Intelligence enabled
```

```python
from apple_fm import FoundationModel
model = FoundationModel()
out = model.generate(prompt=PROMPT_AS_ABOVE, temperature=0.2)
```

Reality check: read the Python SDK docs carefully ([apple.github.io/python-apple-fm-sdk](https://apple.github.io/python-apple-fm-sdk/)). Apple positions it primarily as an evaluation tool for testing Swift integrations. If long-running Python use turns out to be brittle, the fallback is to write a tiny Swift helper that calls the Foundation Models framework directly and shell out to it from Python — that's the supported production path.

### Anthropic (Claude) — Python

```bash
pip install anthropic
export ANTHROPIC_API_KEY=...
```

```python
import anthropic

client = anthropic.Anthropic()

def rewrite(text: str, important: bool = False) -> str:
    model = "claude-sonnet-4-6" if important else "claude-haiku-4-5-20251001"
    with client.messages.stream(
        model=model,
        max_tokens=600,
        system="Rewrite dictated text. Preserve voice; tighten only.",
        messages=[{"role": "user", "content": text}],
    ) as stream:
        return "".join(stream.text_stream)
```

Streaming is well-supported. API keys via env var. Sub-second TTFT means the first words land before the user has finished blinking.

### OpenAI — Python

```bash
pip install openai
export OPENAI_API_KEY=...
```

```python
from openai import OpenAI
client = OpenAI()
out = client.responses.create(
    model="gpt-5",
    input=[{"role": "user", "content": prompt}],
    temperature=0.2,
)
print(out.output_text)
```

### Google Gemini — Python

```bash
pip install google-genai
export GOOGLE_API_KEY=...
```

```python
from google import genai
client = genai.Client()
resp = client.models.generate_content(
    model="gemini-2.5-flash",
    contents=prompt,
    config={"temperature": 0.2},
)
print(resp.text)
```

---

## Recommended setup

A reasonable architecture given your goals:

1. **Default path:** Gemma 3 4B locally via Ollama. No network call, sub-second latency, zero cost. Good enough for ~95% of dictations.
2. **"Important" hotkey:** Send to Claude Sonnet 4.6 streaming. ~1.5s end-to-end including network. Cost is pennies per use.
3. **Optional experiment:** Wire up Apple Intelligence's foundation model behind a feature flag and run a week of side-by-side comparisons against Gemma 3 4B on real dictations. If Apple's quality matches or beats Gemma at the same latency, switch your default — it's even more native and the prompt-engineering surface area is similar.

Avoid: Llama 4 Scout (too big), Gemini 2.5 Pro (high latency), Opus 4.6 (overkill for rewrite).

---

## Sources

- [Claude API pricing](https://platform.claude.com/docs/en/about-claude/pricing)
- [Artificial Analysis — Claude Haiku 4.5](https://artificialanalysis.ai/models/claude-4-5-haiku/providers)
- [Artificial Analysis — Gemini 2.5 Flash](https://artificialanalysis.ai/models/gemini-2-5-flash/providers)
- [OpenAI API pricing](https://openai.com/api/pricing/)
- [Gemini Developer API pricing](https://ai.google.dev/gemini-api/docs/pricing)
- [Apple Foundation Models framework](https://developer.apple.com/documentation/FoundationModels)
- [apple/python-apple-fm-sdk](https://github.com/apple/python-apple-fm-sdk)
- [Updates to Apple's On-Device Foundation Models](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates)
- [Gemma 3 on Mac install guide](https://codersera.com/blog/how-to-run-gemma-3-on-a-mac-a-comprehensive-guide/)
- [Gemma 3n developer guide](https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/)
- [Apple Silicon LLM benchmarks](https://llmcheck.net/benchmarks)
- [Qwen 3 8B on Mac install guide](https://codersera.com/blog/run-qwen-3-8b-on-mac-an-installation-guide/)
- [Best Qwen models — May 2026](https://insiderllm.com/guides/qwen-models-guide/)
- [Phi-4 Mini guide](https://localaimaster.com/models/phi-4-mini)
- [Mistral 3 announcement](https://mistral.ai/news/mistral-3/)
- [Ministral 3 on Mac install guide](https://codersera.com/blog/run-and-install-mistral-3-3b-locally-the-complete-guide/)
- [Best Local LLMs for Mac in 2026](https://insiderllm.com/guides/best-local-llms-mac-2026/)
