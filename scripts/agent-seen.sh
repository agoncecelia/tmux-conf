#!/usr/bin/env bash

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
mkdir -p "$log_dir"
exec 2>>"$log_dir/sidebar.log"

win="${1:-}"
[ -z "$win" ] && exit 0

IFS='|' read -r claude codex <<<"$(tmux display -p -t "$win" '#{@claude_state}|#{@codex_state}')"
changed=0
if [ "$claude" = waiting ]; then
  tmux set -w -t "$win" @claude_state idle || printf '%s [agent-seen] clear claude on %s failed\n' "$(date '+%F %T')" "$win" >&2
  changed=1
fi
if [ "$codex" = waiting ]; then
  tmux set -uw -t "$win" @codex_state || printf '%s [agent-seen] clear codex on %s failed\n' "$(date '+%F %T')" "$win" >&2
  changed=1
fi
[ "$changed" = 1 ] && tmux refresh-client -S
exit 0
