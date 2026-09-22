#!/usr/bin/env bash
# Renders a catppuccin-latte status segment for the given window's Claude state.
# Invoked from status-right as: #(claude-status-segment.sh #{window_id})
# Prints nothing when no Claude session is active in that window.

win="$1"
[ -z "$win" ] && exit 0

state="$(tmux show-options -wqv -t "$win" @claude_state 2>/dev/null)"

case "$state" in
  waiting) printf ' #[fg=#eff1f5,bg=#d20f39] ● claude #[default]' ;;  # red  — your turn
  working) printf ' #[fg=#11111b,bg=#df8e1d] ◐ claude #[default]' ;;  # yellow — thinking
  idle)    printf ' #[fg=#eff1f5,bg=#8c8fa1] ○ claude #[default]' ;;  # grey — ready
  *)       : ;;                                                        # nothing
esac

exit 0
