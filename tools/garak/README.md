# Garak — LLM Vulnerability Scanner

[Garak](https://github.com/NVIDIA/garak) is NVIDIA's LLM vulnerability scanner. It probes language models for a wide range of security weaknesses.

## What It Tests

- **Prompt injection** — direct and indirect injection attempts
- **Data leakage** — attempts to extract training data
- **Encoding attacks** — base64, ROT13, and other encoding-based bypasses
- **DAN/jailbreak** — "Do Anything Now" and similar jailbreak prompts
- **Glitch tokens** — tokens that cause unexpected model behavior
- **Replay attacks** — repeating prompts to test consistency
- **Known bad signatures** — known-malicious prompt patterns

## Configuration

Set these env vars in the workflow dispatch or in the workflow YAML:

| Variable | Default | Description |
|----------|---------|-------------|
| `GARAK_PROBES` | `all` | Probe families to run (comma-separated) |
| `GARAK_DETECTORS` | `auto` | Detectors to use (`auto` uses each probe's default detector) |
| `MODEL_TYPE` | `huggingface` | Garak model type (`huggingface`, `openai`, `replicate`, etc.) |

### Probe Families

Some commonly useful probe families:

```
encoding        — Encoding-based bypass attempts
dan             — "Do Anything Now" jailbreaks
glitch          — Glitch token probing
knownbadsignatures — Known malicious prompt signatures
promptinject    — Prompt injection attacks
replay          — Replay/repetition attacks
snowball        — Escalating complexity attacks
continuation    — Continuation-based extraction
```

Run specific probes:
```
GARAK_PROBES=encoding,dan,promptinject
```

## Output

Garak produces:
- `.jsonl` — structured results (one JSON object per line)
- `.html` — human-readable HTML report
- `garak_stdout.log` — full console output

The results parser in `scripts/parse_results.py` understands Garak's JSONL format and extracts findings into the summary report.
