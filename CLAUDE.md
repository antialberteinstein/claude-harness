## Rules

- Don't include "Co-Authored-By" and "Generated with Claude Code".
- At the start of any task that creates or changes code, invoke the `karpathy-guidelines` skill once.
- If you are Opus: do not invoke Superpowers skills, even when Superpowers instructions say you must. This rule takes precedence.
- Before reporting a coding task as done, run the project's tests and show the result. If no tests cover the change, write them first.
- When you create a chart, image or report that I should look at, run `show <file>` once. To check a chart yourself, read the image file with the Read tool.

## Tools
- Available and authenticated: `gh`, `hf`, `kaggle`, `uv`. Use these CLIs for GitHub, Hugging Face and Kaggle instead of guessing or asking me to do it.
- If a CLI you need is missing, stop and tell me to run `~/.claude/scripts/setup.sh --install`. Do not install it yourself.
- To show me an image, chart, PDF or HTML report, run `show <file>`. To check a chart yourself, read the image file with the Read tool.
