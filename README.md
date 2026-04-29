# dotfiles

Portable tmux + tmuxp feature-session setup for Claude Code and Codex.

## What's included

| File | Purpose |
|---|---|
| `install.sh` | Installs tmuxp if needed, symlinks configs and helper scripts, reloads tmux |
| `bin/new-session` | Creates a git worktree and launches a tmux session for it |
| `bin/tmux-*` | Status-bar, attention, and clipboard helpers used by tmux |
| `tmux/tmux.conf` | tmux navigation, window menus, mouse, and clipboard config |
| `tmuxp/feature.yaml` | Default three-window session layout |

## Fresh-machine requirements

- `bash`
- `git`
- `tmux` 3.0+
- Python 3 or `uv` so `install.sh` can install `tmuxp`
- `claude` CLI
- `codex` CLI

`install.sh` will install `tmuxp` for you if it is missing. It does not install system packages or the Claude/Codex CLIs.

## Install

Clone this repository anywhere you want, then run the installer from that checkout:

```bash
git clone git@github.com:yourname/dotfiles.git ~/src/dotfiles
cd ~/src/dotfiles
./install.sh
```

The repo path is not hardcoded. After installation, the tmux config and helper commands work even if the checkout is not at `~/.dotfiles`.

`install.sh` will:

- Check core dependencies
- Install `tmuxp` if needed
- Symlink `~/.tmux.conf`, `~/.tmuxp/feature.yaml`, and every executable in `bin/` into `~/.local/bin`
- Back up any existing non-symlink targets as `*.bak`
- Reload tmux if a server is already running
- Warn if `~/.local/bin` is not on your `PATH`

If `~/.local/bin` is missing from your shell config, add:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

For every project repo where you plan to use worktrees, ignore `.worktrees/`:

```bash
echo '.worktrees/' >> /path/to/your/repo/.gitignore
```

## Usage

Start a feature session from the primary checkout of the repository you want to work on:

```bash
new-session <name> [base-branch]
```

Examples:

```bash
new-session payments-refactor      # branches from the current branch in the main checkout
new-session auth-fix main          # branches from main explicitly
```

What `new-session` does:

1. Creates `.worktrees/<name>` on branch `<name>`
2. Symlinks root `.env` and `.env.local` into the worktree if those files exist in the main checkout
3. Starts a tmux session named `<name>` with three windows:
   - `claude` running `claude --effort high`
   - `codex` running `codex -c 'model_reasoning_effort="high"'`
   - `console` running a plain shell

If you omit `[base-branch]`, `new-session` now uses the currently checked-out branch in the main repo instead of assuming `develop`.

## Recreate a session

```bash
new-session <name> --recreate
new-session --recreate <name> [base-branch]
```

This kills the tmux session, removes the worktree, deletes the branch, and rebuilds the session from scratch.

Run recreate from outside the tmux session you are destroying, otherwise tmux will kill the shell you are currently using.

## Window behaviour

- `claude` windows are orange
- `codex` windows are green
- Other windows are grey
- If Claude or Codex is waiting for confirmation, the window is renamed with a leading `!` and the active tab turns yellow

Window navigation shortcuts:

| Keys | Action |
|---|---|
| `Alt+h` | Previous window |
| `Alt+l` | Next window |
| `Alt+Shift+[` | Previous window |
| `Alt+Shift+]` | Next window |
| `Cmd+Shift+[` | Previous window on macOS terminals that emit the expected sequence |
| `Cmd+Shift+]` | Next window on macOS terminals that emit the expected sequence |

Mouse selection copy now uses `bin/tmux-copy`, which picks the first available clipboard tool from `pbcopy`, `wl-copy`, `xclip`, or `xsel`.

## Customising the layout

Duplicate `tmuxp/feature.yaml`, change the windows or startup commands, and create another launcher script that follows the same placeholder pattern as `bin/new-session`.

Placeholders used in tmuxp templates:

```text
${TMUXP_NAME}      tmux session name
${TMUXP_WORKTREE}  absolute worktree path
```

`new-session` renders those placeholders into a temporary tmuxp file before loading the session, then applies the status-bar hooks and watcher scripts.

## Updating

Pull the latest changes in this repo, then rerun the installer so any new helper scripts are symlinked:

```bash
cd /path/to/this/repo
git pull
./install.sh
```
