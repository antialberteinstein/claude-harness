#!/usr/bin/env bash
# setup.d/test.sh — test offline cho setup.sh. Chạy: bash ~/.claude/scripts/setup.d/test.sh
# Dùng HOME giả và lệnh giả, không đọc hay sửa ~/.claude thật, không cài gì thật.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETUP="$ROOT/setup.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0; failn=0
check() { local name="$1"; shift; if "$@"; then echo "ok   $name"; pass=$((pass+1)); else echo "FAIL $name"; failn=$((failn+1)); fi; }
has()   { grep -qF -- "$2" <<<"$1"; }
hasnt() { ! grep -qF -- "$2" <<<"$1"; }

# ── Máy giả ──────────────────────────────────────────────────────────
H="$TMP/home"; B="$TMP/bin"; LOG="$TMP/calls"
mkdir -p "$H/.claude/scripts" "$H/.claude/themes" "$H/Downloads" "$B"
stub() { printf '#!/bin/bash\necho "%s $*" >> "%s"\n%s\n' "$1" "$LOG" "${2:-exit 0}" > "$B/$1"; chmod +x "$B/$1"; }
for c in git claude uv brew npx; do stub "$c"; done
ln -s "$(command -v jq)" "$B/jq"
stub gh "[ \"\$1 \$2\" = 'auth status' ] && { [ -f '$H/gh-ok' ] && exit 0 || exit 1; }; [ \"\$1 \$2\" = 'auth login' ] && touch '$H/gh-ok'; exit 0"
echo '#!/bin/bash' > "$H/.claude/scripts/claude-sync"
cat > "$H/.claude/settings.json" <<JSON
{ "extraKnownMarketplaces": { "kessie-local": { "source": { "source": "directory", "path": "/Users/other/.claude/local-plugins" } } },
  "env": { "KESSIE_REPO": "/Users/other/src/kessie" },
  "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } }
JSON
echo '{}' > "$H/.claude.json"
run() { env -i HOME="$H" SHELL=/bin/zsh TERM=dumb PATH="$B:/usr/bin:/bin" SETUP_OS_RELEASE="${SETUP_OS_RELEASE:-}" bash "$SETUP" "$@" 2>&1 </dev/null; }
rel() { printf 'ID=%s\nID_LIKE="%s"\n' "$1" "$2" > "$TMP/os-release"; }

# ── Nhận diện OS ─────────────────────────────────────────────────────
out=$(run --list --os darwin)
check "--os darwin dùng hồ sơ macOS"                 has "$out" "OS: macOS"
check "--list liệt kê đủ module theo thứ tự"         has "$out" "Module: deps tools mcp perms link paths validate sync"
if [[ "$(uname -s)" == Linux ]]; then
  rel fedora "";            out=$(SETUP_OS_RELEASE="$TMP/os-release" run --list)
  check "nhận Fedora từ os-release"                  has "$out" "OS: Fedora"
  rel fedora-asahi-remix "fedora"; out=$(SETUP_OS_RELEASE="$TMP/os-release" run --list)
  check "Fedora Asahi: rơi về ID_LIKE=fedora"        has "$out" "OS: Fedora"
  rel arch "";              out=$(SETUP_OS_RELEASE="$TMP/os-release" run --list)
  check "OS chưa có hồ sơ: dùng Linux chung"         has "$out" "OS: Linux (chung)"
fi
out=$(run --list --os haiku)
check "--os lạ: dự phòng Linux chung + ghi chú"      has "$out" "dự phòng cho \"haiku\""

# ── Chạy thử không ghi gì ────────────────────────────────────────────
before=$(cd "$H" && find . -type f -o -type l | sort | xargs cat 2>/dev/null | cksum)
: > "$LOG"; out=$(run -n --os fedora --install --include-login --add-path)
after=$(cd "$H" && find . -type f -o -type l | sort | xargs cat 2>/dev/null | cksum)
check "-n: không đổi file nào"                       [ "$before" = "$after" ]
check "-n: không gọi lệnh cài"                        hasnt "$(cat "$LOG")" "tool install"
check "-n: in lệnh sẽ chạy"                           has "$out" "→ uv tool install huggingface_hub[cli]"

# ── Module tools theo OS ─────────────────────────────────────────────
out=$(run --os fedora --only tools)
check "fedora: báo thiếu hf, kaggle"                  has "$out" "thiếu kaggle"
check "fedora: gợi ý --install"                       has "$out" "chạy lại với --install"
check "gh chưa đăng nhập thì cảnh báo"                has "$out" "gh chưa đăng nhập"
: > "$LOG"; out=$(run --os fedora --only tools --install)
check "--install: hf, kaggle cài bằng uv tool"        has "$(cat "$LOG")" "uv tool install kaggle"
rm "$B/uv"; : > "$LOG"
out=$(run --os fedora --only tools --install)
check "fedora: uv thiếu thì in lệnh dnf, không sudo"  has "$out" "sudo dnf install uv"
check "fedora: không tự chạy sudo"                    hasnt "$(cat "$LOG")" "sudo"
: > "$LOG"; out=$(run --os darwin --only tools --install)
check "darwin: uv thiếu thì brew install"             has "$(cat "$LOG")" "brew install uv"
stub uv
stub hf; stub kaggle
echo '{}' > "$H/Downloads/kaggle.json"
# script(1): GNU takes -c CMD, BSD/macOS takes the command after the file.
pty() { if [[ $(uname) == Darwin ]]; then script -q /dev/null bash -c "$1"; else script -qec "$1" /dev/null; fi; }
out=$(printf '\n' | env -i HOME="$H" SHELL=/bin/bash TERM=dumb PATH="$B:/usr/bin:/bin" \
      bash -c "$(declare -f pty); pty \"bash '$SETUP' --os fedora --only tools --include-login\"" 2>&1 | tr -d '\r')
check "--include-login: đăng nhập gh"                 has "$out" "gh: đã đăng nhập"
check "--include-login: chuyển kaggle.json"           [ -f "$H/.kaggle/kaggle.json" ]
check "--include-login: kaggle.json quyền 600"        [ "$(stat -c '%a' "$H/.kaggle/kaggle.json" 2>/dev/null || stat -f '%Lp' "$H/.kaggle/kaggle.json")" = 600 ]

# ── MCP ──────────────────────────────────────────────────────────────
stub claude "[ \"\$1 \$2\" = 'mcp add' ] && jq '.mcpServers.context7={\"command\":\"npx\"}' '$H/.claude.json' > '$TMP/cj' && mv '$TMP/cj' '$H/.claude.json'; exit 0"
: > "$LOG"; out=$(run --os fedora --only mcp)
check "mcp: thêm context7 ở scope user"              has "$(cat "$LOG")" "claude mcp add --scope user context7 -- npx -y @upstash/context7-mcp"
: > "$LOG"; out=$(run --os fedora --only mcp)
check "mcp: chạy lại không thêm trùng"                hasnt "$(cat "$LOG")" "mcp add"

# ── Link, paths, validate ────────────────────────────────────────────
out=$(run --os darwin --only link --add-path)
check "link: tạo symlink claude-sync"                 [ -L "$H/.local/bin/claude-sync" ]
check "link: thêm PATH vào ~/.zshrc"                  grep -qF '# claude harness' "$H/.zshrc"
out=$(run --os fedora --only paths)
check "paths: sửa đường dẫn kessie-local"            [ "$(jq -r '.extraKnownMarketplaces["kessie-local"].source.path' "$H/.claude/settings.json")" = "$H/.claude/local-plugins" ]
check "paths: cảnh báo env của máy khác"              has "$out" "env KESSIE_REPO trỏ tới /Users/other"
out=$(run --os fedora --only validate)
check "validate: báo thiếu statusline.sh"             has "$out" "thiếu ~/.claude/statusline.sh"
out=$(run --os fedora --only nosuch); rc=$?
check "--only module không tồn tại thì lỗi"           [ "$rc" -ne 0 ]

# ── statusline, move.sh: rút gọn $HOME thành ~ (không phải \~) ─────────
out=$(cd / && env -i HOME=/home/u PATH="/usr/bin:/bin" CLAUDE_SL_NERD=0 bash "$ROOT/../statusline.sh" <<<'{"cwd":"/home/u/proj"}' \
      | sed $'s/\033\\[[0-9;]*m//g')
check "statusline: hiện ~/proj"                       has "$out" " ~/proj "
check "move.sh: không in \\~ cho đường dẫn sao lưu"   hasnt "$(cat "$ROOT/move.sh")" '$HOME/\~}'

echo "---"; echo "$pass passed, $failn failed"
[ "$failn" -eq 0 ]
