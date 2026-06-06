#!/usr/bin/env python3
"""
Generate a side-by-side comparison report from 2+ eval run result files.

Usage:
    python3 eval/compare.py eval/results/gemma2-9b_20260605.json eval/results/qwen3-8b_20260605.json
    python3 eval/compare.py eval/results/a.json eval/results/b.json eval/results/c.json
"""

import json
import pathlib
import sys
import datetime

EVAL_DIR = pathlib.Path(__file__).parent


def load_run(path):
    return json.loads(pathlib.Path(path).read_text())


def result_by_id(run):
    return {r["id"]: r for r in run["results"]}


def check_badge(issues):
    if not issues:
        return "✅ PASS"
    return f"❌ FAIL ({len(issues)})"


def word_count(text):
    return len(text.split())


def main():
    if len(sys.argv) < 3:
        sys.exit("Usage: python3 eval/compare.py <result1.json> <result2.json> [result3.json ...]")

    runs = [load_run(p) for p in sys.argv[1:]]
    by_id = [result_by_id(r) for r in runs]

    # Collect all case IDs in corpus order
    all_ids = []
    seen = set()
    for r in runs:
        for res in r["results"]:
            if res["id"] not in seen:
                all_ids.append(res["id"])
                seen.add(res["id"])

    lines = []
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")

    # ── Header ────────────────────────────────────────────────────────────────
    lines.append(f"# Model Comparison Report")
    lines.append(f"Generated: {ts}")
    lines.append("")

    # ── Summary table ─────────────────────────────────────────────────────────
    lines.append("## Auto-Check Summary")
    lines.append("")

    header_cells = ["Model", "Temp", "Pass", "Fail", "Errors", "Avg Latency"]
    lines.append("| " + " | ".join(header_cells) + " |")
    lines.append("| " + " | ".join(["---"] * len(header_cells)) + " |")

    for run in runs:
        results_with_latency = [r for r in run["results"] if "latency_ms" in r]
        avg_latency = (
            int(sum(r["latency_ms"] for r in results_with_latency) / len(results_with_latency))
            if results_with_latency else 0
        )
        row = [
            f"**{run['model']}**",
            str(run.get("temperature", "?")),
            str(run.get("auto_pass", "?")),
            str(run.get("auto_fail", "?")),
            str(run.get("errors", 0)),
            f"{avg_latency}ms",
        ]
        lines.append("| " + " | ".join(row) + " |")

    lines.append("")

    # ── Category breakdown ────────────────────────────────────────────────────
    categories = {}
    for case_id in all_ids:
        for i, run in enumerate(runs):
            res = by_id[i].get(case_id)
            if res and "error" not in res:
                cat = res.get("category", "unknown")
                if cat not in categories:
                    categories[cat] = {r["model"]: {"pass": 0, "total": 0} for r in runs}
                categories[cat][run["model"]]["total"] += 1
                if not res.get("issues"):
                    categories[cat][run["model"]]["pass"] += 1

    if categories:
        lines.append("## Pass Rate by Category")
        lines.append("")
        cat_header = ["Category"] + [r["model"] for r in runs]
        lines.append("| " + " | ".join(cat_header) + " |")
        lines.append("| " + " | ".join(["---"] * len(cat_header)) + " |")
        for cat, model_data in sorted(categories.items()):
            row = [cat]
            for run in runs:
                md = model_data.get(run["model"], {"pass": 0, "total": 0})
                row.append(f"{md['pass']}/{md['total']}")
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")

    # ── Per-case detail ───────────────────────────────────────────────────────
    lines.append("---")
    lines.append("")
    lines.append("## Case-by-Case Detail")
    lines.append("")
    lines.append("Each case shows: auto-check result, word count, then the full output.")
    lines.append("Human scores go in the scoring table at the end.")
    lines.append("")

    for case_id in all_ids:
        # Get case metadata from whichever run has it
        meta = None
        for res_map in by_id:
            if case_id in res_map and "error" not in res_map[case_id]:
                meta = res_map[case_id]
                break
        if meta is None:
            continue

        lines.append(f"### `{case_id}`")
        lines.append(f"**Category:** {meta['category']}  |  **Style:** {meta['style']}  |  **Length:** {meta['length']}")
        if meta.get("notes"):
            lines.append(f"**What to watch:** {meta['notes']}")
        lines.append("")
        lines.append(f"**Input:**")
        lines.append(f"> {meta['input']}")
        lines.append("")

        for i, run in enumerate(runs):
            res = by_id[i].get(case_id)
            lines.append(f"#### {run['model']}")
            if res is None:
                lines.append("_Not run_")
            elif "error" in res:
                lines.append(f"**ERROR:** {res['error']}")
            else:
                badge = check_badge(res["issues"])
                wc = word_count(res["output"])
                input_wc = word_count(res["input"])
                delta = wc - input_wc
                delta_str = f"+{delta}" if delta > 0 else str(delta)
                lines.append(f"{badge}  |  {wc} words ({delta_str} vs input)  |  {res['latency_ms']}ms")
                if res["issues"]:
                    for issue in res["issues"]:
                        lines.append(f"- ✗ {issue}")
                lines.append("")
                lines.append(res["output"])
            lines.append("")

        lines.append("**Human scores** _(fill in after reading)_:")
        lines.append("")
        score_header = ["Model", "Meaning (1-5)", "Voice (1-5)", "Would send? (Y/N/Edit)", "Notes"]
        lines.append("| " + " | ".join(score_header) + " |")
        lines.append("| " + " | ".join(["---"] * len(score_header)) + " |")
        for run in runs:
            lines.append(f"| {run['model']} | | | | |")
        lines.append("")
        lines.append("---")
        lines.append("")

    # ── Overall human scoring table ───────────────────────────────────────────
    lines.append("## Overall Human Scores")
    lines.append("")
    lines.append("Roll up your per-case scores here after reviewing all cases.")
    lines.append("")
    overall_header = ["Model", "Meaning avg", "Voice avg", "Send rate", "Winner cases", "Notes"]
    lines.append("| " + " | ".join(overall_header) + " |")
    lines.append("| " + " | ".join(["---"] * len(overall_header)) + " |")
    for run in runs:
        lines.append(f"| {run['model']} | | | | | |")
    lines.append("")
    lines.append("**Recommendation:** _(which model to set as default and why)_")
    lines.append("")

    # ── Write output ──────────────────────────────────────────────────────────
    model_slugs = "_vs_".join(r["model"].replace(":", "-") for r in runs)
    out_ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = EVAL_DIR / "results" / f"compare_{model_slugs}_{out_ts}.md"
    out_path.write_text("\n".join(lines))

    print(f"Report saved: eval/results/{out_path.name}")
    print(f"Open with:    open {out_path}")


if __name__ == "__main__":
    main()
