# modules/60-paths.sh — sửa đường dẫn riêng của từng máy trong settings.json
step_paths() {
  say "Đường dẫn riêng của máy trong settings.json"
  [[ -f "$SETTINGS" ]] || { warn "chưa có settings.json"; return; }
  jq empty "$SETTINGS" 2>/dev/null || { fail "settings.json không phải JSON hợp lệ"; return; }
  _paths_marketplaces
  _paths_env
}

# Marketplace dạng thư mục: nếu đường dẫn trỏ vào ~/.claude của máy khác thì đổi sang máy này
_paths_marketplaces() {
  local name path want tmp changed=0
  while IFS=$'\t' read -r name path; do
    [[ -n "$name" ]] || continue
    want="$path"
    case "$path" in */.claude/*) want="$CFG/${path#*/.claude/}" ;; esac
    if [[ "$want" == "$path" ]]; then ok "$name: $(tilde "$path")"; continue; fi
    echo "  → $name: $path → $want"
    changed=1
    (( DRY == 1 )) && continue
    tmp="$(mktemp)"
    if jq --arg n "$name" --arg p "$want" '.extraKnownMarketplaces[$n].source.path = $p' "$SETTINGS" > "$tmp" \
       && jq empty "$tmp"; then mv "$tmp" "$SETTINGS"
    else rm -f "$tmp"; fail "không sửa được $name"; fi
  done < <(jq -r '(.extraKnownMarketplaces // {}) | to_entries[]
                  | select(.value.source.source == "directory") | [.key, .value.source.path] | @tsv' "$SETTINGS")
  (( changed == 1 && DRY == 0 )) && note "đã sửa; chạy claude-sync để đăng ký lại marketplace với đường dẫn mới"
}

# Biến môi trường chứa đường dẫn tuyệt đối của máy khác
_paths_env() {
  local k v
  while IFS=$'\t' read -r k v; do
    [[ -n "$k" ]] || continue
    case "$v" in
      /Users/*|/home/*)
        if [[ "$v" != "$HOME"* ]]; then warn "env $k trỏ tới $v (máy khác?)"
        elif [[ ! -e "$v" ]]; then warn "env $k trỏ tới $v nhưng không tồn tại"; fi ;;
    esac
  done < <(jq -r '(.env // {}) | to_entries[] | [.key, (.value|tostring)] | @tsv' "$SETTINGS")
}
