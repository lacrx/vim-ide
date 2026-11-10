" ============================================================================
" Three-pane IDE in Apple's stock /usr/bin/vim. No installs, no plugins.
"   explorer (left) | editor (middle) | agent CLI (right)
" Verified on vim 9.1.1752, macOS 26.4, arm64.
" ============================================================================

set nocompatible
filetype plugin indent on
syntax on

" If vim was started in compatible mode (e.g. 'vim -u NORC' with no -N), the
" standard plugins were skipped before this file ran, and the sidebar would be
" an empty buffer instead of a directory listing. Load netrw ourselves.
if !exists('g:loaded_netrwPlugin')
  runtime! plugin/netrwPlugin.vim
endif

" --- layout mechanics (all four of these matter) ---------------------------
set splitright          " vertical splits open to the RIGHT (default puts them left)
set splitbelow
set noequalalways       " stop vim re-balancing pane widths behind your back
set hidden              " keep the agent's buffer alive when its window is closed
set autoread            " pick up files the agent rewrites on disk
set termwinscroll=20000 " agent scrollback
set notermguicolors     " Terminal.app is 256-color; truecolor would wash out
set mouse=a ttymouse=sgr
set laststatus=2 number signcolumn=no
set ignorecase smartcase incsearch hlsearch
set backspace=indent,eol,start
set wildmenu wildmode=longest:full,full
set path=.,,** suffixesadd=.py,.cs,.ts,.js,.json,.md
silent! colorscheme wim-warm   " falls back silently if ~/.vim/colors is absent
if get(g:, 'colors_name', '') !=# 'wim-warm' | silent! colorscheme habamax | endif

let g:ide_agent_cmd   = get(g:, 'ide_agent_cmd', 'copilot')
let g:ide_agent_width = get(g:, 'ide_agent_width', 62)
let g:ide_tree_width  = get(g:, 'ide_tree_width', 30)
" Three panes stay three panes. The widths shrink proportionally instead,
" so a narrow terminal costs you columns, never the sidebar.
let g:ide_min_editor = get(g:, 'ide_min_editor', 30)

" Set the *_frac values to 1.0 to force the exact widths above at any
" terminal size (e.g. a deliberately wide agent and a narrow editor).
let g:ide_agent_frac = get(g:, 'ide_agent_frac', 0.40)
let g:ide_tree_frac  = get(g:, 'ide_tree_frac',  0.18)

func! s:AgentW() abort
  return max([34, min([g:ide_agent_width, float2nr(&columns * g:ide_agent_frac)])])
endfunc
func! s:TreeW() abort
  return max([16, min([g:ide_tree_width, float2nr(&columns * g:ide_tree_frac)])])
endfunc

" Panes are only dropped when the editor genuinely cannot fit: the tree first,
" then the agent. On any normal terminal this returns 'trio'.
func! s:LayoutMode() abort
  if &columns - s:AgentW() - s:TreeW() - 2 >= g:ide_min_editor | return 'trio' | endif
  if &columns - s:AgentW() - 1 >= g:ide_min_editor | return 'duo' | endif
  return 'solo'
endfunc

" --- netrw as the left sidebar --------------------------------------------
let g:netrw_banner       = 0
let g:netrw_liststyle    = 3
let g:netrw_browse_split = 0
let g:netrw_altv         = 1
let g:netrw_fastbrowse   = 0   " re-read dirs, so agent-created files appear
let g:netrw_list_hide    = '^\.\=/\=$,^\.git/\=$,\.pyc$,\.sw[op]$,^__pycache__/\=$,^bin/\=$,^obj/\=$'
let g:netrw_hide         = 1

" ---------------------------------------------------------------------------
" Window bookkeeping. Window *numbers* shift as panes open and close, so we
" track window IDs and recompute netrw's target window on every change.
" ---------------------------------------------------------------------------
let g:ide_agent_buf = -1

" NERDTree is used when it is installed (drop it in ~/.vim/pack/ide/start/),
" otherwise everything falls back to netrw. One config, both machines.
func! s:HasNerd() abort
  return exists(':NERDTreeFind') == 2
endfunc

func! s:IsSidebar(id) abort
  let l:b = winbufnr(a:id)
  let l:ft = getbufvar(l:b, '&filetype')
  return l:ft ==# 'netrw' || l:ft ==# 'nerdtree' || isdirectory(bufname(l:b))
endfunc

func! s:EditorWinId() abort
  for l:w in range(1, winnr('$'))
    let l:id = win_getid(l:w)
    if getwinvar(l:id, '&buftype') ==# '' && !s:IsSidebar(l:id)
      return l:id
    endif
  endfor
  return 0
endfunc

" Pin netrw's file-opening target to the editor window. Without this, files
" picked in the sidebar land in whatever window netrw last remembered, which
" is how the agent pane gets clobbered.
func! IdePinEditor() abort
  let l:id = s:EditorWinId()
  let g:netrw_chgwin = l:id ? win_id2win(l:id) : -1
endfunc

func! IdeRelayout() abort
  let l:here = win_getid()
  let l:t = s:TreeWinId()
  if l:t | call win_execute(l:t, 'vertical resize ' . s:TreeW()) | endif
  let l:a = s:AgentWinId()
  if l:a | call win_execute(l:a, 'vertical resize ' . s:AgentW()) | endif
  call win_gotoid(l:here)
endfunc

augroup IdePin
  autocmd!
  autocmd WinEnter,WinNew,WinClosed,BufWinEnter * call IdePinEditor()
  autocmd VimResized * call IdeRelayout()
augroup END

" --- the agent pane -------------------------------------------------------
" Resolve the agent command to an absolute path. vim's term_start() searches
" only the PATH it inherited, which often lacks the user-local bin dirs where
" these CLIs install, so a bare name like 'copilot' fails with a bare
" "executing job failed: No such file or directory".
func! s:ResolveAgent() abort
  if type(g:ide_agent_cmd) == v:t_list | return g:ide_agent_cmd | endif
  let l:parts = split(g:ide_agent_cmd)
  if empty(l:parts) | return [] | endif
  let l:exe = exepath(l:parts[0])
  if l:exe ==# ''
    for l:d in [$HOME . '/.local/bin', '/opt/homebrew/bin', '/usr/local/bin', $HOME . '/bin']
      if executable(l:d . '/' . l:parts[0])
        let l:exe = l:d . '/' . l:parts[0]
        break
      endif
    endfor
  endif
  return l:exe ==# '' ? [] : [l:exe] + l:parts[1:]
endfunc

func! s:AgentAlive() abort
  return g:ide_agent_buf > 0 && bufexists(g:ide_agent_buf)
        \ && term_getstatus(g:ide_agent_buf) =~# 'running'
endfunc

func! s:AgentWinId() abort
  return s:AgentAlive() ? get(win_findbuf(g:ide_agent_buf), 0, 0) : 0
endfunc

func! IdeAgentOpen() abort
  let l:w = s:AgentWinId()
  if l:w | call win_gotoid(l:w) | return | endif
  botright vertical new
  execute 'vertical resize' s:AgentW()
  setlocal winfixwidth
  if s:AgentAlive()
    " reattach the SAME session (no trailing comment on an :execute line: E114)
    try
      execute 'buffer' g:ide_agent_buf
    catch
      close
      return
    endtry
  else
    let l:cmd = s:ResolveAgent()
    if empty(l:cmd)
      setlocal buftype=nofile bufhidden=wipe noswapfile
      call setline(1, ['', '  Agent not found:  ' . string(g:ide_agent_cmd), '',
            \ '  vim searched its inherited PATH plus ~/.local/bin,',
            \ '  /opt/homebrew/bin, /usr/local/bin and ~/bin.', '',
            \ '  Fix with an absolute path, e.g.', '',
            \ '    let g:ide_agent_cmd = expand("~/.local/bin/copilot")', '',
            \ '  then reopen this pane with  <Space>ac'])
      setlocal nomodifiable
      return
    endif
    let g:ide_agent_buf = term_start(l:cmd, {
          \ 'curwin': 1, 'term_name': 'AGENT', 'term_kill': 'kill' })
  endif
  setlocal nonumber signcolumn=no winfixwidth
  call IdePinEditor()
endfunc

" Closing the window leaves the job running ('hidden' + the buffer survives),
" so toggling does not restart your agent session.
func! IdeAgentToggle() abort
  let l:w = s:AgentWinId()
  if l:w
    call win_execute(l:w, 'close')
    call IdePinEditor()
  else
    call IdeAgentOpen()
  endif
endfunc

func! IdeAgentFocus() abort
  call IdeAgentOpen()
  if mode() !=# 't'
    silent! execute "normal! i"
  endif
endfunc

" --- the explorer pane ----------------------------------------------------
func! s:TreeWinId() abort
  for l:w in range(1, winnr('$'))
    let l:id = win_getid(l:w)
    if getbufvar(winbufnr(l:id), '&filetype') ==# 'nerdtree' | return l:id | endif
    if getwinvar(l:id, '&buftype') ==# '' && s:IsSidebar(l:id) | return l:id | endif
  endfor
  return 0
endfunc

func! IdeTreeToggle() abort
  let l:w = s:TreeWinId()
  if l:w
    call win_execute(l:w, 'close')
  else
    call s:EnsureTree()
    let l:t = s:TreeWinId()
    if l:t | call win_gotoid(l:t) | endif
  endif
  call IdePinEditor()
endfunc

" If the editor pane has been closed, opening a file from the sidebar makes
" the file take over the sidebar's window. Put the sidebar back and give the
" file a proper editor pane, so you end up with tree | file | agent again.
func! s:TreeStolen() abort
  if get(g:, 'ide_repairing', 0) | return | endif
  if &buftype !=# '' || &filetype ==# 'netrw' | return | endif
  if !get(w:, 'ide_is_tree', 0) | return | endif
  let w:ide_is_tree = 0
  let g:ide_repairing = 1
  try
    let l:fw = win_getid()
    call s:EnsureTree()
    call win_gotoid(l:fw)
    execute 'vertical resize'
          \ max([g:ide_min_editor, &columns - s:TreeW() - s:AgentW() - 2])
    call IdePinEditor()
  finally
    let g:ide_repairing = 0
  endtry
endfunc

augroup IdeTreeGuard
  autocmd!
  autocmd FileType netrw let w:ide_is_tree = 1
  autocmd BufWinEnter * call s:TreeStolen()
augroup END

" --- build the whole thing ------------------------------------------------
func! IdeStart(...) abort
  let l:file = a:0 && a:1 !=# '' ? a:1 : ''
  only
  if l:file !=# '' | execute 'edit' fnameescape(l:file) | else | enew | endif
  let l:mode = s:LayoutMode()
  if l:mode !=# 'solo' | call IdeAgentOpen() | endif
  if l:mode ==# 'trio' | call IdeTreeToggle() | endif
  call IdePinEditor()
  if l:file ==# ''
    call IdeAgentFocus()
  else
    call win_gotoid(s:EditorWinId())
  endif
endfunc
command! -nargs=? -complete=file Ide call IdeStart(<q-args>)

" Auto-start, but only inside a git project, and never for a git commit
" message, a piped stdin, or a multi-file argument list.
func! s:InProject() abort
  return finddir('.git', getcwd().';') !=# '' || filereadable(findfile('.git', getcwd().';'))
endfunc

func! s:AutoStart() abort
  if argc() > 1 || !s:InProject() | return | endif
  if &filetype =~# 'gitcommit\|gitrebase\|gitconfig' | return | endif
  if exists('g:ide_no_autostart') | return | endif
  let l:a = argc() == 1 ? argv(0) : ''
  if l:a !=# '' && isdirectory(l:a)
    execute 'cd' fnameescape(l:a)
    call IdeStart('')
  else
    call IdeStart(l:a)
  endif
endfunc
autocmd VimEnter * nested call s:AutoStart()

" --- send context to the agent -------------------------------------------
" Deliberately sends a PATH (and line range), never multi-line text: pasting
" many lines into a TUI input box is where bracketed-paste bugs live.
func! IdeSendPath(range_mode) abort range
  if &buftype !=# '' || expand('%') ==# ''
    echohl WarningMsg
    echomsg 'Ide: nothing to send, this is not a file buffer'
    echohl NONE
    return
  endif
  if !s:AgentAlive() | call IdeAgentOpen() | endif
  if !s:AgentAlive() | return | endif
  let l:p = fnamemodify(expand('%:p'), ':.')
  let l:t = a:range_mode ? printf('%s:%d-%d ', l:p, a:firstline, a:lastline)
        \               : printf('%s ', l:p)
  call term_sendkeys(g:ide_agent_buf, l:t)
  call IdeAgentFocus()
endfunc
nnoremap <silent> <Space>ab :call IdeSendPath(0)<CR>
xnoremap <silent> <Space>as :call IdeSendPath(1)<CR>

" --- keep the editor honest about on-disk changes ------------------------
func! s:Checktime(t) abort
  if mode() ==# 'n' && getcmdwintype() ==# '' | silent! checktime | endif
endfunc
call timer_start(1500, function('s:Checktime'), {'repeat': -1})
autocmd FocusGained,BufEnter * silent! checktime

" --- navigation -----------------------------------------------------------
let g:mapleader = ' '
nnoremap <C-h> <C-w>h
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-l> <C-w>l
" Option+h/j/k/l leave the agent pane WITHOUT stealing Ctrl-W, which the CLI
" needs for delete-word. <C-w>. sends a literal Ctrl-W through to it.
" Needs Option-as-Meta in Terminal.app: Settings > Profiles > Keyboard.
nnoremap <silent> <Space>e :call IdeTreeToggle()<CR>
nnoremap <silent> <Space>ac :call IdeAgentToggle()<CR>
nnoremap <silent> <Space>af :call IdeAgentFocus()<CR>
nnoremap <silent> <Space>w :write<CR>
func! IdeClose() abort
  if winnr('$') > 1
    close
  else
    quit
  endif
endfunc
nnoremap <silent> <Space>q :call IdeClose()<CR>
nnoremap <Space>ff :find 
nnoremap <Space>fg :grep -rn  .<Left><Left>
" NOT <Esc><Esc>: that would make every Escape wait for a second key,
" now that <M-x> is declared as ESC followed by x.
nnoremap <silent> <Space>n :nohlsearch<CR>

" ============================================================================
" Explorer parity with the snacks.nvim sidebar
" ============================================================================
" 'fuzzy' does NOT apply to :find / file-in-path completion (measured);
" it only helps command and buffer completion. 'pum' gives the popup menu.
set wildoptions=pum,fuzzy
set wildignorecase

" Declare Option-as-Meta keys properly, so <M-e> is ONE key to vim instead of
" an <Esc> that collides with real Escape in normal mode.
for s:k in ['e','a','h','j','k','l','q']
  execute "set <M-".s:k.">=\<Esc>".s:k
endfor
unlet s:k

func! s:EnsureTree() abort
  let l:w = s:TreeWinId()
  if l:w | return l:w | endif
  if s:HasNerd()
    let l:here = win_getid()
    execute 'NERDTree' fnameescape(getcwd())
    let l:t = s:TreeWinId()
    if l:t
      call win_execute(l:t, 'vertical resize ' . s:TreeW())
      call setwinvar(l:t, '&winfixwidth', 1)
    endif
    call win_gotoid(l:here)
    return l:t
  endif
  topleft vertical new
  execute 'vertical resize' s:TreeW()
  setlocal winfixwidth
  execute 'edit' fnameescape(getcwd())
  return win_getid()
endfunc

" Toggle WITHOUT moving focus, the Alt+e behaviour from the nvim setup.
func! IdeTreePeek() abort
  let l:here = win_getid()
  let l:w = s:TreeWinId()
  if l:w
    call win_execute(l:w, 'close')
  else
    call s:EnsureTree()
  endif
  call IdePinEditor()
  if win_id2win(l:here) | call win_gotoid(l:here) | endif
endfunc

" Walk the tree down to the current file, expanding each directory, which is
" the closest netrw gets to snacks' reveal-current-file.
func! s:TreeExpandTo(path) abort
  let l:rel = fnamemodify(a:path, ':.')
  if l:rel ==# a:path || l:rel ==# '' | return 0 | endif
  let l:parts = split(l:rel, '/')
  call cursor(1, 1)
  for l:i in range(len(l:parts) - 1)
    if search('\V' . escape(l:parts[l:i], '\') . '/\$', 'cW') == 0 | return 0 | endif
    execute "normal \<CR>"
  endfor
  return search('\V' . escape(l:parts[-1], '\') . '\$', 'cW') > 0
endfunc

func! IdeTreeReveal() abort
  let l:f = expand('%:p')
  if l:f ==# '' || !filereadable(l:f) | return | endif
  let l:here = win_getid()
  if s:HasNerd()
    execute 'NERDTreeFind' fnameescape(l:f)
    let l:t = s:TreeWinId()
    if l:t | call win_execute(l:t, 'vertical resize ' . s:TreeW()) | endif
    let g:ide_last_reveal = l:t ? 1 : 0
    call IdePinEditor()
    call win_gotoid(l:here)
    return
  endif
  let l:w = s:EnsureTree()
  call win_gotoid(l:w)
  let l:ok = s:TreeExpandTo(l:f)
  if !l:ok
    " fallback: root the sidebar at the file's own directory
    execute 'edit' fnameescape(fnamemodify(l:f, ':h'))
    call cursor(1, 1)
    let l:ok = search('\V' . escape(fnamemodify(l:f, ':t'), '\') . '\$', 'cW') > 0
  endif
  let g:ide_last_reveal = l:ok
  call IdePinEditor()
  call win_gotoid(l:here)
endfunc

" Path of the entry under the cursor in a netrw listing.
func! s:TreeDepth(line) abort
  return len(substitute(matchstr(a:line, '^[| ]*'), '[^|]', '', 'g'))
endfunc

" Absolute path of the entry under the cursor in a netrw listing. In tree view
" the line itself holds only the basename, so the ancestors are rebuilt from
" the indentation of the lines above. Depth 0 is the tree root, which is
" already part of w:netrw_treetop and must not be added again.
func! IdeTreeEntry() abort
  if &filetype ==# 'nerdtree'
    let l:n = g:NERDTreeFileNode.GetSelected()
    return empty(l:n) ? '' : l:n.path.str()
  endif
  let l:root = exists('w:netrw_treetop') ? w:netrw_treetop
        \ : (exists('b:netrw_curdir') ? b:netrw_curdir : getcwd())
  let l:name = expand('<cfile>')
  if l:name ==# '' | return '' | endif
  let l:depth = s:TreeDepth(getline('.'))
  if l:depth == 0 && exists('w:netrw_treetop')
        \ && l:name ==# fnamemodify(substitute(l:root, '/$', '', ''), ':t')
    return l:root
  endif
  let l:parts = [l:name]
  let l:d = l:depth
  for l:n in range(line('.') - 1, 1, -1)
    if l:d <= 1 | break | endif
    let l:dd = s:TreeDepth(getline(l:n))
    if l:dd < l:d
      call insert(l:parts, substitute(matchstr(getline(l:n), '[^| ].*$'), '/$', '', ''))
      let l:d = l:dd
    endif
  endfor
  return simplify(l:root . '/' . join(l:parts, '/'))
endfunc

func! IdeTreeSend() abort
  let l:p = IdeTreeEntry()
  if l:p ==# '' || !filereadable(l:p) | return | endif
  if !s:AgentAlive() | call IdeAgentOpen() | endif
  call term_sendkeys(g:ide_agent_buf, fnamemodify(l:p, ':.') . ' ')
  call IdeAgentFocus()
endfunc

" NERDTree opens files in the "previous window", which can be the agent pane.
" We take that decision away from it: directories expand in place, files go to
" the editor window, which is created if it is missing.
func! s:GotoEditor() abort
  let l:e = s:EditorWinId()
  if l:e | call win_gotoid(l:e) | return | endif
  let l:t = s:TreeWinId()
  if l:t
    call win_gotoid(l:t)
    rightbelow vertical new
  else
    topleft vertical new
  endif
  execute 'vertical resize'
        \ max([g:ide_min_editor, &columns - s:TreeW() - s:AgentW() - 2])
endfunc

func! s:NerdOpen() abort
  let l:n = g:NERDTreeFileNode.GetSelected()
  if empty(l:n) | return | endif
  if l:n.path.isDirectory
    call l:n.activate()
    return
  endif
  let l:p = l:n.path.str()
  call s:GotoEditor()
  execute 'edit' fnameescape(l:p)
  call IdePinEditor()
endfunc

if s:HasNerd()
  let g:NERDTreeMinimalUI       = 1
  let g:NERDTreeShowHidden      = 1
  let g:NERDTreeWinSize         = g:ide_tree_width
  let g:NERDTreeQuitOnOpen      = 0
  let g:NERDTreeAutoDeleteBuffer= 1
  let g:NERDTreeHijackNetrw     = 0
  " dotfiles stay visible (they colour as metadata); noise does not
  let g:NERDTreeIgnore = ['^\.git$', '\.pyc$', '^__pycache__$',
        \ '^node_modules$', '^\.venv$', '\.egg-info$', '^bin$', '^obj$',
        \ '\.sw[op]$', '^\.DS_Store$']
  let g:NERDTreeStatusline      = '%#StatusLine# tree'
endif

augroup IdeNerdTree
  autocmd!
  autocmd FileType nerdtree nnoremap <buffer><silent> <CR> :call <SID>NerdOpen()<CR>
  autocmd FileType nerdtree nnoremap <buffer><silent> o   :call <SID>NerdOpen()<CR>
  autocmd FileType nerdtree nnoremap <buffer><silent> <Space>as :call IdeTreeSend()<CR>
  autocmd FileType nerdtree setlocal winfixwidth nonumber
  autocmd FileType nerdtree call s:NerdExtraSyntax()
augroup END

" dotfiles read as metadata here too; matchadd for the same reason as netrw
func! s:NerdExtraSyntax() abort
  if get(w:, 'ide_nerd_matched', 0) | return | endif
  let w:ide_nerd_matched = 1
  silent! call matchadd('ideNetrwDotfile', '^[^A-Za-z0-9.]*\zs\.\w\S*', 20)
endfunc

" --- fuzzy finding -------------------------------------------------------
" ctrlp.vim when it is installed, otherwise :find, which is prefix-only
" ('wildoptions=fuzzy' does not apply to file-in-path completion; measured).
" Either way we move to the editor window first, so a pick never lands on
" the agent or replaces the sidebar.
func! s:HasCtrlP() abort
  return exists(':CtrlP') == 2
endfunc

func! IdeFind(...) abort
  let l:what = a:0 ? a:1 : 'files'
  call s:GotoEditor()
  if s:HasCtrlP()
    if     l:what ==# 'buffers' | CtrlPBuffer
    elseif l:what ==# 'recent'  | CtrlPMRU
    else                        | CtrlP
    endif
  else
    call feedkeys(l:what ==# 'buffers' ? ":buffer \<C-d>" : ':find ', 'n')
  endif
endfunc

if s:HasCtrlP()
  let g:ctrlp_map = ''
  let g:ctrlp_working_path_mode = 'ra'
  let g:ctrlp_show_hidden = 1
  let g:ctrlp_max_files = 20000
  let g:ctrlp_switch_buffer = 'et'
  let g:ctrlp_match_window = 'bottom,order:ttb,min:1,max:15,results:15'
  let g:ctrlp_custom_ignore = {
        \ 'dir':  '\v[\/](\.git|node_modules|__pycache__|\.venv|bin|obj)$',
        \ 'file': '\v\.(pyc|swp|swo|DS_Store)$' }
endif

nnoremap <silent> <Space>fb :call IdeFind('buffers')<CR>
nnoremap <silent> <Space>fr :call IdeFind('recent')<CR>

nnoremap <silent> <M-e> :call IdeTreePeek()<CR>
nnoremap <silent> <M-a> :call IdeAgentToggle()<CR>
nnoremap <silent> <Space>ef :call IdeTreeReveal()<CR>
nnoremap <silent> <Space><Space> :call IdeFind()<CR>
nnoremap <Space>fF :find 
nnoremap <M-h> <C-w>h
nnoremap <M-j> <C-w>j
nnoremap <M-k> <C-w>k
nnoremap <M-l> <C-w>l
tnoremap <M-h> <C-w>h
tnoremap <M-j> <C-w>j
tnoremap <M-k> <C-w>k
tnoremap <M-l> <C-w>l
tnoremap <M-e> <C-w>:call IdeTreePeek()<CR>
tnoremap <M-a> <C-w>:call IdeAgentToggle()<CR>
" Reach vim's own command line from inside the agent (e.g. :cd ~/repos/x).
" Escape cannot do this: the agent owns that key for its own modes.
tnoremap <M-q> <C-w>:
" netrw has no highlight group for dotfiles. A :syntax match loses here,
" because netrw re-applies its own syntax every time it redraws the listing.
" matchadd() is window-local and paints over syntax, so it survives redraws.
func! s:NetrwExtraSyntax() abort
  if get(w:, 'ide_netrw_matched', 0) | return | endif
  let w:ide_netrw_matched = 1
  silent! call matchadd('ideNetrwDotfile', '^[| ]*\zs\.\w\S*', 20)
  silent! call matchadd('ideNetrwUp', '^\.\.\/', 20)
endfunc

augroup IdeNetrwKeys
  autocmd!
  autocmd FileType netrw nnoremap <buffer><silent> <Space>as :call IdeTreeSend()<CR>
  autocmd FileType netrw setlocal winfixwidth nonumber
  autocmd FileType netrw call s:NetrwExtraSyntax()
  autocmd BufWinEnter * if &filetype ==# 'netrw' | call s:NetrwExtraSyntax() | endif
augroup END
