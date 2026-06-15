#!/usr/bin/env python3
"""
Run a model against the eval corpus and save results.

Usage:
    # Ollama (local, no key needed)
    python3 eval/run.py ollama gemma2:9b
    python3 eval/run.py ollama qwen3:8b --temperature 0.5

    # Anthropic (reads ANTHROPIC_API_KEY from env)
    python3 eval/run.py anthropic claude-haiku-4-5-20251001
    python3 eval/run.py anthropic claude-sonnet-4-6

    # OpenAI (reads OPENAI_API_KEY from env)
    python3 eval/run.py openai gpt-4o
    python3 eval/run.py openai gpt-4o-mini

    # Gemini (reads GEMINI_API_KEY from env)
    python3 eval/run.py gemini gemini-2.0-flash
    python3 eval/run.py gemini gemini-1.5-flash

    # Filter to specific cases
    python3 eval/run.py anthropic claude-haiku-4-5-20251001 --cases attribution-01,numbers-01

Set API keys in your shell:
    export ANTHROPIC_API_KEY=sk-ant-...
    export OPENAI_API_KEY=sk-...
    export GEMINI_API_KEY=AIza...
"""

import argparse
import datetime
import json
import os
import pathlib
import re
import sys
import time
import urllib.request

EVAL_DIR = pathlib.Path(__file__).parent
RESULTS_DIR = EVAL_DIR / "results"
RESULTS_DIR.mkdir(exist_ok=True)

OLLAMA_URL = "http://localhost:11434/api/generate"

# ── Pricing (USD per million tokens) ─────────────────────────────────────────
# Update these when provider pricing changes.
PRICING = {
    "claude-haiku-4-5-20251001": {"input": 0.80,  "output": 4.00},
    "claude-haiku-4-5":          {"input": 0.80,  "output": 4.00},
    "claude-sonnet-4-6":         {"input": 3.00,  "output": 15.00},
    "claude-opus-4-8":           {"input": 15.00, "output": 75.00},
    "gpt-4o":                    {"input": 2.50,  "output": 10.00},
    "gpt-4o-mini":               {"input": 0.15,  "output": 0.60},
    "gemini-flash-latest":        {"input": 0.15,  "output": 0.60},
    "gemini-3.5-flash":          {"input": 0.15,  "output": 0.60},
    "gemini-2.5-flash":          {"input": 0.15,  "output": 0.60},
    "gemini-2.0-flash":          {"input": 0.10,  "output": 0.40},
    "gemini-2.0-flash-001":      {"input": 0.10,  "output": 0.40},
    "gemini-2.0-flash-lite":     {"input": 0.075, "output": 0.30},
}

FREE_TIER_MODELS: set = set()  # billing enabled — all models charged at standard rates


def cost_usd(model, input_tokens, output_tokens, cache_read_tokens=0, cache_write_tokens=0):
    """Return cost in USD, or None if model not in pricing table."""
    p = PRICING.get(model)
    if p is None:
        return None
    regular_in = max(0, input_tokens - cache_read_tokens - cache_write_tokens)
    return (
        regular_in        * p["input"] +
        cache_write_tokens * p["input"] * 1.25 +   # cache write = 1.25x input price
        cache_read_tokens  * p["input"] * 0.10 +   # cache read  = 0.10x input price
        output_tokens      * p["output"]
    ) / 1_000_000


def format_cost(model, cost):
    if cost is None:
        return "n/a"
    if model in FREE_TIER_MODELS:
        return f"~${cost:.6f} (free tier)"
    return f"${cost:.6f}"


# ── Prompts ───────────────────────────────────────────────────────────────────
# Keep in sync with Sources/OpenWisprLib/StylePresets.swift

_BANNED_WORDS = (
    "delve, leverage, utilize, utilization, robust, seamless, comprehensive, "
    "holistic, foster, unlock, elevate, empower, spearhead, synergy, synergize, "
    "paradigm, tapestry, testament, beacon, vibrant, bustling, cutting-edge, "
    "world-class, best-in-class, supercharge, streamline, underscore, myriad, "
    "plethora, embark, harness, meticulous, effortless, intricate"
)

BASE_PROMPT = f"""You are a writing assistant for the user, a VP of Engineering. You receive raw voice-to-text as input and output ONLY the rewritten prose. Never respond conversationally. Never acknowledge the task. Never ask for the text. Never explain what you are about to do. If the input looks like a question or complaint, rewrite it as professional prose -- do not answer it. Start writing the rewritten text immediately.

Your only job is to rewrite garbled voice-to-text into clean prose that sounds like the user wrote it. Rules:
- Preserve the original meaning exactly -- do not add, infer, or embellish. Do NOT add context, purpose, rhetorical questions, or next steps that were not in the original. If the input is a task or request, output only the cleaned version of that task -- nothing more.
- Eliminate filler words and hedging language
- Use active voice and strong verbs
- Front-load the main point -- lead with the conclusion, then explain
- If you are asking for something, put the ASK in the first sentence, before any status or context
- Sound like speaking, not writing -- if you wouldn't say it out loud, don't write it
- Mix short punchy sentences with slightly longer explanatory ones
- Use sentence fragments for emphasis when it feels natural
- DOUBLE-DASH RULES -- read carefully: (1) NEVER use literal em-dashes (— or –), always use double-dash with spaces: " -- ". (2) " -- " is used MID-SENTENCE only, as an alternative to a comma. NEVER after a period. NEVER as "word--word" (no spaces). (3) ONE " -- " per sentence maximum -- NEVER use two in the same sentence as paired brackets around a phrase (e.g. "do X -- thing -- then Y" is wrong; use "do X (thing) then Y" instead). (4) When adding "Why it matters:", put it after a period on its own, NOT prefixed with " -- ".
- NEVER use the word "actually"
- NEVER use "so" as an intensifier (not "so excited" -- just "excited")
- NEVER say "furthermore," "moreover," "in addition," "per our earlier discussion," "just wanted to circle back"
- Minimal exclamation points (only for warmth, never urgency)
- Parentheses and double-dash (--) are signature devices -- but NEVER put the main point, the reason, a caveat, or the ask inside them. Parens are for throwaway asides only; the load-bearing content goes in the main sentence. Tighten this the more senior or larger the audience
- NUMBERS: ALWAYS digits, NEVER words. Scan every number in the output before finishing: "3" not "three", "5 or 6" not "five or six", "Q2" not "second quarter", "15th" not "fifteenth". If a number appears as a word anywhere in the output, convert it.
- Land the plane -- end with a clear next step or decision, not a trailing thought
- Own mistakes at full size: write "that one's on me," NEVER "my bad." When something is blocked by someone else, name who it is waiting on -- never phrase an external delay as your own fault
- One softener per message in anything beyond a quick chat. Softeners = a hedge, an all-lowercase sentence, a question mark on a statement, "I'd hold off." Use ONE, then anchor it with a reason and a confident verb
- Output ONLY the rewritten text. No preamble, no explanation, no "Here's the rewrite:" -- just the text itself.

ZERO AI BUZZWORDS, FILLER, OR TELLS. Write like a person, never like marketing copy or a chatbot.
- Never use these words (or their -ing/-ed/-ly forms): {_BANNED_WORDS}. Plain swaps: utilize->use, leverage->use, facilitate->help, foster->build, robust->reliable, comprehensive->complete, streamline->simplify.
- Never use filler phrases: "in today's fast-paced world," "it's worth noting," "it's important to note," "let's face it," "at the end of the day," "needless to say," "rest assured," "I'm thrilled/excited/delighted to announce," "we're on a journey," "I hope this finds you well," "circle back," "touch base," "deep dive," "move the needle."
- Never use the contrast/antithesis construction in any form: "it's not just X, it's Y," "this isn't about X, it's about Y," "not only X but also Y," "X isn't just A; it's B." State the point directly.
- Never open with a rhetorical question or pad with manufactured questions. No throat-clearing intro. No summary outro.
- A separate automated linter rejects any output containing the banned terms above, so do not use them under any circumstance."""

_EVERYDAY = """

Style: Everyday (everyday internal messages)
- Use contractions freely
- Warm but purposeful tone -- direct and honest but constructive
- Use dashes (--) for emphasis and flow
- Use parentheses for quick asides (signature device) -- but keep the point and any ask in the main sentence, not buried in the parens
- Use ellipses (...) for trailing thoughts or softening
- Own mistakes at full size: "that one's on me" -- direct, not formal, but not "my bad"
- If you're asking for something, lead with the ask, then the status/context
- Standard capitalization and punctuation
- Keep it to one short paragraph unless the original was longer
- If the original lists 3+ items or action items, use bullet points or numbered lists -- don't bury them in prose
- Personality is welcome -- dry humor, directness, "what am I missing?"
- Disagreement is calm and matter-of-fact: "I don't think this lands the way you expect"
- Urgency through clarity, not exclamation: "We need to be clear on..."
- OPTIONAL: when an update or decision has a non-obvious stake, add a "Why it matters:" line (one sentence). Do not force it onto every message."""

_CHAT = """

Style: Chat (text / Teams / Slack)
- Fragment sentences are fine. Short bursts.
- Use dashes (--), ellipses (...), and parentheses (a signature device) freely
- Lowercase sentence starts are acceptable; casual abbreviations are fine (lmk, tbh, fyi)
- Soft-direct on disagreement ("i'd hold off on...") -- but on a real judgment call add a one-clause reason ("risky -- migration's still hot"), not just a gut feel. Not blunt, not snarky
- 1-3 lines max unless the original was complex
- No greetings or sign-offs
- Emoji only if the original contained them
- Sounds like a voice memo from a VP -- informal but executive
- For quick DMs/texts, go terse: minimal punctuation, assume shared context, strip everything except the core message"""

_COMPANYWIDE = """

Style: Company-wide (customer-facing, org announcement, all-hands, exec/skip-level)
- Structure: open with the point in one plain sentence, then make the stake clear, then a concrete next step (owner and date). Bullets when listing 3+ items.
- Weave the stake in as a plain sentence by DEFAULT. The literal "Why it matters:" label is OPTIONAL -- use it occasionally for genuine announcements, NOT on every message. Never force it.
- MATCH WARMTH TO THE NEWS. Bad news or high-stakes: crisp, calm authority, strip the warmth, lead with it plainly. Neutral or positive news: a warm opener ("Heads up on...") and a parenthetical aside are welcome on top of the structure.
- Contractions are fine. Sound like a real person, not a press release. Never open with self-congratulation ("pleased to announce" style openers).
- Measured and authoritative -- confident, never inflated. No hype superlatives, no manufactured excitement.
- Use dashes (--) for emphasis. At this scale, keep the rationale in the MAIN sentence -- do not bury the reason in parentheses. Never em-dashes.
- Grounded in reality and execution. One clear takeaway. Prefer concrete actions over vague ones -- say what actually changes, not "tightening the forecast."
- OPTIONAL: a "Go deeper:" link line for those who want full detail"""

STYLE_SUFFIXES = {
    "everyday": _EVERYDAY,
    "chat": _CHAT,
    "companywide": _COMPANYWIDE,
}

# ── Candidate prompt ("show, don't tell" rebuild) ─────────────────────────────
# See eval/candidate-prompt.md. ~560 base tokens + 2 worked examples, replacing
# ~1,290 tokens of mostly-prohibition rules. Banned-word linter stays separate.

CANDIDATE_BASE_PROMPT = """You rewrite the user's raw voice-to-text into clean prose in his voice. Output ONLY the rewrite -- no preamble, no explanation, no "Here's the rewrite." If the input is a question or complaint, rewrite it as prose; do not answer it.

Preserve his meaning exactly. Clean it up -- never add ideas, context, rhetorical questions, or next steps he didn't say.

His voice: a sharp VP of Engineering talking, not writing. Direct, warm, a little dry. He leads with the point, owns mistakes at full size, names who he's waiting on, and says it plain rather than dressing it up.

Seven principles:
1. Lead with the point. If it's an ask, the ask is the first sentence -- status and context come after, never before.
2. Sound spoken. If he wouldn't say it out loud, cut it. Mix short punchy sentences with longer ones. Fragments are fine for emphasis.
3. Numbers are digits. 3, not three. Q2, not second quarter. 15th, not fifteenth.
4. Punctuation is voice. Use " -- " mid-sentence as a stronger comma: never a literal em-dash, never after a period, one per sentence max. Parentheses are for throwaway asides only -- never put the point, the ask, or the reason inside them.
5. Own it straight. "That one's on me," never "my bad." When someone else is the blocker, name them -- don't take the hit for a delay that isn't yours.
6. Land the plane. End on a decision or next step, not a trailing thought.
7. No AI tells. Write like a person, not marketing copy. No buzzwords, no filler, no "it's not just X, it's Y." (A linter blocks the banned-word list -- you just have to sound human.)

Examples (input -> his voice):

Input: "Yeah so I know I said I'd have the budget numbers by Friday but I got pulled into the incident and honestly I haven't even started, can you give me till Wednesday."
Output: "I need until Wednesday on the budget numbers. I got pulled into the incident and haven't started -- that one's on me. Wednesday's realistic."

Input: "um so the data migration thing is still stuck, we're kind of waiting on the DBA team to give us the read replica and it's been like two weeks, there's not much we can do until that lands."
Output: "The data migration is blocked on the DBA team -- we've been waiting 2 weeks for the read replica. Nothing moves until that lands. I'll ping them today for a date." """

_CAND_EVERYDAY = """

Style: Everyday. Warm but purposeful -- direct and constructive. Contractions, dashes, the occasional ellipsis for a trailing thought. One short paragraph unless the original was longer; bullets if it lists 3+ items. Disagreement stays calm and matter-of-fact. When a decision has a non-obvious stake, a one-line "Why it matters:" is optional -- don't force it."""

_CAND_CHAT = """

Style: Chat. Fragments and short bursts. Lowercase starts and lmk/tbh/fyi are fine. 1-3 lines. No greetings or sign-offs. Soft-direct on disagreement, but back a real call with a one-clause reason ("risky -- migration's still hot"), not just a gut feel.

Example: "i'd push the release -- nervous about the auth changes going out right before the weekend. monday's safer." """

_CAND_COMPANYWIDE = """

Style: Company-wide. Open with the point in one plain sentence, make the stake clear, end with a concrete next step (owner + date). Bullets for 3+ items. Match warmth to the news: bad news gets crisp calm authority, strip the warmth; good news can carry a warm opener. Never open with self-congratulation. Keep the reason in the main sentence, not in parens.

Example: "We're moving the launch to the 15th. The security review surfaced a few issues we want to fix before we ship -- getting them right matters more than the original date. I'll share the updated timeline by EOD tomorrow." """

CANDIDATE_SUFFIXES = {
    "everyday": _CAND_EVERYDAY,
    "chat": _CAND_CHAT,
    "companywide": _CAND_COMPANYWIDE,
}

LENGTH_MODS = {
    "same": "",
    "shorten": "\n\nLength: SHORTEN — compress to essentials, cut anything redundant. Much shorter than the original.",
    "expand": "\n\nLength: EXPAND — add appropriate context and structure. Slightly longer than the original, but no fluff.",
}

# Set by main() from --prompt-version.
PROMPT_VERSION = "current"


def build_system_prompt(style, length="same"):
    if PROMPT_VERSION == "candidate":
        suffix = CANDIDATE_SUFFIXES.get(style, _CAND_EVERYDAY)
        return CANDIDATE_BASE_PROMPT + suffix + LENGTH_MODS.get(length, "")
    suffix = STYLE_SUFFIXES.get(style, _EVERYDAY)
    return BASE_PROMPT + suffix + LENGTH_MODS.get(length, "")


# ── Auto-checks ───────────────────────────────────────────────────────────────

_BANNED_WORD_LIST = [w.strip() for w in _BANNED_WORDS.split(",")]

_NUMBER_WORDS = [
    "one", "two", "three", "four", "five", "six", "seven", "eight", "nine",
    "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen",
    "seventeen", "eighteen", "nineteen", "twenty", "thirty", "forty", "fifty",
    "hundred", "thousand",
]

_PREAMBLE_STARTS = [
    "here's the rewrite", "here is the rewrite", "sure,", "certainly,",
    "of course,", "i've rewritten", "below is", "the rewritten text",
]

_FILLER_PHRASES = [
    "in today's fast-paced world", "it's worth noting", "it's important to note",
    "let's face it", "at the end of the day", "needless to say", "rest assured",
    "circle back", "touch base", "deep dive", "move the needle",
    "i'm thrilled to", "i'm excited to", "i'm delighted to", "we're on a journey",
]


def auto_check(output):
    """Return list of rule violation strings. Empty list = all pass."""
    issues = []
    lower = output.lower()

    if "—" in output or "–" in output:
        issues.append("em-dash (— or –) in output")

    if re.search(r"\bactually\b", lower):
        issues.append("'actually' found")

    found_banned = [
        w for w in _BANNED_WORD_LIST
        if re.search(rf"\b{re.escape(w)}(?:ing|ed|ly|s|tion)?\b", lower)
    ]
    if found_banned:
        issues.append(f"banned words: {', '.join(found_banned)}")

    if any(lower.startswith(p) for p in _PREAMBLE_STARTS):
        issues.append("preamble/meta-commentary detected")

    found_nums = [w for w in _NUMBER_WORDS if re.search(rf"\b{w}\b", lower)]
    if found_nums:
        issues.append(f"number words: {', '.join(found_nums)}")

    found_filler = [p for p in _FILLER_PHRASES if p in lower]
    if found_filler:
        issues.append(f"filler phrases: {'; '.join(found_filler)}")

    if re.search(r"\.\s*--", output):
        issues.append("double-dash placed after a period")

    return issues


# ── Provider calls ────────────────────────────────────────────────────────────

def call_ollama(model, text, style, length, temperature):
    body = {
        "model": model,
        "prompt": f"Rewrite this voice-to-text:\n\n{text}",
        "system": build_system_prompt(style, length),
        "stream": False,
        "options": {"num_predict": 1024, "temperature": temperature},
    }
    req = urllib.request.Request(
        OLLAMA_URL,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=180) as r:
        data = json.loads(r.read())
    latency_ms = int((time.monotonic() - t0) * 1000)
    return data["response"].strip(), latency_ms, None, None


def call_anthropic(model, text, style, length, temperature, api_key):
    body = {
        "model": model,
        "max_tokens": 1024,
        "temperature": temperature,
        "system": [{"type": "text", "text": build_system_prompt(style, length), "cache_control": {"type": "ephemeral"}}],
        "messages": [{"role": "user", "content": f"Rewrite this voice-to-text:\n\n{text}"}],
    }
    req = urllib.request.Request(
        "https://api.anthropic.com/v1/messages",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "anthropic-beta": "prompt-caching-2024-07-31",
        },
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read())
    latency_ms = int((time.monotonic() - t0) * 1000)
    output = data["content"][0]["text"].strip()
    usage = data.get("usage", {})
    input_tokens = usage.get("input_tokens")
    output_tokens = usage.get("output_tokens")
    return output, latency_ms, input_tokens, output_tokens


def call_openai(model, text, style, length, temperature, api_key):
    body = {
        "model": model,
        "max_tokens": 1024,
        "temperature": temperature,
        "messages": [
            {"role": "system", "content": build_system_prompt(style, length)},
            {"role": "user", "content": f"Rewrite this voice-to-text:\n\n{text}"},
        ],
    }
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=json.dumps(body).encode(),
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {api_key}",
        },
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read())
    latency_ms = int((time.monotonic() - t0) * 1000)
    output = data["choices"][0]["message"]["content"].strip()
    usage = data.get("usage", {})
    input_tokens = usage.get("prompt_tokens")
    output_tokens = usage.get("completion_tokens")
    return output, latency_ms, input_tokens, output_tokens


def call_gemini(model, text, style, length, temperature, api_key):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
    body = {
        "system_instruction": {"parts": [{"text": build_system_prompt(style, length)}]},
        "contents": [{"role": "user", "parts": [{"text": f"Rewrite this voice-to-text:\n\n{text}"}]}],
        "generationConfig": {"maxOutputTokens": 1024, "temperature": temperature},
    }
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
    )
    t0 = time.monotonic()
    with urllib.request.urlopen(req, timeout=60) as r:
        data = json.loads(r.read())
    latency_ms = int((time.monotonic() - t0) * 1000)
    output = data["candidates"][0]["content"]["parts"][0]["text"].strip()
    usage = data.get("usageMetadata", {})
    input_tokens = usage.get("promptTokenCount")
    output_tokens = usage.get("candidatesTokenCount")
    return output, latency_ms, input_tokens, output_tokens


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Run a model against the eval corpus.")
    parser.add_argument("provider", choices=["ollama", "anthropic", "openai", "gemini"],
                        help="Provider: ollama | anthropic | openai | gemini")
    parser.add_argument("model", help="Model name, e.g. claude-haiku-4-5-20251001 or gemma2:9b")
    parser.add_argument("--cases", help="Comma-separated case IDs (default: all)")
    parser.add_argument("--temperature", type=float, default=0.3, help="Temperature (default 0.3)")
    parser.add_argument("--corpus", default="corpus.json",
                        help="Corpus filename in eval/ (default corpus.json)")
    parser.add_argument("--prompt-version", choices=["current", "candidate"], default="current",
                        help="Which system prompt to use (default current)")
    args = parser.parse_args()

    global PROMPT_VERSION
    PROMPT_VERSION = args.prompt_version

    # Resolve API key from env
    api_key = None
    env_vars = {
        "anthropic": "ANTHROPIC_API_KEY",
        "openai": "OPENAI_API_KEY",
        "gemini": "GEMINI_API_KEY",
    }
    if args.provider in env_vars:
        env_var = env_vars[args.provider]
        api_key = os.environ.get(env_var)
        if not api_key:
            sys.exit(f"Error: {env_var} not set. Run: export {env_var}=your-key-here")

    corpus = json.loads((EVAL_DIR / args.corpus).read_text())

    if args.cases:
        ids = set(args.cases.split(","))
        corpus = [c for c in corpus if c["id"] in ids]
        if not corpus:
            sys.exit(f"No corpus cases matched: {args.cases}")

    results = []
    passed = failed = errors = 0
    total_input_tokens = total_output_tokens = 0

    provider_label = f"{args.provider}/{args.model}"
    print(f"\nProvider: {args.provider}")
    print(f"Model:    {args.model}")
    print(f"Prompt:   {args.prompt_version}")
    print(f"Corpus:   {args.corpus}")
    print(f"Cases:    {len(corpus)}")
    print(f"Temp:     {args.temperature}\n")

    for case in corpus:
        label = f"  {case['id']}"
        print(f"{label:<32}", end="", flush=True)
        try:
            if args.provider == "ollama":
                output, latency_ms, in_tok, out_tok = call_ollama(
                    args.model, case["input"], case["style"],
                    case.get("length", "same"), args.temperature,
                )
            elif args.provider == "anthropic":
                output, latency_ms, in_tok, out_tok = call_anthropic(
                    args.model, case["input"], case["style"],
                    case.get("length", "same"), args.temperature, api_key,
                )
            elif args.provider == "openai":
                output, latency_ms, in_tok, out_tok = call_openai(
                    args.model, case["input"], case["style"],
                    case.get("length", "same"), args.temperature, api_key,
                )
            elif args.provider == "gemini":
                output, latency_ms, in_tok, out_tok = call_gemini(
                    args.model, case["input"], case["style"],
                    case.get("length", "same"), args.temperature, api_key,
                )

            issues = auto_check(output)
            status = "PASS" if not issues else f"FAIL({len(issues)})"

            c = cost_usd(args.model, in_tok or 0, out_tok or 0)
            cost_str = format_cost(args.model, c) if c is not None else ""
            token_str = f"{in_tok}+{out_tok}tok" if in_tok is not None else ""
            print(f"{status:<14} {latency_ms:>5}ms  {token_str:<16} {cost_str}")

            for issue in issues:
                print(f"    ✗ {issue}")

            if issues:
                failed += 1
            else:
                passed += 1
            if in_tok:
                total_input_tokens += in_tok
            if out_tok:
                total_output_tokens += out_tok

            results.append({
                "id": case["id"],
                "category": case["category"],
                "style": case["style"],
                "length": case.get("length", "same"),
                "input": case["input"],
                "output": output,
                "latency_ms": latency_ms,
                "input_tokens": in_tok,
                "output_tokens": out_tok,
                "cost_usd": c,
                "issues": issues,
                "notes": case.get("notes", ""),
            })
        except Exception as exc:
            print(f"ERROR: {exc}")
            errors += 1
            results.append({"id": case["id"], "error": str(exc)})

    total_cost = cost_usd(args.model, total_input_tokens, total_output_tokens)

    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    slug = f"{args.provider}_{args.model.replace(':', '-').replace('/', '-')}_{args.prompt_version}"
    out_path = RESULTS_DIR / f"{slug}_{ts}.json"

    out_path.write_text(json.dumps({
        "provider": args.provider,
        "model": args.model,
        "prompt_version": args.prompt_version,
        "corpus": args.corpus,
        "run_at": ts,
        "temperature": args.temperature,
        "auto_pass": passed,
        "auto_fail": failed,
        "errors": errors,
        "total": len(corpus),
        "total_input_tokens": total_input_tokens,
        "total_output_tokens": total_output_tokens,
        "total_cost_usd": total_cost,
        "results": results,
    }, indent=2))

    total = len(corpus)
    print(f"\nAuto-check: {passed}/{total} passed", end="")
    if errors:
        print(f"  ({errors} errors)", end="")
    if total_cost is not None:
        print(f"\nTotal cost: {format_cost(args.model, total_cost)}", end="")
        if total_input_tokens:
            print(f"  ({total_input_tokens:,} in + {total_output_tokens:,} out tokens)", end="")
    print(f"\nSaved:  eval/results/{out_path.name}")
    if total > 1:
        print(f"\nCompare: python3 eval/compare.py eval/results/{out_path.name} eval/results/<other>.json")
        print(f"  Blind: python3 eval/compare.py --blind eval/results/{out_path.name} eval/results/<other>.json")


if __name__ == "__main__":
    main()
