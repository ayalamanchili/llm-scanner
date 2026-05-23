#!/usr/bin/env bash
# -------------------------------------------------------------------
# tool_runner.sh — Discover and execute a scanning tool
#
# Usage: tool_runner.sh <tool_name>
#
# Env vars passed to each tool's run.sh:
#   MODEL_ID      — Hugging Face model identifier
#   MODEL_PATH    — Local path to downloaded model weights
#   MODEL_TYPE    — Model backend type (huggingface, openai, etc.)
#   RESULTS_DIR   — Directory to write results into
#   HF_TOKEN      — Hugging Face token (optional)
#
# Tool-specific env vars (prefixed by tool name in caps):
#   GARAK_PROBES, GARAK_DETECTORS, etc.
# -------------------------------------------------------------------
set -euo pipefail

TOOL_NAME="${1:?Usage: tool_runner.sh <tool_name>}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TOOL_DIR="$REPO_ROOT/tools/$TOOL_NAME"

# Validate the tool exists
if [[ ! -d "$TOOL_DIR" ]]; then
    echo "✗ ERROR: Tool '$TOOL_NAME' not found in tools/"
    echo "  Available tools:"
    ls -1 "$REPO_ROOT/tools/" | grep -v '^_' | sed 's/^/    - /'
    exit 1
fi

if [[ ! -f "$TOOL_DIR/run.sh" ]]; then
    echo "✗ ERROR: Tool '$TOOL_NAME' is missing run.sh"
    exit 1
fi

# Ensure results directory exists
RESULTS_DIR="${RESULTS_DIR:-./results}"
mkdir -p "$RESULTS_DIR"

echo "╔══════════════════════════════════════════════════╗"
echo "║  Running tool: $TOOL_NAME"
echo "║  Model:        ${MODEL_ID:-unknown}"
echo "║  Results:      $RESULTS_DIR"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Read tool config if present
if [[ -f "$TOOL_DIR/config.yml" ]]; then
    echo "ℹ Tool config found: $TOOL_DIR/config.yml"
fi

# Export standard vars
export MODEL_ID="${MODEL_ID:-gpt2}"
export MODEL_PATH="${MODEL_PATH:-./model_cache}"
export MODEL_TYPE="${MODEL_TYPE:-huggingface}"
export RESULTS_DIR
export TOOL_DIR

# Run the tool
START_TIME=$(date +%s)

bash "$TOOL_DIR/run.sh"
EXIT_CODE=$?

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
if [[ $EXIT_CODE -eq 0 ]]; then
    echo "✓ $TOOL_NAME completed in ${DURATION}s"
else
    echo "✗ $TOOL_NAME failed with exit code $EXIT_CODE after ${DURATION}s"
fi

# Write metadata
cat > "$RESULTS_DIR/${TOOL_NAME}_meta.json" <<EOF
{
  "tool": "$TOOL_NAME",
  "model_id": "$MODEL_ID",
  "model_type": "$MODEL_TYPE",
  "exit_code": $EXIT_CODE,
  "duration_seconds": $DURATION,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

exit $EXIT_CODE
