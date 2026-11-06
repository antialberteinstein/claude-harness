# modules/10-deps.sh — công cụ nền mà harness cần
step_deps() {
  say "Công cụ nền"
  local c
  for c in git jq; do
    have "$c" && ok "$c" || fail "thiếu $c: $(os_hint "$c")"
  done
  have claude && ok "claude" || fail "thiếu claude (cài Claude Code trước)"
  for c in node npm; do
    have "$c" && ok "$c" || warn "thiếu $c: hook ECC và MCP chạy bằng npx cần Node ($(os_hint node))"
  done
  os_deps
}
