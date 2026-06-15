#!/usr/bin/env python3
"""
Generate a side-by-side comparison report from 2+ eval run result files.

Usage:
    python3 eval/compare.py eval/results/a.json eval/results/b.json
    python3 eval/compare.py eval/results/a.json eval/results/b.json eval/results/c.json

    # Blind mode: models labeled A/B/C/D per case; key revealed at end
    python3 eval/compare.py --blind eval/results/a.json eval/results/b.json
"""

import argparse
import json
import pathlib
import random
import datetime
import string

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


def fmt_cost(run, total=False):
    """Format total or per-run cost for summary table."""
    if total:
        c = run.get("total_cost_usd")
        model = run.get("model", "")
        free = model in {"gemini-2.0-flash", "gemini-1.5-flash"}
        if c is None:
            return "n/a (local)"
        if free:
            return f"~${c:.4f} ¹"
        return f"${c:.4f}"
    return ""


def avg_cost_per_case(run):
    results = [r for r in run["results"] if r.get("cost_usd") is not None]
    if not results:
        return None
    return sum(r["cost_usd"] for r in results) / len(results)


def fmt_per_case_cost(cost, model):
    if cost is None:
        return "n/a"
    free = model in {"gemini-2.0-flash", "gemini-1.5-flash"}
    if free:
        return f"~${cost:.6f} ¹"
    return f"${cost:.6f}"


def main():
    parser = argparse.ArgumentParser(description="Compare 2+ eval result files.")
    parser.add_argument("files", nargs="+", help="Result JSON files to compare")
    parser.add_argument("--blind", action="store_true",
                        help="Hide model names in per-case sections; show key at end")
    args = parser.parse_args()

    runs = [load_run(p) for p in args.files]
    by_id = [result_by_id(r) for r in runs]

    # Assign blind labels (same random order for every case)
    labels = list(string.ascii_uppercase[:len(runs)])
    blind_order = list(range(len(runs)))
    if args.blind:
        random.shuffle(blind_order)
    blind_label = {i: labels[pos] for pos, i in enumerate(blind_order)}

    all_ids = []
    seen = set()
    for r in runs:
        for res in r["results"]:
            if res["id"] not in seen:
                all_ids.append(res["id"])
                seen.add(res["id"])

    lines = []
    ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
    blind_tag = " (BLIND)" if args.blind else ""

    lines.append(f"# Model Comparison Report{blind_tag}")
    lines.append(f"Generated: {ts}")
    if args.blind:
        lines.append("")
        lines.append("> **Blind mode:** models are labeled A/B/C/D. Score each case before scrolling to the key at the bottom.")
    lines.append("")

    # ── Summary table ─────────────────────────────────────────────────────────
    lines.append("## Auto-Check Summary")
    lines.append("")

    has_cost = any(r.get("total_cost_usd") is not None for r in runs)
    has_tokens = any(r.get("total_input_tokens") for r in runs)

    header_cells = ["Model", "Temp", "Pass", "Fail", "Errors", "Avg Latency"]
    if has_tokens:
        header_cells.append("Tokens (in+out)")
    if has_cost:
        header_cells += ["Total Cost", "Avg/Case"]

    lines.append("| " + " | ".join(header_cells) + " |")
    lines.append("| " + " | ".join(["---"] * len(header_cells)) + " |")

    for i, run in enumerate(runs):
        results_with_latency = [r for r in run["results"] if "latency_ms" in r]
        avg_latency = (
            int(sum(r["latency_ms"] for r in results_with_latency) / len(results_with_latency))
            if results_with_latency else 0
        )
        display_name = blind_label[i] if args.blind else f"**{run['model']}**"
        row = [
            display_name,
            str(run.get("temperature", "?")),
            str(run.get("auto_pass", "?")),
            str(run.get("auto_fail", "?")),
            str(run.get("errors", 0)),
            f"{avg_latency}ms",
        ]
        if has_tokens:
            in_t = run.get("total_input_tokens", 0)
            out_t = run.get("total_output_tokens", 0)
            row.append(f"{in_t:,} + {out_t:,}" if in_t else "n/a")
        if has_cost:
            row.append(fmt_cost(run, total=True))
            apc = avg_cost_per_case(run)
            row.append(fmt_per_case_cost(apc, run.get("model", "")) if apc is not None else "n/a")
        lines.append("| " + " | ".join(row) + " |")

    lines.append("")
    if any(run.get("model") in {"gemini-2.0-flash", "gemini-1.5-flash"} for run in runs):
        lines.append("¹ _Gemini Flash: costs shown are what you'd pay after the free tier. Within the free tier (15 RPM / 1M tokens/day) the actual cost is $0._")
        lines.append("")

    # ── Category breakdown ────────────────────────────────────────────────────
    categories = {}
    for case_id in all_ids:
        for i, run in enumerate(runs):
            res = by_id[i].get(case_id)
            if res and "error" not in res:
                cat = res.get("category", "unknown")
                if cat not in categories:
                    categories[cat] = {j: {"pass": 0, "total": 0} for j in range(len(runs))}
                categories[cat][i]["total"] += 1
                if not res.get("issues"):
                    categories[cat][i]["pass"] += 1

    if categories:
        lines.append("## Pass Rate by Category")
        lines.append("")
        if args.blind:
            cat_header = ["Category"] + [blind_label[i] for i in range(len(runs))]
        else:
            cat_header = ["Category"] + [r["model"] for r in runs]
        lines.append("| " + " | ".join(cat_header) + " |")
        lines.append("| " + " | ".join(["---"] * len(cat_header)) + " |")
        for cat, model_data in sorted(categories.items()):
            row = [cat]
            for i in range(len(runs)):
                md = model_data.get(i, {"pass": 0, "total": 0})
                row.append(f"{md['pass']}/{md['total']}")
            lines.append("| " + " | ".join(row) + " |")
        lines.append("")

    # ── Per-case detail ───────────────────────────────────────────────────────
    lines.append("---")
    lines.append("")
    lines.append("## Case-by-Case Detail")
    lines.append("")
    lines.append("Each case shows: auto-check result, word count, latency, cost, then the full output.")
    lines.append("Fill in human scores after reading each output.")
    lines.append("")

    for case_id in all_ids:
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

        display_indices = blind_order if args.blind else list(range(len(runs)))
        for i in display_indices:
            run = runs[i]
            res = by_id[i].get(case_id)
            display_name = blind_label[i] if args.blind else run["model"]
            lines.append(f"#### Model {display_name}" if args.blind else f"#### {display_name}")
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

                meta_parts = [badge, f"{wc} words ({delta_str})", f"{res['latency_ms']}ms"]
                if res.get("input_tokens") is not None:
                    meta_parts.append(f"{res['input_tokens']}+{res['output_tokens']}tok")
                if res.get("cost_usd") is not None:
                    meta_parts.append(fmt_per_case_cost(res["cost_usd"], run.get("model", "")))
                lines.append("  |  ".join(meta_parts))

                if res["issues"]:
                    for issue in res["issues"]:
                        lines.append(f"- ✗ {issue}")
                lines.append("")
                lines.append(res["output"])
            lines.append("")

        lines.append("**Human scores** _(fill in after reading — before looking at the key)_:")
        lines.append("")
        score_header = ["Model", "Meaning (1-5)", "Voice (1-5)", "Would send? (Y/N/Edit)", "Notes"]
        lines.append("| " + " | ".join(score_header) + " |")
        lines.append("| " + " | ".join(["---"] * len(score_header)) + " |")
        for i in display_indices:
            display_name = blind_label[i] if args.blind else runs[i]["model"]
            lines.append(f"| {'Model ' + display_name if args.blind else display_name} | | | | |")
        lines.append("")
        lines.append("---")
        lines.append("")

    # ── Overall human scoring table ───────────────────────────────────────────
    lines.append("## Overall Human Scores")
    lines.append("")
    lines.append("Roll up your per-case scores here after reviewing all cases.")
    lines.append("")
    overall_header = ["Model", "Meaning avg", "Voice avg", "Send rate", "Winner cases", "Total cost", "Notes"]
    lines.append("| " + " | ".join(overall_header) + " |")
    lines.append("| " + " | ".join(["---"] * len(overall_header)) + " |")
    for i in display_indices:
        run = runs[i]
        display_name = blind_label[i] if args.blind else run["model"]
        cost_cell = fmt_cost(run, total=True)
        lines.append(f"| {'Model ' + display_name if args.blind else display_name} | | | | | {cost_cell} | |")
    lines.append("")
    lines.append("**Recommendation:** _(which model to set as default and why)_")
    lines.append("")

    # ── Blind key (revealed at end) ───────────────────────────────────────────
    if args.blind:
        lines.append("---")
        lines.append("")
        lines.append("## 🔑 Blind Key")
        lines.append("")
        lines.append("_Reveal only after completing all human scores above._")
        lines.append("")
        for i, run in enumerate(runs):
            lines.append(f"- **Model {blind_label[i]}** = `{run['model']}` ({run.get('provider', 'ollama')})")
        lines.append("")

    # ── Write output ──────────────────────────────────────────────────────────
    model_slugs = "_vs_".join(
        r["model"].replace(":", "-").replace("/", "-") for r in runs
    )
    blind_suffix = "_blind" if args.blind else ""
    out_ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out_path = EVAL_DIR / "results" / f"compare_{model_slugs}{blind_suffix}_{out_ts}.md"
    out_path.write_text("\n".join(lines))

    print(f"Report saved: eval/results/{out_path.name}")
    print(f"Open with:    open {out_path}")


if __name__ == "__main__":
    main()
