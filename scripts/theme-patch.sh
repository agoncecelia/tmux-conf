#!/usr/bin/env bash
# catppuccin rebuilds status-left/right on load (and again after plugin updates), so re-apply for ~15s until it settles.

dir="$(cd "$(dirname "$0")" && pwd)"
seg="#($dir/claude-status-segment.sh #{window_id})"
button="#[range=user|sidebar]#[fg=#303446,bg=#8caaee] ☰ #[norange default] "

for _ in $(seq 1 30); do
  cur="$(tmux show -gv status-right)"
  if [ -n "$cur" ]; then
    want="${cur%'#('*claude-status-segment.sh*}${seg}"
    [ "$cur" != "$want" ] && tmux set -g status-right "$want"
  fi
  cur="$(tmux show -gv status-left)"
  want="${button}${cur#"$button"}"
  [ "$cur" != "$want" ] && tmux set -g status-left "$want"
  sleep 0.5
done
