#!/usr/bin/env bash
# install-necessary-ecc-user.sh — cài phần ECC đã chọn vào ~/.claude (scope user).
#
# Clone ECC vào thư mục tạm, cài hook / skill / agent đã chọn, rồi xoá thư mục tạm.
# Chạy lại bất cứ lúc nào để cập nhật lên bản ECC mới nhất.
#
# Dùng:  ./install-necessary-ecc-user.sh        cài
#        ./install-necessary-ecc-user.sh -n     chạy thử, không ghi gì
# Ghim phiên bản:  ECC_REF=<tag|branch|sha> ./install-necessary-ecc-user.sh
#
# Cần: git, node, npm, jq.
set -euo pipefail

# ─── Danh sách đã chọn ──────────────────────────────────────────────
SKILLS=(
  # ngôn ngữ
  typescript-patterns python-patterns cpp-coding-standards error-handling
  # bảo mật
  security-review agent-security-hardening
  # ML / MLOps
  pytorch-patterns mle-workflow docker-patterns deployment-patterns
  # LLM / agentic
  agent-harness-construction cost-aware-llm-pipeline prompt-caching-strategy
  mcp-server-patterns regex-vs-llm-structured-text
  # công cụ test (có thể trùng một phần với TDD của Superpowers)
  cpp-testing python-testing
)

AGENTS=(
  typescript-reviewer python-reviewer cpp-reviewer
  build-error-resolver cpp-build-resolver pytorch-build-resolver
  mle-reviewer rag-pipeline-reviewer
  security-reviewer silent-failure-hunter type-design-analyzer
  fastapi-reviewer performance-optimizer
)
# Không lấy react-reviewer ở scope user: nó cần rules/react và 3 skill React khác.

DISABLED_HOOKS=(
  pre:bash:auto-tmux-dev pre:bash:tmux-reminder pre:bash:git-push-reminder
  pre:write:doc-file-warning
  # "học liên tục": PreToolUse dùng ID pre:observe, PostToolUse dùng post:observe:continuous-learning
  pre:observe pre:observe:continuous-learning post:observe:continuous-learning stop:evaluate-session
  stop:cost-tracker post:ecc-metrics-bridge
  stop:desktop-notify
  # GateGuard: chặn lệnh Bash/Edit đầu tiên mỗi session tới khi agent liệt kê "facts".
  # Trùng ý với Karpathy và tốn thêm một lượt. Xoá 3 dòng dưới nếu muốn thử.
  pre:bash:gateguard-fact-force pre:edit-write:gateguard-fact-force
  pre:powershell:gateguard-fact-force
)
HOOK_PROFILE="standard"

REPO="https://github.com/affaan-m/ECC"
# ────────────────────────────────────────────────────────────────────

DRY=0
[[ "${1:-}" == "-n" ]] && DRY=1
CFG="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CFG/settings.json"

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
die()  { echo "Lỗi: $*" >&2; exit 1; }

for c in git node npm jq; do
  command -v "$c" >/dev/null || die "thiếu '$c' (macOS: brew install $c · Fedora: sudo dnf install $c)"
done
if [[ -f "$SETTINGS" ]]; then
  jq empty "$SETTINGS" 2>/dev/null || die "$SETTINGS không phải JSON hợp lệ"
fi

TMP="$(mktemp -d -t ecc-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

say "Clone ECC"
if [[ -n "${ECC_REF:-}" ]]; then
  git clone -q "$REPO" "$TMP/ECC"
  git -C "$TMP/ECC" checkout -q "$ECC_REF"
else
  git clone -q --depth 1 "$REPO" "$TMP/ECC"
fi
SHA="$(git -C "$TMP/ECC" rev-parse HEAD)"
echo "commit $SHA"

missing=0
for a in "${AGENTS[@]}"; do
  [[ -f "$TMP/ECC/agents/$a.md" ]] || { echo "Không có agent: $a" >&2; missing=1; }
done
for s in "${SKILLS[@]}"; do
  [[ -f "$TMP/ECC/skills/$s/SKILL.md" ]] || { echo "Không có skill: $s" >&2; missing=1; }
done
(( missing == 0 )) || die "ECC đã đổi tên hoặc xoá thành phần ở trên; sửa danh sách rồi chạy lại"

INSTALL=(bash "$TMP/ECC/install.sh" --target claude)
(( DRY == 1 )) && INSTALL+=(--dry-run)

if (( DRY == 0 )) && [[ -f "$SETTINGS" ]]; then
  BAK="$SETTINGS.bak-$(date +%Y%m%d-%H%M%S)"
  cp "$SETTINGS" "$BAK"
  echo "Đã sao lưu settings.json → $BAK"
fi

say "Cài hook runtime"
(cd "$TMP/ECC" && "${INSTALL[@]}" --modules hooks-runtime --enable-hooks) | grep -vE '^- ' || true

# Không dùng `install.sh --skills`: nó kéo theo cả module phụ thuộc
# (rules-core, agents-core, workflow-quality…), tức cả trăm skill trùng Superpowers.
say "Chép skill (${#SKILLS[@]})"
for s in "${SKILLS[@]}"; do
  echo "  $s"
  (( DRY == 1 )) && continue
  rm -rf "$CFG/skills/$s"
  mkdir -p "$CFG/skills"
  cp -r "$TMP/ECC/skills/$s" "$CFG/skills/$s"
done

say "Chép agent (${#AGENTS[@]})"
for a in "${AGENTS[@]}"; do
  echo "  $a"
  (( DRY == 1 )) && continue
  mkdir -p "$CFG/agents"
  install -m 644 "$TMP/ECC/agents/$a.md" "$CFG/agents/$a.md"
done

say "Ghi cấu hình hook vào settings.json"
DISABLED="$(IFS=,; echo "${DISABLED_HOOKS[*]}")"
echo "  ECC_HOOK_PROFILE=$HOOK_PROFILE"
echo "  ECC_DISABLED_HOOKS=$DISABLED"
if (( DRY == 0 )); then
  [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
  # 1) ghi biến môi trường điều khiển hook
  # 2) xoá hẳn các khối hook chỉ chạy MỘT hook đã tắt (bớt tiến trình node mỗi lần gọi tool).
  #    Khối dispatcher gom nhiều hook con được giữ nguyên; hook con trong đó tắt bằng biến môi trường.
  before=$(jq '[.hooks // {} | .[] | .[]] | length' "$SETTINGS")
  jq --arg p "$HOOK_PROFILE" --arg d "$DISABLED" '
    def hook_id: (.command // "") | (capture("\" (node scripts/hooks/run-with-flags\\.js )?(?<id>[a-z-]+(:[a-z0-9-]+)+) ").id) // null;
    ($d | split(",")) as $dis
    | .env = ((.env // {}) + {ECC_HOOK_PROFILE: $p, ECC_DISABLED_HOOKS: $d})
    | if .hooks then
        .hooks |= (with_entries(.value |= map(select(
            ([.hooks[]? | hook_id] | (length > 0 and all(. != null and (. as $i | $dis | index($i))))) | not
          ))) | with_entries(select(.value | length > 0)))
      else . end' "$SETTINGS" > "$TMP/settings.json"
  jq empty "$TMP/settings.json" || die "lọc settings.json thất bại; file gốc chưa bị đổi"
  mv "$TMP/settings.json" "$SETTINGS"
  after=$(jq '[.hooks // {} | .[] | .[]] | length' "$SETTINGS")
  echo "  đã xoá $((before - after)) khối hook bị tắt ($before → $after)"

  # 3) chuyển hook ECC ra khỏi settings.json, vào plugin cục bộ ecc-hooks.
  #    Claude Code không có `include` cho settings; plugin là chỗ duy nhất khác đọc được hook.
  #    Hook không phải của ECC (nếu bạn tự thêm) vẫn ở lại settings.json.
  say "Chuyển hook ECC sang plugin cục bộ"
  LOCAL="$CFG/local-plugins"; PLUG="$LOCAL/ecc-hooks"
  mkdir -p "$LOCAL/.claude-plugin" "$PLUG/.claude-plugin" "$PLUG/hooks"
  jq -n --arg o "$(id -un)" '{
      name: "kessie-local", owner: {name: $o},
      description: "Plugin cục bộ của máy này, sinh tự động, không đưa lên git",
      plugins: [{name: "ecc-hooks", source: "./ecc-hooks",
                 description: "Hook runtime của ECC (do install-necessary-ecc-user.sh sinh ra)"}]
    }' > "$LOCAL/.claude-plugin/marketplace.json"
  jq -n '{name: "ecc-hooks", description: "Hook runtime của ECC", license: "MIT"}' \
    > "$PLUG/.claude-plugin/plugin.json"

  IS_ECC='(.command // "") | test("resolve-ecc-root|plugin-hook-bootstrap|lifecycle-hook-bootstrap")'
  jq "{hooks: ((.hooks // {}) | with_entries(.value |= map(select(any(.hooks[]?; $IS_ECC))))
                             | with_entries(select(.value | length > 0)))}" "$SETTINGS" > "$PLUG/hooks/hooks.json"
  jq --arg lp "$LOCAL" "
      (if .hooks then .hooks |= (with_entries(.value |= map(select(any(.hooks[]?; $IS_ECC) | not)))
                                | with_entries(select(.value | length > 0))) else . end)
      | if (.hooks // {}) == {} then del(.hooks) else . end
      | .extraKnownMarketplaces[\"kessie-local\"] = {source: {source: \"directory\", path: \$lp}}
      | .enabledPlugins[\"ecc-hooks@kessie-local\"] = true
    " "$SETTINGS" > "$TMP/settings.json"
  jq empty "$TMP/settings.json" "$PLUG/hooks/hooks.json" || die "chuyển hook thất bại; settings.json chưa bị đổi"
  mv "$TMP/settings.json" "$SETTINGS"
  echo "  $(jq '[.hooks[][]] | length' "$PLUG/hooks/hooks.json") khối hook → $PLUG/hooks/hooks.json"
  echo "  settings.json còn $(wc -c < "$SETTINGS" | tr -d ' ') byte"

  if command -v claude >/dev/null; then
    KNOWN="$CFG/plugins/known_marketplaces.json"
    if ! { [[ -f "$KNOWN" ]] && jq -e 'has("kessie-local")' "$KNOWN" >/dev/null; }; then
      claude plugin marketplace add "$LOCAL" </dev/null || echo "  ! không thêm được marketplace kessie-local" >&2
    fi
    INST="$CFG/plugins/installed_plugins.json"
    if ! { [[ -f "$INST" ]] && jq -e '.plugins["ecc-hooks@kessie-local"]' "$INST" >/dev/null; }; then
      claude plugin install ecc-hooks@kessie-local --scope user </dev/null || echo "  ! không cài được ecc-hooks@kessie-local" >&2
    fi
  else
    echo "  ! không thấy lệnh claude: tự chạy 'claude plugin marketplace add $LOCAL' rồi 'claude plugin install ecc-hooks@kessie-local'" >&2
  fi

  # ghi nguồn + giấy phép MIT của ECC (điều kiện của giấy phép)
  mkdir -p "$CFG/ecc"
  cp "$TMP/ECC/LICENSE" "$CFG/ecc/LICENSE"
  {
    echo "source: $REPO"
    echo "commit: $SHA"
    echo "installed: $(date +%Y-%m-%dT%H:%M:%S%z)"
    echo "agents: ${AGENTS[*]}"
    echo "skills: ${SKILLS[*]}"
  } > "$CFG/ecc/SOURCE"
fi

if (( DRY == 1 )); then
  say "Chạy thử xong, chưa ghi gì."
else
  say "Xong (ECC $SHA). Khởi động lại Claude Code rồi chạy /status, /agents, /hooks để kiểm tra."
fi