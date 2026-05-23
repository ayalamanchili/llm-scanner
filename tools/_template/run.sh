#!/usr/bin/env bash
# -------------------------------------------------------------------
# run.sh — Template execution script for a new scanning tool
#
# Copy tools/_template/ to tools/<your-tool>/ and customize this file.
#
# Available env vars (set by tool_runner.sh):
#   MODEL_ID         — Hugging Face model ID (e.g. gpt2)
#   MODEL_PATH       — Local path to downloaded model weights
#   MODEL_TYPE       — Model backend type (huggingface, openai, etc.)
#   RESULTS_DIR      — Directory to write output files to
#   TOOL_DIR         — Path to this tool's directory
#   HF_TOKEN         — Hugging Face token (optional)
#
# Guidelines:
#   1. Install your tool (pip, npm, etc.)
#   2. Run the scan against MODEL_ID or MODEL_PATH
#   3. Write results to $RESULTS_DIR/<toolname>_<something>.<ext>
#   4. Exit 0 on success, non-zero on failure
#   5. Keep stdout informative — it's captured in the Actions log
# -------------------------------------------------------------------
set -euo pipefail

echo "── My Tool Configuration ───────────────────────"
echo "  Model:  $MODEL_ID"
echo "  Type:   $MODEL_TYPE"
echo "────────────────────────────────────────────────"

# ── Step 1: Install ───────────────────────────────────
echo "→ Installing my-tool..."
# pip install --quiet my-tool
# npm install -g my-tool

# ── Step 2: Run scan ─────────────────────────────────
echo "→ Running scan..."
# my-tool scan --model "$MODEL_ID" --output "$RESULTS_DIR/mytool_results.json"

# ── Step 3: Verify output ────────────────────────────
# if [[ ! -f "$RESULTS_DIR/mytool_results.json" ]]; then
#     echo "✗ No results produced"
#     exit 1
# fi

echo "✓ Scan complete"
echo "TODO: Implement this tool's scanning logic"
exit 0
