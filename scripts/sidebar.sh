#!/usr/bin/env bash

self="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
layout="$(dirname "$self")/layout.py"
log_dir="${XDG_STATE_HOME:-$HOME/.local/state}/tmux"
mkdir -p "$log_dir"
exec 2>>"$log_dir/sidebar.log"

cmd="${1:-}"
[ $# -gt 0 ] && shift

log() { printf '%s [%s] %s\n' "$(date '+%F %T')" "$cmd" "$*" >&2; }

enabled() { [ "$(tmux show -gqv @sidebar_enabled)" = 1 ]; }
width() { local w; w="$(tmux show -gqv @sidebar_width)"; echo "${w:-26}"; }
sidebar_panes() { tmux list-panes "$@" -F '#{?#{@sidebar},#{pane_id},}' | grep .; }

ensure() {
  local win="$1" sess zoomed W H before pane target
  [ -z "$win" ] && return 0
  enabled || return 0
  IFS='|' read -r sess zoomed W H before <<<"$(tmux display -p -t "$win" '#{session_name}|#{window_zoomed_flag}|#{window_width}|#{window_height}|#{window_layout}')"
  [ -z "$sess" ] && { log "window $win not found"; return 1; }
  case "$sess" in _*) return 0 ;; esac
  [ "$zoomed" = 1 ] && return 0
  [ -n "$(sidebar_panes -t "$win")" ] && return 0
  pane="$(tmux split-window -hbfd -l "$(width)" -t "$win" -P -F '#{pane_id}' "exec '$self' render")" \
    || { log "split-window failed for $win"; return 1; }
  tmux set -p -t "$pane" @sidebar 1
  sidebar_panes -t "$win" | grep -vx "$pane" | while read -r extra; do tmux kill-pane -t "$extra"; done
  target="$("$layout" with "$before" "$W" "$H" "${pane#%}" "$(width)")" \
    || { log "layout with failed for $win"; return 1; }
  tmux select-layout -t "$win" "$target" || { log "select-layout failed for $win: $target"; return 1; }
  tmux set -w -t "$win" @sidebar_saved "$before"
  tmux set -w -t "$win" @sidebar_applied "$(tmux display -p -t "$win" '#{window_layout}')"
}

ensure_all() {
  enabled || return 0
  tmux list-windows -a -F '#{window_id}' | while read -r w; do ensure "$w"; done
}

remove() {
  local pane="$1" win="$2" W H zoomed panes cur saved applied target=""
  IFS='|' read -r W H zoomed panes cur saved applied <<<"$(tmux display -p -t "$win" '#{window_width}|#{window_height}|#{window_zoomed_flag}|#{window_panes}|#{window_layout}|#{@sidebar_saved}|#{@sidebar_applied}')"
  if [ "$zoomed" != 1 ] && [ "$panes" -gt 1 ]; then
    if [ -n "$saved" ] && [ "$cur" = "$applied" ]; then
      target="$saved"
    else
      target="$("$layout" without "$cur" "$W" "$H" "${pane#%}")" || log "layout without failed for $win"
    fi
  fi
  tmux kill-pane -t "$pane" || { log "kill-pane $pane failed"; return 1; }
  [ "$panes" -gt 1 ] || return 0
  tmux set -uw -t "$win" @sidebar_saved
  tmux set -uw -t "$win" @sidebar_applied
  [ -n "$target" ] && { tmux select-layout -t "$win" "$target" || log "select-layout failed for $win: $target"; }
}

fit() {
  local win="$1" pane W H zoomed cur sw target
  enabled || return 0
  pane="$(sidebar_panes -t "$win" | head -1)"
  [ -z "$pane" ] && return 0
  IFS='|' read -r W H zoomed sw cur <<<"$(tmux display -p -t "$pane" '#{window_width}|#{window_height}|#{window_zoomed_flag}|#{pane_width}|#{window_layout}')"
  [ "$zoomed" = 1 ] && return 0
  [ "$sw" = "$(width)" ] && return 0
  tmux set -uw -t "$win" @sidebar_saved
  tmux set -uw -t "$win" @sidebar_applied
  if target="$("$layout" with "$cur" "$W" "$H" "${pane#%}" "$(width)")"; then
    tmux select-layout -t "$win" "$target" && return 0
    log "select-layout failed for $win: $target"
  else
    log "layout with failed for $win"
  fi
  tmux resize-pane -t "$pane" -x "$(width)" || log "resize-pane $pane failed"
}

hide() {
  tmux set -g @sidebar_enabled 0
  tmux list-panes -a -F '#{?#{@sidebar},#{pane_id}|#{window_id},}' | grep . | while IFS='|' read -r p w; do remove "$p" "$w"; done
}

toggle() {
  if enabled; then hide; else tmux set -g @sidebar_enabled 1 && ensure_all; fi
}

focus() {
  tmux set -g @sidebar_enabled 1
  ensure "$1"
  local p
  p="$(sidebar_panes -t "$1" | head -1)"
  [ -n "$p" ] && tmux select-pane -t "$p"
}

switch_to() {
  local name="$1" client="${2:-}"
  if [ -n "$client" ]; then
    tmux switch-client -c "$client" -t "=$name" || log "switch to '$name' failed"
  else
    tmux last-pane -t "$TMUX_PANE" || tmux select-pane -t "$TMUX_PANE" -R
    tmux switch-client -t "=$name" || log "switch to '$name' failed"
  fi
}

click() {
  local pane="$1" y="$2" client="$3" rows
  if [ "$y" = 0 ]; then hide; return; fi
  rows="$(tmux show -pqv -t "$pane" @sidebar_rows)"
  local name
  name="$(printf '%s' "$rows" | tr '\t' '\n' | sed -n "$((y - 1))p")"
  [ -n "$name" ] && switch_to "$name" "$client"
}

next_waiting() {
  local client="$1" current="$2" target
  target="$(tmux list-windows -a -F '#{window_id}	#{session_name}	#{@claude_state}#{@codex_state}' | awk -F'\t' -v cur="$current" '
    $2 ~ /^_/ { next }
    $1 == cur { seen = 1; next }
    $3 ~ /waiting/ { if (seen && !after) after = $1 "\t" $2; if (!first) first = $1 "\t" $2 }
    END { print (after ? after : first) }')"
  if [ -z "$target" ]; then
    tmux display-message -c "$client" "No agent is waiting for input"
    return
  fi
  tmux switch-client -c "$client" -t "=${target#*	}" && tmux select-window -t "${target%%	*}" \
    || log "jump to $target failed"
}

render() {
  local RED=$'\e[38;2;48;52;70;48;2;231;130;132m' YEL=$'\e[38;2;229;200;144m' DIM=$'\e[38;2;115;121;148m'
  local BOLD=$'\e[1m' REV=$'\e[7m' RST=$'\e[0m' EL=$'\e[K'
  local cursor=0 prev="" prev_rows="" key seq last_fit_w=""

  tmux set -p -t "$TMUX_PANE" @sidebar 1
  tmux select-pane -t "$TMUX_PANE" -T sidebar
  printf '\e[?1049h\e[?25l\e[?1000h'
  trap 'printf "\e[?1000l\e[?25h\e[?1049l"' EXIT

  while :; do
    local info visible w h panes active cur_sess
    info="$(tmux display -p -t "$TMUX_PANE" '#{&&:#{window_active},#{session_attached}}	#{pane_width}	#{pane_height}	#{window_panes}	#{pane_active}	#{session_name}')" || exit 0
    IFS=$'\t' read -r visible w h panes active cur_sess <<<"$info"
    enabled || exit 0
    [ "$panes" = 1 ] && exit 0

    if [ "$visible" = 1 ]; then
      if [ "$w" != "$(width)" ] && [ "$w" != "$last_fit_w" ]; then
        last_fit_w="$w"
        "$self" fit "$(tmux display -p -t "$TMUX_PANE" '#{window_id}')"
      fi

      local names=() states=() rows_str="" name st n i
      while IFS=$'\t' read -r name st; do
        [ -z "$name" ] && continue
        names+=("$name"); states+=("$st"); rows_str+="$name"$'\t'
      done <<<"$(tmux list-windows -a -F '#{session_name}	#{@claude_state} #{@codex_state}' | awk -F'\t' '
        $1 ~ /^_/ { next }
        { s = ($2 ~ /waiting/) ? 2 : ($2 ~ /working/) ? 1 : 0
          if (!($1 in best)) { order[++n] = $1; best[$1] = s } else if (s > best[$1]) best[$1] = s }
        END { for (i = 1; i <= n; i++) print order[i] "\t" best[order[i]] }')"

      n=${#names[@]}
      [ "$cursor" -ge "$n" ] && cursor=$((n - 1))
      [ "$cursor" -lt 0 ] && cursor=0
      if [ "$rows_str" != "$prev_rows" ]; then
        tmux set -p -t "$TMUX_PANE" @sidebar_rows "$rows_str"
        prev_rows="$rows_str"
      fi

      local nw=$((w - 5)) frame line sep="" mark ind style
      for ((i = 0; i < w - 1; i++)); do sep+="─"; done
      frame="$BOLD$(printf '%-*s' $((w - 3)) ' Sessions')$RST${DIM}«$RST$EL"$'\n'"$DIM$sep$RST$EL"
      for ((i = 0; i < n && i < h - 6; i++)); do
        mark=" "; ind=" "; style=""
        [ "${names[$i]}" = "$cur_sess" ] && { mark="▸"; style="$BOLD"; }
        case "${states[$i]}" in
          2) ind="●"; style="$style$RED" ;;
          1) ind="${YEL}◐${RST}" ;;
        esac
        [ "$active" = 1 ] && [ "$i" = "$cursor" ] && style="$style$REV"
        line="$style$mark $(printf '%-*.*s' "$nw" "$nw" "${names[$i]}") $ind$RST"
        frame+=$'\n'"$line$EL"
      done
      frame+=$'\e[J'$'\e['"$((h - 2))"';1H'"$DIM click/⏎  switch$EL"$'\n'" C-a a    next waiting$EL"$'\n'" C-a t    hide$RST$EL"
      if [ "$frame" != "$prev" ]; then
        printf '\e[H%s' "$frame"
        prev="$frame"
      fi
    fi

    if read -rsn1 -t 1 key; then
      case "$key" in
        j) cursor=$((cursor + 1)) ;;
        k) cursor=$((cursor - 1)) ;;
        q) tmux run -b "'$self' hide" ;;
        "") [ -n "${names[$cursor]:-}" ] && switch_to "${names[$cursor]}" ;;
        $'\e')
          read -rsn2 -t 1 seq
          case "$seq" in
            "[A") cursor=$((cursor - 1)) ;;
            "[B") cursor=$((cursor + 1)) ;;
            "[M") read -rsn3 -t 1 seq ;;
          esac ;;
      esac
      prev=""
    fi
  done
}

case "$cmd" in
  ensure) ensure "$@" ;;
  ensure-all) ensure_all ;;
  fit) fit "$@" ;;
  toggle) toggle "$@" ;;
  hide) hide ;;
  focus) focus "$@" ;;
  click) click "$@" ;;
  next-waiting) next_waiting "$@" ;;
  render) render ;;
  *) log "unknown command '$cmd'"; exit 1 ;;
esac
