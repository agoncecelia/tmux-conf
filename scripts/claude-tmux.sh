#!/usr/bin/env bash
# Claude Code lifecycle hook -> tmux state + macOS notification.
#
# Records Claude's state into a per-window tmux option (@claude_state) so the
# status bar can show idle/working/waiting, and fires a desktop notification +
# pane bell when it's your turn. The event name is passed as $1 (one per hook in
# settings.json). Hook JSON arrives on stdin and is ignored.

event="${1:-}"
cat >/dev/null 2>&1 || true   # drain stdin so Claude's pipe closes cleanly

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
mkdir -p "$log_dir"
exec 2>>"$log_dir/sidebar.log"
log() { printf '%s [claude-tmux %s] %s\n' "$(date '+%F %T')" "$event" "$*" >&2; }

# event -> (state, notify?, body)
state=""; notify=0; body=""
case "$event" in
  SessionStart)     state="idle" ;;
  UserPromptSubmit|PostToolUse) state="working" ;;
  SessionEnd)       state="clear" ;;
  Stop)             state="waiting"; notify=1; body="Finished — your turn" ;;
  Notification)     state="waiting"; notify=1; body="Needs your input" ;;
esac

# -- update tmux window state + force an immediate status redraw ---------------
win=""
if [ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ]; then
  win="$(tmux display -p -t "$TMUX_PANE" '#{window_id}')" || log "window lookup failed for $TMUX_PANE"
  if [ -n "$win" ]; then
    if [ "$state" = "clear" ]; then
      tmux set-option -uw -t "$win" @claude_state || log "unset @claude_state on $win failed"
    elif [ -n "$state" ]; then
      tmux set-option -w -t "$win" @claude_state "$state" || log "set @claude_state=$state on $win failed"
    fi
    tmux refresh-client -S || log "refresh-client failed"
  fi
fi

# -- "your turn": pane bell (flags the window) + desktop notification ----------
if [ "$notify" = "1" ]; then
  if [ -n "$win" ]; then
    tty="$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}')" || log "pane_tty lookup failed for $TMUX_PANE"
    if [ -n "$tty" ]; then printf '\a' >"$tty" || log "bell to $tty failed"; fi
  fi

  if command -v terminal-notifier >/dev/null 2>&1; then
    bundle=""
    case "${TERM_PROGRAM:-}" in
      iTerm.app)      bundle="com.googlecode.iterm2" ;;
      Apple_Terminal) bundle="com.apple.Terminal" ;;
      ghostty)        bundle="com.mitchellh.ghostty" ;;
      WezTerm)        bundle="com.github.wez.wezterm" ;;
      vscode)         bundle="com.microsoft.VSCode" ;;
      Hyper)          bundle="co.zeit.hyper" ;;
    esac
    args=(-title "Claude Code" -message "$body" -sound default -group claude-code)
    [ -n "$bundle" ] && args+=(-activate "$bundle")
    [ -n "$win" ] && args+=(-execute "tmux select-window -t '$win'")
    terminal-notifier "${args[@]}" >/dev/null || log "terminal-notifier failed"
  fi
fi

exit 0
