#!/usr/bin/env bash

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
mkdir -p "$log_dir"
exec 2>>"$log_dir/sidebar.log"

case "${1:-}" in *agent-turn-complete*) ;; *) exit 0 ;; esac
[ -n "${TMUX:-}" ] && [ -n "${TMUX_PANE:-}" ] || exit 0

tmux set -w -t "$TMUX_PANE" @codex_state waiting \
  || printf '%s [codex-notify] failed to set state for %s\n' "$(date '+%F %T')" "$TMUX_PANE" >&2
tty="$(tmux display -p -t "$TMUX_PANE" '#{pane_tty}')"
[ -n "$tty" ] && printf '\a' >"$tty"
