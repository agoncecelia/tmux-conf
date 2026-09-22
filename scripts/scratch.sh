#!/usr/bin/env bash

log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
mkdir -p "$log_dir"
exec 2>>"$log_dir/sidebar.log"

log() { printf '%s [scratch] %s\n' "$(date '+%F %T')" "$*" >&2; }

dir="${1:-$HOME}"
[ -d "$dir" ] || { log "dir '$dir' missing, using HOME"; dir="$HOME"; }
sess=_scratch

if ! tmux has-session -t "=$sess" 2>/dev/null; then
  exec tmux new-session -s "$sess" -c "$dir"
fi

IFS='|' read -r cmd cur <<<"$(tmux display -p -t "=$sess:" '#{pane_current_command}|#{pane_current_path}')"
if [ "$cur" != "$dir" ]; then
  case "$cmd" in
    zsh|bash|sh|fish|-zsh|-bash)
      tmux send-keys -t "=$sess:" C-u "cd -- $(printf '%q' "$dir") && clear" Enter || log "cd in $sess to '$dir' failed"
      ;;
    *)
      tmux new-window -t "=$sess:" -c "$dir" || log "new-window in $sess at '$dir' failed"
      ;;
  esac
fi

exec tmux attach-session -t "=$sess"
