# modules/90-sync.sh — gọi claude-sync (cài plugin + ECC). Chỉ chạy khi có --sync.
step_sync() {
  (( SYNC == 1 )) || return 0
  say "claude-sync"
  if (( nf > 0 )); then note "bỏ qua vì còn lỗi ở trên"; return; fi
  [[ -x "$SCRIPTS/claude-sync" ]] || { fail "không có $(tilde "$SCRIPTS/claude-sync")"; return; }
  if (( DRY == 1 )); then act bash "$SCRIPTS/claude-sync" -n; else act bash "$SCRIPTS/claude-sync"; fi
}
