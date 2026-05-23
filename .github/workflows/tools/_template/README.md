# Tool Name

> Copy this template to `tools/<your-tool>/` and customize.

## What It Tests

Describe the security risks this tool evaluates.

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `MY_TOOL_OPTION` | `default` | What this option controls |

## Output

Describe the files this tool writes to `$RESULTS_DIR`.

## Adding to parse_results.py

To get your tool's results in the summary report, add a parser function
in `scripts/parse_results.py`:

```python
def parse_mytool_results(results_dir: str) -> dict:
    # Read your tool's output files
    # Return structured findings
    ...
```

Then add a case in `generate_summary()`:

```python
if tool == "mytool":
    mytool = parse_mytool_results(results_dir)
    # Format into markdown
```
