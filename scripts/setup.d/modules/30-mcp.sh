# modules/30-mcp.sh — MCP ở scope user (danh sách trong config.sh) và cấu hình an toàn
step_mcp() {
  say "MCP"
  have npx && ok "npx (Context7, Playwright MCP)" || warn "thiếu npx: Context7 và Playwright MCP cần Node ($(os_hint node))"
  have uvx && ok "uvx (Colab MCP)" || warn "thiếu uvx: Colab MCP cần uv (chạy lại với --install)"
  have claude || { fail "thiếu claude, bỏ qua MCP"; return; }

  # MCP ở user scope được Claude Code lưu trong ~/.claude.json (không phải settings.json)
  local cj name cmd out
  cj="$(claude_json)"
  while IFS='|' read -r name cmd; do
    [[ -n "$name" ]] || continue
    if [[ -f "$cj" ]] && jq -e --arg n "$name" '.mcpServers[$n]' "$cj" >/dev/null 2>&1; then
      ok "$name (user)"; continue
    fi
    echo "  → claude mcp add --scope user $name -- $cmd"
    (( DRY == 1 )) && continue
    # shellcheck disable=SC2086  # cmd được tách thành từng đối số có chủ đích
    if out=$(claude mcp add --scope user "$name" -- $cmd 2>&1); then ok "đã thêm $name"
    elif grep -qi "already exists" <<<"$out"; then ok "$name (user)"
    else fail "không thêm được $name: $out"; fi
  done <<<"$USER_MCP"

  if grep -q '^context7|' <<<"$USER_MCP"; then
    [[ -n "${CONTEXT7_API_KEY:-}" ]] && ok "CONTEXT7_API_KEY có trong môi trường" \
      || note "tuỳ chọn: export CONTEXT7_API_KEY=… trong file rc của shell (key miễn phí ở context7.com/dashboard)"
  fi

  if [[ -f "$SETTINGS" ]] && jq -e '.enableAllProjectMcpServers == true' "$SETTINGS" >/dev/null 2>&1; then
    warn "enableAllProjectMcpServers = true: MCP trong .mcp.json của repo lạ sẽ tự chạy, nên xoá dòng này"
  fi
}
