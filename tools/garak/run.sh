#!/usr/bin/env bash
# -------------------------------------------------------------------
# Garak run.sh — Execute a Garak vulnerability scan
#
# Expected env vars (set by tool_runner.sh):
#   MODEL_ID         — Hugging Face model ID
#   MODEL_PATH       — Local path to model weights
#   MODEL_TYPE       — Model backend (huggingface, openai, etc.)
#   RESULTS_DIR      — Where to write output files
#   HF_TOKEN         — Hugging Face token (optional)
#
# Garak-specific env vars:
#   GARAK_PROBES     — Probe families to run (comma-sep or 'all')
#   GARAK_DETECTORS  — Detectors to use ('auto' = probe defaults)
# -------------------------------------------------------------------
set -euo pipefail

GARAK_PROBES="${GARAK_PROBES:-all}"
GARAK_DETECTORS="${GARAK_DETECTORS:-auto}"
RESULTS_DIR="${RESULTS_DIR:-./results}"

echo "── Garak Configuration ──────────────────────────"
echo "  Model:     $MODEL_ID"
echo "  Type:      $MODEL_TYPE"
echo "  Probes:    $GARAK_PROBES"
echo "  Detectors: $GARAK_DETECTORS"
echo "─────────────────────────────────────────────────"
echo ""

# ── Install Garak ─────────────────────────────────────
echo "→ Installing Garak..."
pip install --quiet garak 2>&1 | tail -5

# ── Set up HF auth ────────────────────────────────────
# Garak reads HF_INFERENCE_TOKEN or HUGGING_FACE_HUB_TOKEN for
# HuggingFace Inference API access.  Export both so it just works.
if [[ -n "${HF_TOKEN:-}" ]]; then
    export HF_INFERENCE_TOKEN="$HF_TOKEN"
    export HUGGING_FACE_HUB_TOKEN="$HF_TOKEN"
    echo "✓ HF_TOKEN exported as HF_INFERENCE_TOKEN and HUGGING_FACE_HUB_TOKEN"
fi

# Verify installation
if ! command -v garak &> /dev/null; then
    # Try via python module
    if ! python -m garak --help &> /dev/null; then
        echo "✗ ERROR: Garak installation failed"
        exit 1
    fi
    GARAK_CMD="python -m garak"
else
    GARAK_CMD="garak"
fi

echo "✓ Garak installed: $($GARAK_CMD --version 2>&1 || echo 'version unknown')"
echo ""

# ── Build command ─────────────────────────────────────
# Garak CLI uses --target_type / --target_name (--model_type and
# --model_name are deprecated aliases but still accepted).
# --probes takes a SINGLE comma-separated string, NOT repeated flags.
# Same for --detectors.
GARAK_ARGS=(
    --target_type "$MODEL_TYPE"
    --target_name "$MODEL_ID"
)

# Probes — pass as a single comma-separated value
if [[ "$GARAK_PROBES" != "all" ]]; then
    # Strip any spaces around commas so garak parses cleanly
    CLEAN_PROBES=$(echo "$GARAK_PROBES" | tr -d ' ')
    GARAK_ARGS+=(--probes "$CLEAN_PROBES")
fi

# Detectors — also a single comma-separated value
if [[ "$GARAK_DETECTORS" != "auto" ]]; then
    CLEAN_DETECTORS=$(echo "$GARAK_DETECTORS" | tr -d ' ')
    GARAK_ARGS+=(--detectors "$CLEAN_DETECTORS")
fi

# Report prefix — garak writes .report.jsonl / .hitlog.jsonl / .html
# using the report_prefix path. Make sure the directory exists.
GARAK_REPORT_PREFIX="$RESULTS_DIR/garak_report"
mkdir -p "$RESULTS_DIR"
GARAK_ARGS+=(--report_prefix "$GARAK_REPORT_PREFIX")

# ── Run the scan ──────────────────────────────────────
echo "→ Starting Garak scan..."
echo "  Command: $GARAK_CMD ${GARAK_ARGS[*]}"
echo ""

set +e
$GARAK_CMD "${GARAK_ARGS[@]}" 2>&1 | tee "$RESULTS_DIR/garak_stdout.log"
SCAN_EXIT=$?
set -e

echo ""
echo "→ Garak exited with code $SCAN_EXIT"

# ── Collect results ───────────────────────────────────
# Garak writes report files to either:
#   1. The --report_prefix path ($RESULTS_DIR/garak_report.report.jsonl etc.)
#   2. The default ~/.local/share/garak/ directory
echo ""
echo "→ Collecting results..."

GARAK_HOME="${HOME}/.local/share/garak"
FOUND_RESULTS=false

# Check for results at the report prefix path
for f in "$RESULTS_DIR"/garak_report*.jsonl "$RESULTS_DIR"/garak_report*.html; do
    if [[ -f "$f" ]]; then
        FOUND_RESULTS=true
        echo "  Found: $f"
    fi
done

# Check default Garak output directory
if [[ "$FOUND_RESULTS" == "false" && -d "$GARAK_HOME" ]]; then
    echo "  Checking default garak home: $GARAK_HOME"
    for f in "$GARAK_HOME"/*.jsonl "$GARAK_HOME"/*.html; do
        if [[ -f "$f" ]]; then
            cp "$f" "$RESULTS_DIR/"
            FOUND_RESULTS=true
            echo "  Copied: $(basename "$f")"
        fi
    done
    # Also check subdirectories (some versions nest by date)
    find "$GARAK_HOME" -name "*.jsonl" -o -name "*.html" 2>/dev/null | while read -r f; do
        if [[ -f "$f" ]]; then
            cp "$f" "$RESULTS_DIR/" 2>/dev/null || true
            echo "  Copied: $f"
        fi
    done
    FOUND_RESULTS=true
fi

if [[ "$FOUND_RESULTS" == "false" ]]; then
    echo "⚠ No Garak report files found — check garak_stdout.log for errors"
    echo ""
    echo "── Last 30 lines of garak_stdout.log ──"
    tail -30 "$RESULTS_DIR/garak_stdout.log" 2>/dev/null || true
fi

echo ""
echo "✓ Garak scan complete. Results in $RESULTS_DIR/"
ls -lh "$RESULTS_DIR"/ 2>/dev/null || true
