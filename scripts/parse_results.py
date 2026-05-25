#!/usr/bin/env python3
"""
parse_results.py — Aggregate scan results and produce a GitHub Actions job summary.

Usage: python parse_results.py <results_dir>

Reads all *_meta.json and tool-specific result files from the results directory,
then writes a markdown summary to GITHUB_STEP_SUMMARY (or stdout).
"""

import json
import os
import sys
import glob
from pathlib import Path
from datetime import datetime

try:
    from tabulate import tabulate
except ImportError:
    tabulate = None


def parse_garak_results(results_dir: str) -> dict:
    """Parse Garak's JSON Lines report file.

    Garak writes several file types:
      - *.report.jsonl  — main report with entry_type = "eval", "init", "config", etc.
      - *.hitlog.jsonl  — only the hits/failures
      - *.html          — human-readable summary

    We look for .report.jsonl first, then fall back to any .jsonl.
    """
    # Try the standard .report.jsonl naming first
    report_files = glob.glob(os.path.join(results_dir, "*.report.jsonl"))
    if not report_files:
        # Fall back to any garak-related jsonl
        report_files = glob.glob(os.path.join(results_dir, "garak*.jsonl"))
    if not report_files:
        # Last resort: any jsonl at all
        report_files = glob.glob(os.path.join(results_dir, "*.jsonl"))

    findings = []
    total_probes = 0
    total_passed = 0
    total_failed = 0

    for rf in report_files:
        # Skip hitlog files for counting (they only contain failures)
        if "hitlog" in rf:
            continue
        with open(rf, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Garak report entry types: "init", "config", "eval", "end"
                # The "eval" entries contain the actual probe results
                if entry.get("entry_type") == "eval":
                    total_probes += 1
                    passed = entry.get("passed", None)
                    probe = entry.get("probe", "unknown")
                    detector = entry.get("detector", "unknown")
                    score = entry.get("score", None)
                    # Some versions use "status" field
                    status = entry.get("status", None)

                    if passed is True or status == "PASS":
                        total_passed += 1
                    elif passed is False or status == "FAIL":
                        total_failed += 1
                        findings.append({
                            "probe": probe,
                            "detector": detector,
                            "score": score,
                            "status": "FAIL",
                        })
                    else:
                        # Unknown status — count but don't categorize
                        total_passed += 1

    # If we found no eval entries in report files, check hitlog for failures
    if total_probes == 0:
        hitlog_files = glob.glob(os.path.join(results_dir, "*.hitlog.jsonl"))
        for hf in hitlog_files:
            with open(hf, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    total_probes += 1
                    total_failed += 1
                    findings.append({
                        "probe": entry.get("probe", "unknown"),
                        "detector": entry.get("detector", "unknown"),
                        "score": entry.get("score", None),
                        "status": "FAIL",
                    })

    return {
        "total_probes": total_probes,
        "passed": total_passed,
        "failed": total_failed,
        "findings": findings,
    }


def load_meta_files(results_dir: str) -> list:
    """Load all tool metadata files."""
    metas = []
    for meta_file in glob.glob(os.path.join(results_dir, "*_meta.json")):
        with open(meta_file, "r") as f:
            metas.append(json.load(f))
    return metas


def generate_summary(results_dir: str) -> str:
    """Generate a markdown summary of all scan results."""
    lines = []
    lines.append("# 🛡️ LLM Security Scan Report")
    lines.append(f"**Generated:** {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}")
    lines.append("")

    # Load metadata
    metas = load_meta_files(results_dir)

    if not metas:
        lines.append("⚠️ No scan results found.")
        # List what files ARE present for debugging
        all_files = os.listdir(results_dir) if os.path.isdir(results_dir) else []
        if all_files:
            lines.append("")
            lines.append("Files in results directory:")
            for f in sorted(all_files):
                lines.append(f"- `{f}`")
        return "\n".join(lines)

    # Overview table
    lines.append("## Overview")
    lines.append("")
    overview_rows = []
    for m in metas:
        status = "✅ Passed" if m.get("exit_code", 1) == 0 else "❌ Failed"
        duration = f"{m.get('duration_seconds', '?')}s"
        overview_rows.append([
            m.get("tool", "unknown"),
            m.get("model_id", "unknown"),
            status,
            duration,
            m.get("timestamp", ""),
        ])

    headers = ["Tool", "Model", "Status", "Duration", "Timestamp"]
    if tabulate:
        lines.append(tabulate(overview_rows, headers=headers, tablefmt="github"))
    else:
        # Fallback: simple markdown table
        lines.append("| " + " | ".join(headers) + " |")
        lines.append("| " + " | ".join(["---"] * len(headers)) + " |")
        for row in overview_rows:
            lines.append("| " + " | ".join(str(c) for c in row) + " |")
    lines.append("")

    # Tool-specific results
    for m in metas:
        tool = m.get("tool", "unknown")
        lines.append(f"## {tool.capitalize()} Results")
        lines.append("")

        if tool == "garak":
            garak = parse_garak_results(results_dir)
            lines.append(f"- **Total probes:** {garak['total_probes']}")
            lines.append(f"- **Passed:** {garak['passed']}")
            lines.append(f"- **Failed:** {garak['failed']}")
            lines.append("")

            if garak["findings"]:
                lines.append("### Findings")
                lines.append("")
                finding_rows = []
                for f in garak["findings"][:50]:  # Cap at 50
                    finding_rows.append([
                        f.get("probe", ""),
                        f.get("detector", ""),
                        f.get("score", ""),
                        f.get("status", ""),
                    ])
                f_headers = ["Probe", "Detector", "Score", "Status"]
                if tabulate:
                    lines.append(tabulate(finding_rows, headers=f_headers, tablefmt="github"))
                else:
                    lines.append("| " + " | ".join(f_headers) + " |")
                    lines.append("| " + " | ".join(["---"] * len(f_headers)) + " |")
                    for row in finding_rows:
                        lines.append("| " + " | ".join(str(c) for c in row) + " |")

                if len(garak["findings"]) > 50:
                    lines.append(f"\n_...and {len(garak['findings']) - 50} more findings. See full artifacts._")
            elif garak["total_probes"] == 0:
                lines.append("⚠️ **No probe results found.** Garak may have failed to connect to the model.")
                lines.append("")
                lines.append("Check the `garak_stdout.log` artifact for errors. Common causes:")
                lines.append("- Missing or invalid `HF_TOKEN` for gated models")
                lines.append("- Model not available on HuggingFace Inference API")
                lines.append("- Incorrect `model_type` (try `huggingface` for HF Hub models)")
            else:
                lines.append("✅ No vulnerabilities detected.")
            lines.append("")
        else:
            # Generic: just list files produced
            tool_files = [
                f for f in os.listdir(results_dir)
                if f.startswith(tool) and not f.endswith("_meta.json")
            ]
            if tool_files:
                lines.append("Result files:")
                for tf in tool_files:
                    lines.append(f"- `{tf}`")
            else:
                lines.append("No result files found.")
            lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python parse_results.py <results_dir>", file=sys.stderr)
        sys.exit(1)

    results_dir = sys.argv[1]
    if not os.path.isdir(results_dir):
        print(f"ERROR: {results_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    # Debug: list all files in results dir
    print(f"📂 Files in {results_dir}:")
    for f in sorted(os.listdir(results_dir)):
        fpath = os.path.join(results_dir, f)
        size = os.path.getsize(fpath) if os.path.isfile(fpath) else 0
        print(f"  {f} ({size} bytes)")
    print("")

    summary = generate_summary(results_dir)

    # Write to GitHub step summary if available
    summary_file = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary_file:
        with open(summary_file, "a") as f:
            f.write(summary)
        print(f"✓ Summary written to GITHUB_STEP_SUMMARY")

    # Always print to stdout too
    print(summary)


if __name__ == "__main__":
    main()
