" Minimal settings for kitty scrollback overlay
set ft=scrollback
set readonly
set clipboard=unnamedplus

" Line numbers (force-visible)
set number relativenumber numberwidth=5
set signcolumn=yes:1
set statuscolumn=%s%=%{v:relnum?v:relnum:v:lnum}\ 

" Make the numbers pop on dim/transparent overlays
set termguicolors
hi LineNr guifg=#a0a0a0 ctermfg=7
hi CursorLineNr gui=bold guifg=#ffffff cterm=bold ctermfg=15

" Quick exit
nnoremap <silent> <C-q> :q!<CR>

" Jump to the last non-empty line so we land near the most recent output
augroup kitty_scrollback_init
  autocmd!
  autocmd VimEnter * call s:kitty_scrollback_focus()
augroup END

" Ensure yanks reach the system clipboard even in minimal scrollback sessions
if executable('kitty')
  augroup kitty_scrollback_clipboard
    autocmd!
    autocmd TextYankPost * call s:kitty_copy(v:event)
  augroup END

  function! s:kitty_copy(event) abort
    if a:event.operator !=# 'y'
      return
    endif
    let l:reg = a:event.regname ==# '' ? '"' : a:event.regname
    call system(['kitty', '+kitten', 'clipboard', '--copy'], getreg(l:reg))
  endfunction
endif

function! s:kitty_scrollback_focus() abort
  let l:lastline = line('$')
  if l:lastline <= 0
    return
  endif
  let l:target = prevnonblank(l:lastline)
  if l:target <= 0
    let l:target = l:lastline
  endif
  call cursor(l:target, 1)
  silent! normal! zz
endfunction
