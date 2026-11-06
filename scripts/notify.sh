#!/usr/bin/env bash
# ~/.claude/scripts/notify.sh — hook Notification/Stop của Claude Code, chạy trên macOS và Linux.
#
# Terminal có thông báo riêng → trả về `terminalSequence` để Claude Code ghi mã escape,
# thông báo thuộc về terminal (bấm vào là nhảy đúng tab):
#   iTerm2, WezTerm: OSC 9   ·   Kitty: OSC 99 (chỉ báo khi cửa sổ không focus)   ·   Ghostty: OSC 777
# Terminal khác (VS Code, JetBrains, Apple Terminal, gnome-terminal…) hoặc trong tmux/screen
#   → thông báo của hệ điều hành (terminal-notifier/osascript trên macOS, notify-send trên Linux).
#
#   CLAUDE_NOTIFY_OS=1     luôn dùng thông báo hệ điều hành
#   CLAUDE_NOTIFY_SOUND=0  tắt âm thanh (chỉ áp dụng cho thông báo hệ điều hành)
#   CLAUDE_NOTIFY_LOG=1    ghi mỗi lần hook chạy vào ~/.claude/notify.log
# Chạy được với bash 3.2. Không bao giờ chặn Claude Code.

input=$(cat)
has_jq=0; command -v jq >/dev/null 2>&1 && has_jq=1

event=""; msg=""; proj=""
if (( has_jq )); then
  event=$(jq -r '.hook_event_name // empty' <<<"$input" 2>/dev/null)
  msg=$(jq -r '.message // empty' <<<"$input" 2>/dev/null)
  d=$(jq -r '.cwd // empty' <<<"$input" 2>/dev/null); [[ -n "$d" ]] && proj=$(basename "$d")
fi
if [[ -z "$msg" ]]; then
  [[ "$event" == Stop ]] && msg="Claude đã làm xong" || msg="Claude cần bạn xem"
fi
title="Claude Code${proj:+ · $proj}"

# ─── Chọn cách báo ───────────────────────────────────────────────────
via=os
if [[ "${CLAUDE_NOTIFY_OS:-0}" != 1 && $has_jq == 1 && -z "${TMUX:-}" && "${TERM:-}" != screen* ]]; then
  if [[ -n "${KITTY_WINDOW_ID:-}" || "${TERM:-}" == xterm-kitty ]]; then via=kitty
  else
    case "${TERM_PROGRAM:-}" in
      iTerm.app|WezTerm) via=osc9 ;;
      ghostty)           via=osc777 ;;
    esac
  fi
fi

if [[ "${CLAUDE_NOTIFY_LOG:-0}" == 1 ]]; then
  printf '%s  event=%s  term=%s  via=%s  msg=%s\n' "$(date '+%F %T')" "${event:-?}" \
    "${TERM_PROGRAM:-${TERM:-?}}" "$via" "$msg" >> "$HOME/.claude/notify.log" 2>/dev/null
fi

# ─── Thông báo của terminal ──────────────────────────────────────────
clean() { tr -d '\000-\037\177' <<<"$1"; }   # bỏ ký tự điều khiển để không chèn được mã escape
if [[ "$via" != os ]]; then
  t=$(clean "$title"); m=$(clean "$msg")
  case "$via" in
    osc9)   seq=$(printf '\033]9;%s: %s\007' "$t" "$m") ;;
    osc777) seq=$(printf '\033]777;notify;%s;%s\007' "${t//;/,}" "${m//;/,}") ;;
    kitty)  seq=$(printf '\033]99;i=claude:d=0:o=unfocused;%s\033\\\033]99;i=claude:p=body;%s\033\\' "$t" "$m") ;;
  esac
  jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
  exit 0
fi

# ─── Thông báo của hệ điều hành ──────────────────────────────────────
sound="${CLAUDE_NOTIFY_SOUND:-1}"
case "$(uname -s)" in
  Darwin)
    if command -v terminal-notifier >/dev/null 2>&1; then
      args=(-title "$title" -message "$msg" -group "claude-code")
      [[ "$sound" == 1 ]] && args+=(-sound Glass)
      terminal-notifier "${args[@]}" >/dev/null 2>&1
    else
      osascript -e 'on run argv' \
                -e 'display notification (item 1 of argv) with title (item 2 of argv)' \
                -e 'end run' "$msg" "$title" >/dev/null 2>&1
      [[ "$sound" == 1 ]] && { afplay /System/Library/Sounds/Glass.aiff >/dev/null 2>&1 & }
    fi
    ;;
  Linux)
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Claude Code" -i dialog-information "$title" "$msg" >/dev/null 2>&1
    if [[ "$sound" == 1 ]]; then
      oga=/usr/share/sounds/freedesktop/stereo/message.oga
      if command -v canberra-gtk-play >/dev/null 2>&1; then
        { canberra-gtk-play -i message-new-instant >/dev/null 2>&1 & }
      elif [[ -f "$oga" ]] && command -v pw-play >/dev/null 2>&1; then
        { pw-play "$oga" >/dev/null 2>&1 & }
      elif [[ -f "$oga" ]] && command -v paplay >/dev/null 2>&1; then
        { paplay "$oga" >/dev/null 2>&1 & }
      fi
    fi
    ;;
esac
exit 0