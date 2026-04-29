#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo "[info] $*"; }
success() { echo "[ok]   $*"; }
error()   { echo "[err]  $*" >&2; }
warn()    { echo "[warn] $*"; }

symlink() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [[ -e "$dst" && ! -L "$dst" ]]; then
    info "Backing up existing $dst → $dst.bak"
    mv "$dst" "$dst.bak"
  fi
  ln -sf "$src" "$dst"
  success "$dst → $src"
}

# ── Dependencies ──────────────────────────────────────────────────────────────

info "Checking dependencies..."

if ! command -v git &>/dev/null; then
  error "git is not installed. Install it first, then re-run this script."
  exit 1
fi

if ! command -v tmux &>/dev/null; then
  error "tmux is not installed. Install it first:"
  echo "  macOS:  brew install tmux"
  echo "  Ubuntu: sudo apt install tmux"
  exit 1
fi

if ! command -v tmuxp &>/dev/null; then
  info "tmuxp not found — installing via pip..."
  if command -v uv &>/dev/null; then
    uv tool install tmuxp
  elif command -v pip3 &>/dev/null; then
    pip3 install --user tmuxp
  else
    error "pip3 not found. Install Python 3 first, then re-run this script."
    exit 1
  fi
fi

if ! command -v claude &>/dev/null; then
  warn "claude CLI not found. Install it before running new-session."
fi

if ! command -v codex &>/dev/null; then
  warn "codex CLI not found. Install it before running new-session."
fi

# ── Symlinks ──────────────────────────────────────────────────────────────────

info "Wiring dotfiles..."

symlink "$DOTFILES/tmux/tmux.conf"      "$HOME/.tmux.conf"
symlink "$DOTFILES/tmuxp/feature.yaml"  "$HOME/.tmuxp/feature.yaml"

mkdir -p "$BIN_DIR"
for script in "$DOTFILES"/bin/*; do
  if [[ -f "$script" && -x "$script" ]]; then
    symlink "$script" "$BIN_DIR/$(basename "$script")"
  fi
done

# ── PATH check ────────────────────────────────────────────────────────────────

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  echo ""
  info "~/.local/bin is not in your PATH. Add this to your ~/.bashrc or ~/.zshrc:"
  echo '  export PATH="$HOME/.local/bin:$PATH"'
fi

# ── tmux reload ───────────────────────────────────────────────────────────────

if tmux info &>/dev/null 2>&1; then
  info "Reloading tmux config..."
  tmux source "$HOME/.tmux.conf" && success "tmux config reloaded"
fi

echo ""
success "Done. Run: new-session <feature-name> [base-branch]"
