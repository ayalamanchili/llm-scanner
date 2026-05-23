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

pip install --quiet huggingface_hub[cli]

# Build auth args if token is available
AUTH_ARGS=()
if [[ -n "${HF_TOKEN:-}" ]]; then
    AUTH_ARGS=(--token "$HF_TOKEN")
    echo "✓ Using authenticated download (HF_TOKEN set)"
else
    echo "⚠ No HF_TOKEN set — only public models will work"
fi

# Download using huggingface-cli (handles LFS, shards, etc.)
mkdir -p "$MODEL_CACHE_DIR"

huggingface-cli download "$MODEL_ID" \
    --local-dir "$MODEL_CACHE_DIR" \
    --local-dir-use-symlinks False \
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
