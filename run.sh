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
GARAK_ARGS=(
    --model_type "$MODEL_TYPE"
    --model_name "$MODEL_ID"
)

# Probes
if [[ "$GARAK_PROBES" != "all" ]]; then
    # Convert comma-separated to space-separated for garak
    IFS=',' read -ra PROBE_LIST <<< "$GARAK_PROBES"
    for probe in "${PROBE_LIST[@]}"; do
        probe=$(echo "$probe" | xargs)  # trim whitespace
        GARAK_ARGS+=(--probes "$probe")
    done
fi

# Detectors
if [[ "$GARAK_DETECTORS" != "auto" ]]; then
    IFS=',' read -ra DETECTOR_LIST <<< "$GARAK_DETECTORS"
    for det in "${DETECTOR_LIST[@]}"; do
        det=$(echo "$det" | xargs)
        GARAK_ARGS+=(--detectors "$det")
    done
fi

# Output directory — Garak writes to its own report dir,
# we'll copy the results after
GARAK_REPORT_DIR="$RESULTS_DIR/garak_raw"
mkdir -p "$GARAK_REPORT_DIR"

# ── Run the scan ──────────────────────────────────────
echo "→ Starting Garak scan..."
echo "  Command: $GARAK_CMD ${GARAK_ARGS[*]}"
echo ""

$GARAK_CMD "${GARAK_ARGS[@]}" \
    --report_prefix "$GARAK_REPORT_DIR/garak_report" \
    2>&1 | tee "$RESULTS_DIR/garak_stdout.log" || true

# ── Collect results ───────────────────────────────────
# Garak writes .jsonl report files — find and copy them
echo ""
echo "→ Collecting results..."

# Garak may write to ~/.local/share/garak/ or the specified prefix
GARAK_HOME="${HOME}/.local/share/garak"
FOUND_RESULTS=false

# Check report prefix location
for f in "$GARAK_REPORT_DIR"/garak_report*.jsonl; do
    if [[ -f "$f" ]]; then
        FOUND_RESULTS=true
        echo "  Found: $f"
    fi
done

# Check default Garak output directory
if [[ "$FOUND_RESULTS" == "false" && -d "$GARAK_HOME" ]]; then
    for f in "$GARAK_HOME"/*.jsonl; do
        if [[ -f "$f" ]]; then
            cp "$f" "$RESULTS_DIR/"
            FOUND_RESULTS=true
            echo "  Copied: $(basename "$f")"
        fi
    done
    # Also grab HTML reports
    for f in "$GARAK_HOME"/*.html; do
        if [[ -f "$f" ]]; then
            cp "$f" "$RESULTS_DIR/"
            echo "  Copied: $(basename "$f")"
        fi
    done
fi

# Move raw results to results dir if at prefix location
if [[ -d "$GARAK_REPORT_DIR" ]]; then
    for f in "$GARAK_REPORT_DIR"/*.jsonl "$GARAK_REPORT_DIR"/*.html; do
        if [[ -f "$f" ]]; then
            cp "$f" "$RESULTS_DIR/"
        fi
    done
fi

if [[ "$FOUND_RESULTS" == "false" ]]; then
    echo "⚠ No Garak report files found — check garak_stdout.log for errors"
    # Still exit 0 so the meta file captures the situation
fi

echo ""
echo "✓ Garak scan complete. Results in $RESULTS_DIR/"
ls -lh "$RESULTS_DIR"/garak_* 2>/dev/null || true
