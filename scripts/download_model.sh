#!/usr/bin/env bash
# -------------------------------------------------------------------
# download_model.sh — Download a Hugging Face model for local scanning
#
# Env vars:
#   MODEL_ID         — HF model identifier (e.g. gpt2, meta-llama/Llama-2-7b-chat-hf)
#   HF_TOKEN         — Hugging Face access token (for gated models)
#   MODEL_CACHE_DIR  — Directory to save model files (default: ./model_cache)
# -------------------------------------------------------------------
set -euo pipefail

MODEL_ID="${MODEL_ID:?MODEL_ID is required}"
MODEL_CACHE_DIR="${MODEL_CACHE_DIR:-./model_cache}"

echo "╔══════════════════════════════════════════════════╗"
echo "║  Downloading model: ${MODEL_ID}"
echo "╚══════════════════════════════════════════════════╝"

pip install --quiet huggingface_hub[hf_xet]

# Build auth args if token is available
AUTH_ARGS=()
if [[ -n "${HF_TOKEN:-}" ]]; then
    AUTH_ARGS=(--token "$HF_TOKEN")
    echo "✓ Using authenticated download (HF_TOKEN set)"
else
    echo "⚠ No HF_TOKEN set — only public models will work"
fi

# Download using hf CLI (huggingface-cli is deprecated in hub >= 1.x)
mkdir -p "$MODEL_CACHE_DIR"

# Try new `hf` CLI first, fall back to `huggingface-cli` for older installs
if command -v hf &> /dev/null; then
    HF_CMD="hf"
elif command -v huggingface-cli &> /dev/null; then
    HF_CMD="huggingface-cli"
else
    echo "✗ ERROR: Neither 'hf' nor 'huggingface-cli' found"
    exit 1
fi

echo "→ Using CLI: $HF_CMD"

$HF_CMD download "$MODEL_ID" \
    --local-dir "$MODEL_CACHE_DIR" \
    "${AUTH_ARGS[@]}" \
    2>&1 | tail -20

# Verify something was downloaded
FILE_COUNT=$(find "$MODEL_CACHE_DIR" -type f | wc -l)
TOTAL_SIZE=$(du -sh "$MODEL_CACHE_DIR" | cut -f1)

if [[ "$FILE_COUNT" -eq 0 ]]; then
    echo "✗ ERROR: No files downloaded for $MODEL_ID"
    exit 1
fi

echo ""
echo "✓ Downloaded $FILE_COUNT files ($TOTAL_SIZE) to $MODEL_CACHE_DIR"
