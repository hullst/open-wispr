#!/usr/bin/env python3
"""
synthesize.py -- produce a CONTENT-FREE voice profile from local edits.

PRIVACY MODEL (read this):
  On the work machine the raw transcripts/rewrites/edits must NEVER leave. This
  script reads them LOCALLY but emits ONLY aggregate, content-free signal:
  counts, percentages, and style categories drawn from a FIXED allowlist defined
  in this file. By construction it cannot print a transcript sentence, a name, a
  project, or any free text from your data -- every string it outputs is hardcoded
  here, never pulled from the DB. Eyeball the output; if it's only numbers and
  the style words below, it's safe to carry to the other machine.

  This is how you train on both machines without the words you said at work ever
  leaving the work laptop. Only the synthesis crosses.

Usage:
  python3 eval/synthesize.py                 # print the profile (human-readable)
  python3 eval/synthesize.py --json out.json # write profile JSON (still content-free)
  python3 eval/synthesize.py --label work    # tag which machine it came from
"""

import argparse
import difflib
import json
import pathlib
import re
import sqlite3

DB = pathlib.Path.home() / "Library/Application Support/Wispr/wispr.sqlite"

# ── The allowlist: the ONLY style words this script will ever emit ────────────
# These are AI-tells / style vocabulary, not your content. Emitting "you removed
# 'leverage' 6 times" is safe -- "leverage" is a generic AI word from this list,
# never a word pulled from your transcript.
BANNED_WORDS = {
    "delve", "leverage", "utilize", "utilization", "robust", "seamless",
    "comprehensive", "holistic", "foster", "unlock", "elevate", "empower",
    "spearhead", "synergy", "synergize", "paradigm", "tapestry", "testament",
    "beacon", "vibrant", "bustling", "cutting-edge", "world-class",
    "best-in-class", "supercharge", "streamline", "underscore", "myriad",
    "plethora", "embark", "harness", "meticulous", "effortless", "intricate",
    "actually", "furthermore", "moreover",
}
FILLER_PHRASES = {
    "it's worth noting", "at the end of the day", "rest assured", "circle back",
    "touch base", "deep dive", "move the needle", "needless to say",
}


def fetch_tweaks():
    if not DB.exists():
        raise SystemExit(f"DB not found: {DB}")
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    try:
        rows = con.execute("""
            SELECT rewrittenText, editedText FROM rewrites
            WHERE editedText IS NOT NULL AND TRIM(editedText) <> ''
              AND editedText <> rewrittenText
        """).fetchall()
    except sqlite3.OperationalError as e:
        if "editedText" in str(e):
            raise SystemExit("No editedText column yet -- use a few rewrites first.")
        raise
    finally:
        con.close()
    return rows


def sentences(text):
    return [s for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s]


def analyze(rows):
    n = len(rows)
    length_deltas = []
    shortened = 0
    banned_removed = {}          # allowlisted word -> count
    filler_removed = {}          # allowlisted phrase -> count
    em_dash_removed = 0
    ellipsis_added = 0
    double_dash_added = 0
    cut_opener = 0
    cut_closer = 0
    other_rewords = 0

    for r in rows:
        ai, mine = r["rewrittenText"], r["editedText"]
        ai_l, mine_l = ai.lower(), mine.lower()

        # length
        wa, wm = len(ai.split()), len(mine.split())
        if wa:
            length_deltas.append((wm - wa) / wa)
        if wm < wa:
            shortened += 1

        # banned words he removed (present in AI, gone in his edit)
        for w in BANNED_WORDS:
            pat = rf"\b{re.escape(w)}\b"
            a = len(re.findall(pat, ai_l))
            m = len(re.findall(pat, mine_l))
            if a > m:
                banned_removed[w] = banned_removed.get(w, 0) + (a - m)
        for ph in FILLER_PHRASES:
            if ph in ai_l and ph not in mine_l:
                filler_removed[ph] = filler_removed.get(ph, 0) + 1

        # punctuation preferences
        em_dash_removed += max(0, (ai.count("—") + ai.count("–")) - (mine.count("—") + mine.count("–")))
        ellipsis_added += max(0, (mine.count("...") + mine.count("…")) - (ai.count("...") + ai.count("…")))
        double_dash_added += max(0, mine.count(" -- ") - ai.count(" -- "))

        # structural: did he drop the AI's first/last sentence?
        sa, sm = sentences(ai), sentences(mine)
        if len(sm) < len(sa) and sa:
            if sa[0] not in sm:
                cut_opener += 1
            if sa[-1] not in sm:
                cut_closer += 1
        # changes that aren't any known category -> counted, never described
        diff_ops = [op for op in difflib.SequenceMatcher(None, ai.split(), mine.split())
                    .get_opcodes() if op[0] != "equal"]
        if diff_ops and not (banned_removed or filler_removed):
            other_rewords += 1

    avg_delta = round(sum(length_deltas) / len(length_deltas) * 100, 1) if length_deltas else 0.0
    return {
        "edits_analyzed": n,
        "avg_length_change_pct": avg_delta,
        "shorten_rate_pct": round(shortened / n * 100, 1) if n else 0.0,
        "banned_words_he_removes": dict(sorted(banned_removed.items(), key=lambda x: -x[1])),
        "filler_he_removes": dict(sorted(filler_removed.items(), key=lambda x: -x[1])),
        "punctuation": {
            "em_dashes_he_removed": em_dash_removed,
            "ellipses_he_added": ellipsis_added,
            "double_dashes_he_added": double_dash_added,
        },
        "structural": {
            "cut_opening_sentence": cut_opener,
            "cut_closing_sentence": cut_closer,
            "other_uncategorized_rewords": other_rewords,
        },
    }


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--json", help="Write profile to this JSON file")
    ap.add_argument("--label", default="unlabeled", help="Machine label, e.g. work / personal")
    args = ap.parse_args()

    rows = fetch_tweaks()
    profile = {"label": args.label, **analyze(rows)}

    if args.json:
        pathlib.Path(args.json).write_text(json.dumps(profile, indent=2))
        print(f"Wrote content-free profile -> {args.json}")
        print("Open it and confirm it's only numbers + the allowlisted style words "
              "before moving it off this machine.")
    else:
        print(json.dumps(profile, indent=2))
    print("\n(Content-free. No transcript text, names, or subject matter included.)")


if __name__ == "__main__":
    main()
