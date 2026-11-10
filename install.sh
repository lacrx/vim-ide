#!/usr/bin/env bash
# Install the three-pane vim IDE. Idempotent. Nothing is deleted: an existing
# vimrc or ide.vim is moved aside with a timestamp.
set -euo pipefail

VIMDIR="${VIMDIR:-$HOME/.vim}"
VIMRC="${VIMRC:-$HOME/.vimrc}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"
SKIP_PLUGINS="${SKIP_PLUGINS:-0}"
NO_VIMRC="${NO_VIMRC:-0}"

say() { printf '  %s\n' "$*"; }

command -v vim >/dev/null || { echo "vim not found on PATH"; exit 1; }
if ! vim --version | grep -q '+terminal'; then
  echo "This vim lacks +terminal, which the agent pane requires."
  vim --version | head -1
  exit 1
fi

echo "==> config"
mkdir -p "$VIMDIR/colors"
[ -f "$VIMDIR/ide.vim" ] && { mv "$VIMDIR/ide.vim" "$VIMDIR/ide.vim.bak.$STAMP"; say "kept old ide.vim as ide.vim.bak.$STAMP"; }
cp "$SRC/ide.vim" "$VIMDIR/ide.vim"
cp "$SRC/colors/wim-warm.vim" "$VIMDIR/colors/wim-warm.vim"
say "installed $VIMDIR/ide.vim and colors/wim-warm.vim"

if [ "$SKIP_PLUGINS" != "1" ]; then
  echo "==> optional plugins (pure vimscript, nothing compiled)"
  mkdir -p "$VIMDIR/pack/ide/start"
  for spec in "nerdtree preservim/nerdtree" "ctrlp ctrlpvim/ctrlp.vim"; do
    name="${spec%% *}"; slug="${spec#* }"; repo="${slug#*/}"
    if [ -d "$VIMDIR/pack/ide/start/$name" ]; then say "$name already present"; continue; fi
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/p.zip" "https://codeload.github.com/$slug/zip/refs/heads/master" \
       && unzip -q "$tmp/p.zip" -d "$tmp/x" 2>/dev/null; then
      mv "$tmp/x/$repo-master" "$VIMDIR/pack/ide/start/$name"
      say "installed $name"
    else
      say "could not fetch $name (skipping; the config falls back without it)"
    fi
    rm -rf "$tmp"
  done
fi

if [ "$NO_VIMRC" != "1" ]; then
  echo "==> vimrc"
  MARK="\" >>> vim-ide"
  if [ -f "$VIMRC" ] && grep -qF "$MARK" "$VIMRC"; then
    say "already sourced from $VIMRC"
  else
    [ -f "$VIMRC" ] && { cp "$VIMRC" "$VIMRC.bak.$STAMP"; say "backed up $VIMRC"; }
    {
      printf '%s\n' "$MARK"
      printf '%s\n' "source $VIMDIR/ide.vim"
      printf '%s\n' "\" <<< vim-ide"
    } >> "$VIMRC"
    say "added a source line to $VIMRC"
  fi
fi

echo "==> check"
if vim -N -u "$VIMDIR/ide.vim" --cmd 'let g:ide_no_autostart=1' -c 'qa!' </dev/null >/dev/null 2>&1; then
  say "vim starts clean with the config"
else
  say "WARNING: vim reported errors loading the config"
fi

cat <<EOF

Done. Open a project:

    cd <project> && vim <file>

Set your agent with  let g:ide_agent_cmd = 'copilot'  (default) or 'claude'.
Press <Space> and wait to see the mappings. Full list in the README.
EOF
