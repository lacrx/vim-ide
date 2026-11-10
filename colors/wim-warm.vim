" wim-warm: the warm 256-colour palette sampled from wolandark's 2022 screenshot.
" Every value below is an exact xterm-256 index, so this renders identically in
" Terminal.app, which has no truecolor. Do NOT set termguicolors with this.
set background=dark
highlight clear
if exists('syntax_on') | syntax reset | endif
let g:colors_name = 'wim-warm'
set notermguicolors t_Co=256

" measured: bg 235 #262626 | fg 223 #ffd7af | orange 215 #ffaf5f | green 108
" #87af87 | salmon 167 #d75f5f | aqua 73 #5fafaf | sky 109 #87afaf | slate 60
" #5f5f87 | olive 143 #afaf5f | amber 136 #af8700 | hot orange 208 #ff8700
let s:p = {
      \ 'bg':235,'fg':223,'orange':215,'hot':208,'green':108,'salmon':167,
      \ 'aqua':73,'sky':109,'slate':60,'olive':143,'amber':136,
      \ 'grey':239,'dim':59,'soft':245,'ink':232,'blue':110 }

func! s:hi(group, fg, bg, attr) abort
  let l:c = 'highlight ' . a:group
  let l:c .= a:fg ==# '' ? '' : ' ctermfg=' . s:p[a:fg]
  let l:c .= a:bg ==# '' ? ' ctermbg=NONE' : ' ctermbg=' . s:p[a:bg]
  let l:c .= ' cterm=' . (a:attr ==# '' ? 'NONE' : a:attr)
  execute l:c
endfunc

call s:hi('Normal',       'fg',     'bg', '')
call s:hi('Comment',      'salmon', '',   '')
call s:hi('Constant',     'fg',     '',   '')
call s:hi('String',       'green',  '',   '')
call s:hi('Character',    'green',  '',   '')
call s:hi('Number',       'olive',  '',   '')
call s:hi('Boolean',      'olive',  '',   '')
call s:hi('Identifier',   'sky',    '',   '')
call s:hi('Function',     'aqua',   '',   '')
call s:hi('Statement',    'orange', '',   '')
call s:hi('Conditional',  'orange', '',   '')
call s:hi('Repeat',       'orange', '',   '')
call s:hi('Operator',     'hot',    '',   '')
call s:hi('Keyword',      'orange', '',   '')
call s:hi('PreProc',      'amber',  '',   '')
call s:hi('Type',         'aqua',   '',   '')
call s:hi('Special',      'slate',  '',   '')
call s:hi('SpecialKey',   'slate',  '',   '')
call s:hi('Underlined',   'sky',    '',   'underline')
call s:hi('Todo',         'ink',    'olive', 'bold')
call s:hi('Error',        'fg',     'salmon', '')
call s:hi('ErrorMsg',     'fg',     'salmon', '')
call s:hi('WarningMsg',   'orange', '',   '')

call s:hi('LineNr',       'dim',    '',   '')
call s:hi('CursorLineNr', 'orange', '',   'bold')
call s:hi('CursorLine',   '',       'grey', '')
call s:hi('CursorColumn', '',       'grey', '')
call s:hi('ColorColumn',  '',       'grey', '')
call s:hi('Visual',       '',       'grey', '')
call s:hi('Search',       'ink',    'olive', '')
call s:hi('IncSearch',    'ink',    'orange', '')
call s:hi('MatchParen',   'hot',    'grey', 'bold')
call s:hi('Folded',       'soft',   'grey', '')
call s:hi('FoldColumn',   'dim',    '',   '')
call s:hi('SignColumn',   'dim',    '',   '')
call s:hi('NonText',      'dim',    '',   '')
call s:hi('EndOfBuffer',  'dim',    '',   '')
call s:hi('Directory',    'orange', '',   '')
call s:hi('Title',        'orange', '',   'bold')
call s:hi('Question',     'green',  '',   '')
call s:hi('MoreMsg',      'green',  '',   '')
call s:hi('ModeMsg',      'orange', '',   'bold')

" the yellow path bar from the screenshot
call s:hi('StatusLine',   'ink',    'olive', '')
call s:hi('StatusLineNC', 'soft',   'grey',  '')
call s:hi('StatusLineTerm',   'ink',  'olive', '')
call s:hi('StatusLineTermNC', 'soft', 'grey',  '')
call s:hi('VertSplit',    'grey',   '',   '')
call s:hi('TabLine',      'soft',   'grey', '')
call s:hi('TabLineSel',   'ink',    'olive', '')
call s:hi('TabLineFill',  '',       'grey', '')
call s:hi('WildMenu',     'ink',    'orange', '')
call s:hi('Pmenu',        'fg',     'grey', '')
call s:hi('PmenuSel',     'ink',    'orange', '')
call s:hi('PmenuSbar',    '',       'grey', '')
call s:hi('PmenuThumb',   '',       'soft', '')
call s:hi('DiffAdd',      'green',  '',   '')
call s:hi('DiffChange',   'amber',  '',   '')
call s:hi('DiffDelete',   'salmon', '',   '')
call s:hi('DiffText',     'ink',    'olive', '')
" --- file tree -------------------------------------------------------------
" Same intention as the code pane: orange = structure (like Statement),
" salmon = metadata you skim past (like Comment), slate = scaffolding (like
" line continuations), green = literal/executable content (like String).
call s:hi('netrwDir',          'orange', '', 'bold')   " directories: structure
call s:hi('netrwTreeBar',      'slate',  '', '')       " the | guides: scaffolding
call s:hi('netrwTreeBarSpace', 'slate',  '', '')
call s:hi('netrwClassify',     'slate',  '', '')       " the trailing / and *
call s:hi('netrwExe',          'green',  '', '')       " executables: content
call s:hi('netrwSymLink',      'aqua',   '', '')
call s:hi('netrwLink',         'aqua',   '', '')
call s:hi('netrwPlain',        'blue',   '', '')       " ordinary files
call s:hi('netrwSpecial',      'amber',  '', '')
" dotfiles and config: metadata, so they read like comments
call s:hi('ideNetrwDotfile',   'salmon', '', '')
call s:hi('ideNetrwUp',        'blue',   '', '')

" --- NERDTree, same intention as netrw above -------------------------------
call s:hi('NERDTreeDir',       'orange', '', 'bold')
call s:hi('NERDTreeDirSlash',  'slate',  '', '')
call s:hi('NERDTreeOpenable',  'slate',  '', '')
call s:hi('NERDTreeClosable',  'slate',  '', '')
call s:hi('NERDTreeFile',      'blue',   '', '')
call s:hi('NERDTreeExecFile',  'green',  '', '')
call s:hi('NERDTreeLinkFile',  'aqua',   '', '')
call s:hi('NERDTreeLinkTarget','aqua',   '', '')
call s:hi('NERDTreeCWD',       'olive',  '', 'bold')
call s:hi('NERDTreeUp',        'blue',   '', '')
call s:hi('NERDTreeHelp',      'salmon', '', '')
call s:hi('NERDTreeFlags',     'amber',  '', '')

" --- ctrlp -----------------------------------------------------------------
call s:hi('CtrlPMatch',    'orange', '',      'bold')
call s:hi('CtrlPLinePre',  'slate',  '',      '')
call s:hi('CtrlPPrtBase',  'slate',  '',      '')
call s:hi('CtrlPPrtText',  'fg',     '',      '')
call s:hi('CtrlPPrtCursor','ink',    'orange','')
call s:hi('CtrlPMode1',    'ink',    'olive', '')
call s:hi('CtrlPMode2',    'ink',    'olive', '')
call s:hi('CtrlPStats',    'soft',   'grey',  '')
call s:hi('CtrlPNoEntries','salmon', '',      '')
delfunc s:hi
