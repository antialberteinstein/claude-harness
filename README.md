# claude-harness

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Fedora-lightgrey.svg)](#install)
[![Shell](https://img.shields.io/badge/shell-bash%203.2%2B-4EAA25.svg?logo=gnubash&logoColor=white)](scripts/)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-harness-D97757.svg?logo=anthropic&logoColor=white)](https://docs.claude.com/en/docs/claude-code/overview)

My user-level [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) config: `settings.json`, `CLAUDE.md`, statusline, theme, notification hooks and setup scripts. This repo *is* `~/.claude`, tracked with an allowlist `.gitignore`, so history, sessions and credentials never enter git.

Supported: macOS and Fedora.

## What's inside

| Part                                              | What it does                                                                                                                                                                                                                                                                       |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plugins                                           | [Superpowers](https://github.com/obra/superpowers) as the main workflow, [Karpathy guidelines](https://github.com/multica-ai/andrej-karpathy-skills) for coding, and [kessie-skills](https://github.com/antialberteinstein/kessie-skills) for per-project setup and harness checks |
| [ECC](https://github.com/affaan-m/ECC) (selected) | Safety and quality hooks, plus a small set of skills and agents. Noisy hooks are turned off in `settings.json`                                                                                                                                                                     |
| `CLAUDE.md`                                       | Load the Karpathy guidelines before coding; Opus skips Superpowers; run tests before calling a task done; use `gh`, `hf`, `kaggle`, `uv` instead of guessing                                                                                                                       |
| Permissions                                       | Auto mode; secrets (`.env*`, `~/.ssh`, `~/.claude.json`) denied; anything that pushes data out (`git push`, PRs, releases, uploads) asks first                                                                                                                                     |
| MCP                                               | Context7 for up-to-date library docs. Project MCP servers (Hugging Face, Colab, Playwright) are added per project by `/setup-project`                                                                                                                                              |
| Statusline                                        | Lualine-style: vim mode, git branch, directory, 5-hour rate limit, context bar, model                                                                                                                                                                                              |
| Theme                                             | Catppuccin Mocha                                                                                                                                                                                                                                                                   |
| Notifications                                     | Alerts when Claude needs permission or finishes: native in Kitty, iTerm2, WezTerm and Ghostty; system notification elsewhere                                                                                                                                                       |

## Install

Requirements: `git`, `jq` and [Claude Code](https://docs.claude.com/en/docs/claude-code/overview).

```bash
# 1. Clone anywhere
git clone https://github.com/antialberteinstein/claude-harness.git ~/claude-harness

# 2. Preview, then move the repo into ~/.claude
bash ~/claude-harness/scripts/move.sh -n
bash ~/claude-harness/scripts/move.sh

# 3. Check dependencies, install the CLIs, log in, link commands
bash ~/.claude/scripts/setup.sh --install --login --add-path

# 4. Install the plugins and ECC components listed in settings.json
claude-sync
```

`move.sh` never overwrites silently: any existing file in `~/.claude` that differs from the repo is moved to `~/.claude/backups/harness-<timestamp>/` first. Everything else already in `~/.claude` is left alone.

Run `bash ~/.claude/scripts/setup.sh -n` at any time to see what setup would change without changing it.

## Usage

```bash
git -C ~/.claude pull && claude-sync   # update config, plugins and ECC
claude-sync -n                         # preview what claude-sync would install
show chart.png                         # open an image or report (new Kitty window, or the default viewer)
bash ~/.claude/scripts/setup.sh --list # list setup modules; run one with --only <name>
```

Inside Claude Code:

- `/setup-project`: detect the project's stack and suggest project-scope plugins, MCP servers and ECC components.
- `/harness-check`: check the whole harness (settings, plugins, hooks, MCP) and report problems.

Optional environment variables:

| Variable                | Effect                                      |
| ----------------------- | ------------------------------------------- |
| `CLAUDE_SL_NERD=0`      | Statusline without Nerd Font icons          |
| `CLAUDE_SL_THEME`       | Statusline color theme                      |
| `CLAUDE_NOTIFY_OS=1`    | Always use system notifications             |
| `CLAUDE_NOTIFY_SOUND=0` | Mute notification sounds                    |
| `CLAUDE_NOTIFY_LOG=1`   | Log notifications to `~/.claude/notify.log` |

Machine-specific overrides for setup go in `scripts/setup.d/config.local.sh` (ignored by git).

## License

[MIT](LICENSE) © Nhat Nguyen