# modules/70-validate.sh — file mà settings.json tham chiếu có thật không (statusline, hook, theme)
step_validate() {
  say "File được settings.json tham chiếu"
  { [[ -f "$SETTINGS" ]] && jq empty "$SETTINGS" 2>/dev/null; } || return
  local cmd f seen="" th
  while IFS= read -r cmd; do
    f=$(grep -oE '(~|\$HOME|/)[^ "'\'']+\.(sh|js|py)' <<<"$cmd" | head -1) || true
    [[ -n "$f" ]] || continue
    f="${f/#\~/$HOME}"; f="${f/#\$HOME/$HOME}"
    case " $seen " in *" $f "*) continue ;; esac
    seen="$seen $f"
    [[ -f "$f" ]] && ok "$(tilde "$f")" || fail "thiếu $(tilde "$f")"
  done < <(jq -r '[.statusLine.command?, (.hooks // {} | .[][] | .hooks[]?.command)] | .[] | select(. != null)' "$SETTINGS")

  [[ -d "$CFG/themes" ]] || act mkdir -p "$CFG/themes"
  th=$(jq -r '.theme // empty' "$SETTINGS")
  if [[ "$th" == custom:* && "$th" != custom:*:* ]]; then
    [[ -f "$CFG/themes/${th#custom:}.json" ]] && ok "theme ${th#custom:}" \
      || fail "theme ${th#custom:}.json không có trong ~/.claude/themes/"
  fi
}
