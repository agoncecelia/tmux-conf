#!/usr/bin/env bash
set -uo pipefail

flavor="${1:?usage: theme.sh <latte|mocha>}"

tmux has-session 2>/dev/null || exit 0
[[ "$(tmux show -gv @catppuccin_flavor 2>/dev/null)" == "$flavor" ]] && exit 0

cmds=()
while read -r opt _; do
  cmds+=(set -gu "$opt" \;)
done < <(tmux show -g | grep -E '^@(thm_|catppuccin_|_ctp_)')

if ! out=$(tmux ${cmds[@]+"${cmds[@]}"} \
  set -g @catppuccin_flavor "$flavor" \; \
  source-file ~/.config/tmux/conf/theme.conf \; \
  run-shell ~/.config/tmux/plugins/tmux/catppuccin.tmux 2>&1); then
  echo "theme.sh: failed to apply $flavor: $out" >&2
  tmux display-message "theme.sh: failed to apply $flavor: $out"
  exit 1
fi
