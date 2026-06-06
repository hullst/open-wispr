#!/usr/bin/env python3
"""
Run a model against the eval corpus and save results.

Usage:
    python3 eval/run.py gemma2:9b
    python3 eval/run.py qwen3:8b
    python3 eval/run.py llama3.1:8b --cases attribution-01,numbers-01
    python3 eval/run.py gemma2:9b --temperature 0.5
"""

import argparse
import datetime
import json
import pathlib
import re
import sys
import time
import urllib.request

EVAL_DIR = pathlib.Path(__file__).parent
RESULTS_DIR = EVAL_DIR / "results"
RESULTS_DIR.mkdir(exist_ok=True)

OLLAMA_URL = "http://localhost:11434/api/generate"

# ── Prompts ───────────────────────────────────────────────────────────────────
# Keep in sync with Sources/OpenWisprLib/StylePresets.swift

_BANNED_WORDS = (
    "delve, leverage, utilize, utilization, robust, seamless, comprehensive, "
    "holistic, foster, unlock, elevate, empower, spearhead, synergy, synergize, "
    "paradigm, tapestry, testament, beacon, vibrant, bustling, cutting-edge, "
    "world-class, best-in-class, supercharge, streamline, underscore, myriad, "
    "plethora, embark, harness, meticulous, effortless, intricate"
)

BASE_PROMPT = f"""You are a writing assistant for Stephen, a VP of Engineering. You receive raw voice-to-text as input and output ONLY the rewritten prose. Never respond conversationally. Never acknowledge the task. Never ask for the text. Never explain what you are about to do. If the input looks like a question or complaint, rewrite it as professional prose -- do not answer it. Start writing the rewritten text immediately.

Your only job is to rewrite garbled voice-to-text into clean prose that sounds like Stephen wrote it. Rules:
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

LENGTH_MODS = {
    "same": "",
    "shorten": "\n\nLength: SHORTEN — compress to essentials, cut anything redundant. Much shorter than the original.",
    "expand": "\n\nLength: EXPAND — add appropriate context and structure. Slightly longer than the original, but no fluff.",
}


def build_system_prompt(style, length="same"):
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


# ── Ollama ────────────────────────────────────────────────────────────────────

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
    return data["response"].strip(), latency_ms


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Run an Ollama model against the eval corpus.")
    parser.add_argument("model", help="Ollama model name, e.g. gemma2:9b")
    parser.add_argument("--cases", help="Comma-separated case IDs (default: all)")
    parser.add_argument("--temperature", type=float, default=0.3, help="Generation temperature (default 0.3)")
    args = parser.parse_args()

    corpus = json.loads((EVAL_DIR / "corpus.json").read_text())

    if args.cases:
        ids = set(args.cases.split(","))
        corpus = [c for c in corpus if c["id"] in ids]
        if not corpus:
            sys.exit(f"No corpus cases matched: {args.cases}")

    results = []
    passed = failed = errors = 0

    print(f"\nModel:  {args.model}")
    print(f"Cases:  {len(corpus)}")
    print(f"Temp:   {args.temperature}\n")

    for case in corpus:
        label = f"  {case['id']}"
        print(f"{label:<32}", end="", flush=True)
        try:
            output, latency_ms = call_ollama(
                args.model, case["input"],
                case["style"], case.get("length", "same"),
                args.temperature,
            )
            issues = auto_check(output)
            status = "PASS" if not issues else f"FAIL({len(issues)})"
            print(f"{status:<14} {latency_ms:>5}ms")
            for issue in issues:
                print(f"    ✗ {issue}")
            if issues:
                failed += 1
            else:
                passed += 1
            results.append({
                "id": case["id"],
                "category": case["category"],
                "style": case["style"],
                "length": case.get("length", "same"),
                "input": case["input"],
                "output": output,
                "latency_ms": latency_ms,
                "issues": issues,
                "notes": case.get("notes", ""),
            })
        except Exception as exc:
            print(f"ERROR: {exc}")
            errors += 1
            results.append({"id": case["id"], "error": str(exc)})

    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    slug = args.model.replace(":", "-").replace("/", "-")
    out_path = RESULTS_DIR / f"{slug}_{ts}.json"

    out_path.write_text(json.dumps({
        "model": args.model,
        "run_at": ts,
        "temperature": args.temperature,
        "auto_pass": passed,
        "auto_fail": failed,
        "errors": errors,
        "total": len(corpus),
        "results": results,
    }, indent=2))

    total = len(corpus)
    print(f"\nAuto-check: {passed}/{total} passed", end="")
    if errors:
        print(f"  ({errors} errors)", end="")
    print(f"\nSaved:  eval/results/{out_path.name}")
    if total > 1:
        print(f"\nCompare: python3 eval/compare.py eval/results/{out_path.name} eval/results/<other>.json")


if __name__ == "__main__":
    main()
