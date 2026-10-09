#!/usr/bin/env bash

if ! info=$(pmset -g batt 2>&1); then
  logger -t tmux-battery "pmset failed: $info"
  exit 1
fi

line=$(grep -m1 InternalBattery <<<"$info") || exit 0
pct=$(grep -oE '[0-9]+%' <<<"$line" | tr -d '%')
state=$(awk -F'; ' '{print $2}' <<<"$line")

if [[ -z $pct ]]; then
  logger -t tmux-battery "could not parse pmset output: $line"
  exit 1
fi

case "$1" in
  icon)
    case "$state" in
      charging) echo "󰂄" ;;
      charged|finishing\ charge|AC\ attached*) echo "󰚥" ;;
      *)
        icons=(󰁺 󰁻 󰁼 󰁽 󰁾 󰁿 󰂁 󰁹)
        idx=$(( pct * 8 / 101 ))
        echo "${icons[$idx]}"
        ;;
    esac
    ;;
  *) echo "${pct}%" ;;
esac
