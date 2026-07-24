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
3. Symlinks any existing `node_modules` directories next to tracked `package.json` files into the same relative paths in the worktree
4. Starts a tmux session named `<name>` with three windows:
   - `claude` running `claude --effort high`
   - `codex` running `codex -c 'model_reasoning_effort="high"' '$prepare-to-tels-in-tmux'`
   - `console` running a plain shell
5. Opens the session directly through tmuxp, or switches clients when opening an existing session from inside tmux

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
- If Claude or Codex is waiting for confirmation, the window is tracked with an internal leading `!` marker and the visible tmux tab shows `[!] Action Required: <window>`
- While any window in a session needs attention, the outer terminal title appends `[!] Action Required` to `tmux attach -t <session>`
- When the prompt is cleared, the watcher removes the attention marker and restores the normal terminal title

Window navigation shortcuts:

| Keys | Action |
|---|---|
| `Alt+h` | Previous window |
| `Alt+l` | Next window |
| `Alt+Shift+[` | Previous window |
| `Alt+Shift+]` | Next window |
| `Ú` | Previous window on macOS/iTerm |
| `Æ` | Next window on macOS/iTerm |

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
