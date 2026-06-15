#!/usr/bin/env python3
"""
Harvest the user's edits into voice-learning signal.

Every time the user edits a rewrite in the panel and Copies/Pastes it, the app
stores his edited version next to what the model produced. The DIFF between the
two is the highest-signal training data that exists: "exactly what AI got wrong
about my voice." This script surfaces those tweaks so they can become new
few-shot examples in StylePresets.swift.

Usage:
    python3 eval/harvest-edits.py                 # all tweaks
    python3 eval/harvest-edits.py --since 30      # last 30 days
    python3 eval/harvest-edits.py --examples      # print as ready-to-paste examples
    python3 eval/harvest-edits.py --log           # append to docs/voice-learnings.md

Run it weekly or monthly (or just say "compound my edits" in a Claude Code
session and it'll read the output and propose prompt changes).
"""

import argparse
import difflib
import pathlib
import sqlite3
import os

DB = pathlib.Path.home() / "Library/Application Support/Wispr/wispr.sqlite"
LOG = pathlib.Path(__file__).resolve().parent.parent / "docs" / "voice-learnings.md"


# kind: "tweak"    -> editedText differs from AI (a correction)
#       "accepted" -> editedText == AI (accepted as-is = a perfect, endorsed example)
def fetch(kind, since_days=None):
    if not DB.exists():
        raise SystemExit(f"DB not found: {DB}")
    con = sqlite3.connect(f"file:{DB}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    cond = "editedText <> rewrittenText" if kind == "tweak" else "editedText = rewrittenText"
    q = f"""
        SELECT id, originalText, rewrittenText, editedText, modelId, styleId, createdAt
        FROM rewrites
        WHERE editedText IS NOT NULL
          AND TRIM(editedText) <> ''
          AND {cond}
    """
    if since_days:
        q += f"  AND createdAt >= datetime('now', '-{int(since_days)} days')\n"
    q += "ORDER BY id DESC"
    try:
        rows = con.execute(q).fetchall()
    except sqlite3.OperationalError as e:
        if "editedText" in str(e):
            con.close()
            raise SystemExit(
                "The editedText column doesn't exist yet. It's added by a lazy "
                "migration on your first rewrite with the new build -- do one "
                "rewrite, use it (Copy/Paste), then run this again."
            )
        raise
    con.close()
    return rows


def word_diff(ai, edited):
    a, b = ai.split(), edited.split()
    out = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(None, a, b).get_opcodes():
        if tag == "equal":
            continue
        removed = " ".join(a[i1:i2])
        added = " ".join(b[j1:j2])
        if tag == "replace":
            out.append(f'"{removed}" -> "{added}"')
        elif tag == "delete":
            out.append(f'cut "{removed}"')
        elif tag == "insert":
            out.append(f'added "{added}"')
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--since", type=int, help="Only tweaks from the last N days")
    ap.add_argument("--examples", action="store_true",
                    help="Print as StylePresets-ready input->output example pairs")
    ap.add_argument("--log", action="store_true",
                    help="Append a dated section to docs/voice-learnings.md")
    args = ap.parse_args()

    accepted = fetch("accepted", args.since)
    tweaks = fetch("tweak", args.since)
    window = f" in the last {args.since} days" if args.since else ""

    if not accepted and not tweaks:
        print("No signal captured yet. Use a few rewrites (Copy/Paste) -- edit the "
              "ones that need it, accept the perfect ones as-is.")
        return

    print(f"{len(accepted)} accepted as-is (perfect), {len(tweaks)} tweaked{window}.\n")

    if args.examples:
        # Both feed the StylePresets `Examples` block. Accepted = positive examples
        # the model already nails; tweaks = corrections in his voice.
        if accepted:
            print("# --- ACCEPTED AS-IS (gold positive examples) ---")
            for r in accepted:
                print(f'Input: "{r["originalText"].strip()}"')
                print(f'Output: "{r["editedText"].strip()}"')
                print()
        if tweaks:
            print("# --- TWEAKED (his corrections) ---")
            for r in tweaks:
                print(f'Input: "{r["originalText"].strip()}"')
                print(f'Output: "{r["editedText"].strip()}"')
                print()
        return

    if accepted:
        print("######## ACCEPTED AS-IS (what already sounds like him) ########\n")
        for r in accepted:
            print(f'#{r["id"]}  {r["createdAt"]}  ({r["modelId"]}, {r["styleId"]})')
            print(f'  INPUT : {r["originalText"].strip()}')
            print(f'  PERFECT: {r["editedText"].strip()}')
            print()

    if tweaks:
        print("######## TWEAKED (what to learn from) ########\n")
        for r in tweaks:
            diffs = word_diff(r["rewrittenText"], r["editedText"])
            print("=" * 88)
            print(f'#{r["id"]}  {r["createdAt"]}  ({r["modelId"]}, {r["styleId"]})')
            print(f'  INPUT : {r["originalText"].strip()}')
            print(f'  AI    : {r["rewrittenText"].strip()}')
            print(f'  YOURS : {r["editedText"].strip()}')
            if diffs:
                print(f'  CHANGED: {"; ".join(diffs)}')
            print()

    rows = tweaks  # the log section below details corrections
    if args.log:
        LOG.parent.mkdir(parents=True, exist_ok=True)
        with open(LOG, "a") as f:
            f.write(f"\n## Harvest ({len(rows)} tweaks)\n\n")
            for r in rows:
                diffs = word_diff(r["rewrittenText"], r["editedText"])
                f.write(f"- **#{r['id']}** ({r['styleId']}): "
                        f"{'; '.join(diffs) if diffs else 'reworded'}\n")
                f.write(f"  - input: {r['originalText'].strip()}\n")
                f.write(f"  - yours: {r['editedText'].strip()}\n")
        print(f"Appended to {LOG}")


if __name__ == "__main__":
    main()
