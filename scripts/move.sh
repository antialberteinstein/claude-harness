#!/usr/bin/env bash
# scripts/move.sh — turn a fresh clone of this repo into ~/.claude itself.
#
#   git clone git@github.com:antialberteinstein/claude-harness.git /tmp/claude-harness
#   bash /tmp/claude-harness/scripts/move.sh [-n]
#
# What it does:
#   1. Sets up the `home` git filter (settings.json stores $HOME as @HOME@ in git).
#   2. Re-checks out tracked files so @HOME@ becomes this machine's $HOME.
#   3. For every tracked file that already exists in ~/.claude with different content,
#      moves the old file to ~/.claude/backups/harness-<timestamp>/ (never overwrites silently).
#   4. Moves .git and the tracked files into ~/.claude, then removes the empty clone.
# Untracked things in ~/.claude (history, projects, plugins, …) are left alone.
# Running it again from ~/.claude/scripts/ only re-applies the filter config.
# Target: $CLAUDE_CONFIG_DIR if set, else ~/.claude. Works with bash 3.2 (macOS).
set -euo pipefail

DRY=0
case "${1:-}" in
  -n|--dry-run) DRY=1 ;;
  "") ;;
  *) echo "Usage: move.sh [-n|--dry-run]" >&2; exit 2 ;;
esac

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
DEST="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
mkdir -p "$DEST"; DEST="$(cd "$DEST" && pwd -P)"

say() { printf '%s\n' "$*"; }
act() { if (( DRY )); then say "→ $*"; else "$@"; fi; }

set_filter() {
  act git -C "$1" config filter.home.clean  'sed "s|$HOME|@HOME@|g"'
  act git -C "$1" config filter.home.smudge 'sed "s|@HOME@|$HOME|g"'
}

[[ -d "$SRC/.git" ]] || { say "Not a git clone: $SRC" >&2; exit 1; }

if [[ "$SRC" == "$DEST" ]]; then
  set_filter "$DEST"; say "Already in place: $DEST (filter config re-applied)"; exit 0
fi
[[ -e "$DEST/.git" ]] && { say "$DEST is already a git repo. Remove $DEST/.git first if you really want to replace it." >&2; exit 1; }
[[ -z "$(git -C "$SRC" status --porcelain)" ]] || { say "The clone has uncommitted changes; commit or discard them first: $SRC" >&2; exit 1; }
[[ -f "$SRC/.gitattributes" ]] || say "warning: no .gitattributes in the repo; settings.json paths will not be rewritten"

say "Moving $SRC → $DEST"

# 1–2. Filter, then re-checkout so smudge runs on every tracked file.
set_filter "$SRC"
if (( ! DRY )); then
  git -C "$SRC" ls-files -z | (cd "$SRC" && xargs -0 rm -f)
  git -C "$SRC" checkout -- .
fi

# 3–4. Back up conflicting files, move tracked files in.
BACKUP="$DEST/backups/harness-$(date +%Y%m%d-%H%M%S)"
backed=0
while IFS= read -r -d '' f; do
  if [[ -e "$DEST/$f" || -L "$DEST/$f" ]]; then
    if cmp -s "$SRC/$f" "$DEST/$f"; then :; else
      act mkdir -p "$BACKUP/$(dirname "$f")"
      act mv "$DEST/$f" "$BACKUP/$f"
      backed=$((backed+1))
    fi
  fi
  [[ "$f" == */* ]] && act mkdir -p "$DEST/${f%/*}"
  act mv -f "$SRC/$f" "$DEST/$f"
done < <(git -C "$SRC" ls-files -z)
act mv "$SRC/.git" "$DEST/.git"

if (( DRY )); then say "(dry run, nothing changed)"; exit 0; fi

# Remove the now-empty clone (only empty directories; anything left over stays).
find "$SRC" -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
[[ -d "$SRC" ]] && say "Left over in $SRC (untracked files, not touched)"

git -C "$DEST" update-index -q --refresh || true
t='~'; (( backed )) && say "Backed up $backed existing file(s) to ${BACKUP/#$HOME/$t} — diff them against the new ones and keep what you need."
say "Done. git status in $DEST:"
git -C "$DEST" status --short
say "Next: bash ~/.claude/scripts/setup.sh"