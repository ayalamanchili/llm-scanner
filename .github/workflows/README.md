# 🛡️ LLM Security Scanner

A modular GitHub Actions pipeline that pulls models from Hugging Face and runs security scans using open-source tools. Designed to be extensible — add new scanning tools by dropping a config into `tools/`.

## Quick Start

1. **Fork or clone** this repo
2. **Set secrets** in your GitHub repo:
   - `HF_TOKEN` — your Hugging Face access token ([create one here](https://huggingface.co/settings/tokens))
3. **Trigger a scan** via GitHub Actions (manual dispatch or push)

## Usage

### Manual Trigger (workflow_dispatch)

Go to **Actions → LLM Security Scan → Run workflow** and fill in:

| Input | Default | Description |
|-------|---------|-------------|
| `model_id` | `gpt2` | Hugging Face model ID (e.g. `meta-llama/Llama-2-7b-chat-hf`) |
| `scan_tools` | `garak` | Comma-separated list of tools to run (e.g. `garak`) |
| `garak_probes` | `all` | Garak probe families to run (e.g. `encoding,dan,glitch`) |
| `garak_detectors` | `auto` | Garak detectors — `auto` uses probe defaults |
| `model_type` | `huggingface` | Model backend type for Garak |

### On Push (auto)

Every push to `main` triggers a scan of `gpt2` with default settings. Edit the workflow to change defaults.

## Architecture

```
llm-security-scanner/
├── .github/workflows/
│   └── llm-security-scan.yml    # Main orchestrator workflow
├── tools/
│   ├── garak/
│   │   ├── config.yml           # Tool metadata & defaults
│   │   ├── run.sh               # Execution script
│   │   └── README.md            # Tool-specific docs
│   └── _template/               # Copy this to add a new tool
│       ├── config.yml
│       ├── run.sh
│       └── README.md
├── scripts/
│   ├── download_model.sh        # Model download helper
│   ├── parse_results.py         # Unified results parser
│   └── tool_runner.sh           # Discovers & runs tools
└── README.md
```

### Adding a New Tool

1. Copy `tools/_template/` to `tools/<your-tool>/`
2. Edit `config.yml` with your tool's metadata
3. Implement `run.sh` — it receives env vars `MODEL_ID`, `MODEL_PATH`, `RESULTS_DIR`
4. The orchestrator auto-discovers tools listed in the `scan_tools` input
5. Results are uploaded as GitHub Actions artifacts

See [tools/_template/README.md](tools/_template/README.md) for details.

## Scan Results

Results are:
- **Uploaded as artifacts** on each workflow run (download from the Actions tab)
- **Printed in the job summary** as a markdown table
- **Saved as JSON** for programmatic consumption

## Supported Tools

| Tool | Status | Description |
|------|--------|-------------|
| [Garak](https://github.com/NVIDIA/garak) | ✅ Ready | LLM vulnerability scanner — probes for prompt injection, data leakage, encoding attacks, and more |
| _Your tool here_ | 🔧 | Copy `tools/_template/` and add it |

## Security Notes

- Model weights are downloaded ephemerally into the runner and discarded after the job
- Your `HF_TOKEN` is stored as a GitHub secret and never logged
- Scan results may contain adversarial content — review artifacts with caution

## License

MIT
