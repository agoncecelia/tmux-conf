# tmux

Modular tmux config with a session sidebar that tracks Claude Code / Codex agents.

## Install

```sh
git clone https://github.com/agoncecelia/tmux-conf ~/.config/tmux
tmux
```

TPM and plugins install automatically on first launch into `plugins/` (gitignored). Remove any `~/.tmux.conf`, since tmux reads it before `~/.config/tmux/tmux.conf`.

Requires tmux 3.3+, `bash`, and `python3` (sidebar layout math).

## Layout

| Path | Purpose |
| --- | --- |
| `tmux.conf` | Sources `conf/*.conf` in order; plugins load last |
| `conf/options.conf` | Terminal, history, indexing, activity/focus options |
| `conf/keys.conf` | Prefix and navigation bindings |
| `conf/copy.conf` | Vi copy mode, clipboard, mouse |
| `conf/agents.conf` | Claude/diff/scratch popups, agent "seen" hooks |
| `conf/sidebar.conf` | Session sidebar hooks and bindings |
| `conf/plugins.conf` | TPM, catppuccin (frappe), resurrect, continuum |
| `scripts/sidebar.sh` | Sidebar lifecycle and renderer |
| `scripts/layout.py` | Rescales window layouts when the sidebar opens/closes/resizes |
| `scripts/agent-seen.sh` | Clears an agent's "waiting" state when its window is focused |
| `scripts/claude-tmux.sh` | Claude Code lifecycle hook (state, bell, notification) |
| `scripts/claude-status-segment.sh` | Claude state segment for `status-right` |
| `scripts/codex-notify.sh` | Codex `notify` hook |
| `scripts/theme-patch.sh` | Re-applies status segments after catppuccin rebuilds them |

## Keys

Prefix is `C-a`.

| Key | Action |
| --- | --- |
| `prefix r` / `prefix e` | reload / edit config |
| `prefix \` or `_` / `-` | split horizontal / vertical (keeps cwd) |
| `prefix h j k l` | move between panes |
| `prefix H J K L` | resize pane |
| `prefix +` | zoom pane |
| `prefix C-h` / `C-l` / `Tab` | previous / next / last window |
| `prefix C-c` / `C-f` / `S` / `BTab` | new / find / choose / last session |
| `prefix Enter`, `v`, `y` | copy mode, select, yank to system clipboard |
| `prefix m` | toggle mouse |
| `prefix C` | Claude popup in the current directory |
| `prefix D` | `git diff HEAD` popup |
| `prefix g` | toggle scratch session popup |
| `C-l` | clear screen and scrollback |

## Session sidebar

| Key | Action |
| --- | --- |
| `prefix t` / click `☰` in the status bar | show/hide sidebar |
| `prefix T` | focus sidebar (`j`/`k`, `Enter` switch, `q` hide) |
| `prefix a` | jump to the next session where an agent is waiting |
| click a session / `«` | switch to it / hide sidebar |

Red row = Claude or Codex waiting for input, `◐` = working. Width: `set -g @sidebar_width 26`.

The sidebar is created in every window up front (on attach and toggle) so switching windows doesn't resize panes. Opening it shrinks existing panes proportionally, closing it restores the previous layout (or grows panes proportionally if you changed it meanwhile), and window resizes re-fit it in one step.

Sessions whose name starts with `_` (e.g. the scratch popup) are skipped.

## Agent integration

- Claude state is driven by `scripts/claude-tmux.sh`, which sets the `@claude_state` window option (`working` / `waiting` / `idle`) and, when it's your turn, rings the pane bell and sends a desktop notification via `terminal-notifier` (optional, `brew install terminal-notifier`). Link it and register it for each event in `~/.claude/settings.json`:

  ```sh
  mkdir -p ~/.claude/hooks
  ln -sf ~/.config/tmux/scripts/claude-tmux.sh ~/.claude/hooks/claude-tmux.sh
  ```

  ```json
  "hooks": {
    "SessionStart":     [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh SessionStart" }] }],
    "UserPromptSubmit": [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh UserPromptSubmit" }] }],
    "PostToolUse":      [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh PostToolUse" }] }],
    "Notification":     [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh Notification" }] }],
    "Stop":             [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh Stop" }] }],
    "SessionEnd":       [{ "hooks": [{ "type": "command", "command": "~/.claude/hooks/claude-tmux.sh SessionEnd" }] }]
  }
  ```
- Codex needs `notify = ["<home>/.config/tmux/scripts/codex-notify.sh"]` in `~/.codex/config.toml`.

Errors are logged to `~/.local/state/tmux/sidebar.log`.
