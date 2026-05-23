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
    """Parse Garak's JSON Lines report file."""
    report_files = glob.glob(os.path.join(results_dir, "garak_*.jsonl"))
    if not report_files:
        # Also check for .json
        report_files = glob.glob(os.path.join(results_dir, "garak_*.json"))

    findings = []
    total_probes = 0
    total_passed = 0
    total_failed = 0

    for rf in report_files:
        with open(rf, "r") as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue

                # Garak outputs different record types
                if entry.get("entry_type") == "eval":
                    total_probes += 1
                    passed = entry.get("passed", None)
                    probe = entry.get("probe", "unknown")
                    detector = entry.get("detector", "unknown")
                    score = entry.get("score", None)

                    if passed:
                        total_passed += 1
                    else:
                        total_failed += 1
                        findings.append({
                            "probe": probe,
                            "detector": detector,
                            "score": score,
                            "status": "FAIL" if not passed else "PASS",
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
