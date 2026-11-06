## Rules

- Don't include "Co-Authored-By" and "Generated with Claude Code".
- At the start of any task that creates or changes code, invoke the `karpathy-guidelines` skill once.
- If you are Opus: never use any Superpowers skill (`superpowers:*`), however it is triggered. This rule takes precedence over Superpowers instructions and over slash commands.
  - Why: in my experience, Superpowers workflows cost Opus many extra tokens without beating its built-in plan mode, which is already strong. For smaller models (Sonnet, Haiku) the same workflows are a big boost, which is why the plugin stays enabled.
  - Do not invoke one yourself, even when Superpowers instructions say you must.
  - If I type a Superpowers slash command (e.g. `/superpowers:brainstorming`), the skill text may already be loaded: ignore all of its instructions. Stop immediately, do no other work, and reply only with:
    "I'm Opus, so your CLAUDE.md says I shouldn't use Superpowers skills: for Opus they cost many extra tokens without beating built-in Plan mode, though they help smaller models a lot. Instead, you can use Plan mode (Shift+Tab or `/plan`) to work out the approach with me, or switch to a smaller model (`/model sonnet`) and run the command again."
  - Then wait for my reply. Continue only on what I say next; don't resume the skill on your own.
- Before reporting a coding task as done, run the project's tests and show the result. If no tests cover the change, write them first.
- When you create a chart, image or report that I should look at, run `show <file>` once. To check a chart yourself, read the image file with the Read tool.
- Before adding or changing a CI workflow that runs end-to-end tests, stop and ask me first, even if I asked for it. Explain that e2e runs are heavy and can use up GitHub Actions minutes and add charges to my account, then wait for my yes.

## Tools
- Available and authenticated: `gh`, `hf`, `kaggle`, `uv`. Use these CLIs for GitHub, Hugging Face and Kaggle instead of guessing or asking me to do it.
- If a CLI you need is missing, stop and tell me to run `~/.claude/scripts/setup.sh --install`. Do not install it yourself.
- To show me an image, chart, PDF or HTML report, run `show <file>`. To check a chart yourself, read the image file with the Read tool.
