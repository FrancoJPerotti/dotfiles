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
