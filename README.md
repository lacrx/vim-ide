# vim-ide

A three-pane IDE in **stock vim**: file tree on the left, editor in the middle, an AI agent CLI
on the right. No Homebrew, no package manager, no Node, no plugins required.

```
┌───────────┬──────────────────────┬────────────────────┐
│ ▸ src/    │ def parse(s):        │ ❯ refactor parse() │
│ ▸ tests/  │     return s.split() │                    │
│   .env    │                      │ ● working…         │
│   README  │                      │                    │
└───────────┴──────────────────────┴────────────────────┘
   NERDTree         your buffer        Copilot CLI
   or netrw                            or Claude Code
```

Built for a locked-down macOS machine where you cannot install tmux, Neovim or Homebrew, but
Apple's own `/usr/bin/vim` is right there and nobody thinks to block it.

```bash
git clone https://github.com/lacrx/vim-ide.git && cd vim-ide && ./install.sh
```

---

## Why this works where other setups don't

**Vim is already a terminal multiplexer.** Apple ships `/usr/bin/vim` 9.1 built with `+terminal
+job +channel +mouse_sgr +packages +popupwin`. You do not need tmux; vim does the splitting and
runs the agent in a real pty. It is part of the OS and signed by Apple, so an executable
allowlist has nothing to object to. (`/usr/bin/screen` is still 4.00.03 from 2006, which predates
vertical splits, so it is not an alternative.)

**GitHub Copilot CLI no longer needs Node.** The official installer fetches a checksum-verified
standalone binary into `$HOME/.local/bin` for a non-root user:

```bash
curl -fsSL https://gh.io/copilot-install | bash
```

**Vim plugins are plain text.** The optional NERDTree and ctrlp tiers are 36 `.vim` files between
them with nothing compiled, so they install by unzipping into `~/.vim/pack/ide/start/`. No
package manager, no git required.

## Requirements

- vim 8.1+ with `+terminal` (check with `vim --version | grep terminal`). Developed against 9.1.
- An agent CLI on your PATH: [Copilot CLI](https://github.com/github/copilot-cli) or
  [Claude Code](https://www.anthropic.com/claude-code). Everything except the right-hand pane
  works without one.
- A 256-colour terminal. Do **not** enable `termguicolors`; see [Colours](#colours).

## Install

`./install.sh` is idempotent and never deletes anything:

1. installs `ide.vim` and the colourscheme into `~/.vim/`, moving any existing `ide.vim` aside
   with a timestamp
2. unzips NERDTree and ctrlp into `~/.vim/pack/ide/start/` (set `SKIP_PLUGINS=1` to omit; the
   config falls back to netrw and `:find`)
3. appends a guarded `source` block to `~/.vimrc`, after backing it up (`NO_VIMRC=1` to skip)
4. checks that vim starts clean

Then pick your agent in `~/.vimrc`:

```vim
let g:ide_agent_cmd = 'copilot'   " or 'claude'
```

## Day 1: the keys you need

Leader is **Space**. `Alt` needs Option-as-Meta (Terminal.app: Settings → Profiles → Keyboard →
"Use Option as Meta Key"). Every `Alt` binding has a `Ctrl-W` equivalent if your terminal will
not deliver Meta.

| Coming from an IDE | Here |
|---|---|
| Ctrl+P (open file) | `<Space><Space>` |
| Ctrl+Shift+E (file tree) | `<Space>e`, or `Alt+e` to toggle it **without losing your place** |
| Reveal current file in tree | `<Space>ef` |
| Find in project | `<Space>fg` |
| Open buffers / recent | `<Space>fb` / `<Space>fr` |
| Save / close pane | `<Space>w` / `<Space>q` |

### The agent pane

| Keys | What |
|---|---|
| `<Space>ac` | Toggle the agent. **The session keeps running while hidden** |
| `<Space>af` | Focus it and start typing |
| `<Space>ab` | Send the current file's path |
| visual `<Space>as` | Send `path:first-last` |
| `<Space>as` in the tree | Send the file under the cursor |
| `Alt+q` (or `Ctrl-W :`) | Reach vim's command line from inside the agent, e.g. `:cd ~/other` |
| `Alt+h/j/k/l` (or `Ctrl-W h/j/k/l`) | Leave the agent pane |
| `Ctrl-W .` | Send a literal `Ctrl-W` to the CLI, which it uses for delete-word |

Context is sent as **paths and line ranges**, never as pasted text. Pasting many lines into a
TUI input box is where bracketed-paste bugs live, and every one of these agents can read a file
itself.

## Five things that are not obvious

Each of these was a bug first.

- **`set splitright`.** Without it a vertical split puts the agent in the *middle*.
- **`set noequalalways` + `winfixwidth`.** Otherwise vim re-balances the panes behind your back
  and a 62-column agent becomes 31.
- **`set hidden`.** This is what keeps the agent's job alive when its window is closed, so
  toggling the pane does not restart your conversation.
- **The sidebar must not be allowed to open files wherever it likes.** netrw remembers a target
  window and NERDTree opens in the "previous window", and either can be your agent. `ide.vim`
  pins the target to the editor pane and creates one if it is missing.
- **Resolve the agent binary yourself.** `term_start()` searches only the PATH vim inherited,
  which often lacks `~/.local/bin` where these CLIs install, and fails with a bare
  `executing job failed: No such file or directory`.

## Colours

`wim-warm` is a 256-colour scheme, sampled pixel by pixel from a screenshot of
[wolandark/wim](https://github.com/wolandark/wim). Every value is an exact xterm-256 index, so it
renders identically in terminals with no truecolor, macOS Terminal.app among them. Leave
`termguicolors` off.

The file tree reuses the code pane's logic rather than being decorative: directories are orange
like `Statement` (structure), dotfiles salmon like `Comment` (metadata), tree guides and slashes
slate like `Special` (scaffolding), ordinary files blue, executables green like `String`. So
scanning the tree uses the same visual grammar as scanning code.

Use any other 256-colour scheme by setting `colorscheme` after sourcing `ide.vim`.

## What this does not do

No LSP, so no go-to-definition, no rename, no hover, and no completion. Stock vim has no LSP
client and closing that gap means real plugins. No git signs, no format-on-save, no diff
accept/reject with the agent. The agent edits files on disk and `autoread` picks them up.

If you want those, you want Neovim, and this repo is not for you. This is for the machine where
you cannot have Neovim.

## Verified

vim 9.1.1752, macOS 26.4, arm64.

- A React/Ink agent TUI renders correctly at 62 and at 40 columns, reflows on live resize, and
  never touches the alternate screen, so scrollback stays usable.
- Hiding and restoring the agent pane reuses the same buffer and the same session.
- Opening a file from the tree or the fuzzy picker lands in the editor pane with the agent
  untouched, from any starting window.
- Pane widths scale with the terminal: 103 columns gives 18 | 42 | 41, 180 gives 30 | 86 | 62,
  and `VimResized` re-applies them live.
- Vim's terminal **reduces** redraw traffic rather than amplifying it: a program that painted 92
  full frames reached the outer terminal as 40 small cursor-positioned updates, 3.4x fewer bytes
  than the program emitted.
- Startup cost over bare vim: about 35 ms for both plugins, about 7 ms for this config.

Tested with Claude Code as the agent. Copilot CLI uses the same TUI conventions but has not been
exercised end to end.

## Licence

MIT.
