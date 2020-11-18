" Some tools for Vim
" Last Change: 2020-11-18 
" Author: Kong Jun <kongjun18@outlook.com>
" Github: https://github.com/kongjun18
" License: GPL-3.0

" guard {{{
if exists('loaded_tools_vim') || &cp || version < 700
    finish
endif
let loaded_tools_vim = 1
" }}}

" tools#create_gitignore {{{
" @brief: Create .gitignore file for C/C++ 
" @note:     only impletemt c and cpp
function g:tools#create_gitignore(filetype)
    if filereadable('.gitignore')
        echomsg "This project had .gitignore"
        return 
    endif

    if a:filetype == 'c' ||  a:filetype == 'cpp'
        try 
            call system("cp ~/.config/nvim/tools/gitignore/c_gitignore " . getcwd() . "/.gitignore")
        catch *
            echomsg "Error in tools#create_gitignore()"
        endtry
    else
        echomsg "This type don't impletemted"
    endif
endfunction
" }}}

" tools#rm_gtags() {{{

" Delete gtags generated by gutentags of a:project_dir
"
" @depends asyncrun and gutentags
" 
" If gtags encounters errors, call this function to delete gtags generated by
" gutentags and run :GutentagsUpdate
"
" For example, :call tools#rm_tags(asyncun#get_root('%'))
function g:tools#rm_gtags(project_dir)
    let l:gtags_dir = a:project_dir
    if l:gtags_dir[0] != '~' && l:gtags_dir[0] != '/'
        echoerr "tools#rm_tags: argument error"
    endif
    if l:gtags_dir[0] == '~'
        let l:gtags_dir = substitute(l:gtags_dir, '~', "$HOME")
    endif
    let l:gtags_dir = substitute(l:gtags_dir, '\/', '-', 'g')
    let l:gtags_dir = substitute(l:gtags_dir, '^-', '\/', '')
    let l:gtags_dir = trim(l:gtags_dir)
    let l:gtags_dir = printf("%s%s", g:gutentags_cache_dir, l:gtags_dir)
    if delete(l:gtags_dir, 'rf') != 0
        echoerr "Can't delete tag directory " . l:gtags_dir
    endif
endfunction
" }}}

" Integrate lightline and ale {{{
function! g:LightlineLinterWarnings() abort
let l:counts = ale#statusline#Count(bufnr(''))
let l:all_errors = l:counts.error + l:counts.style_error
let l:all_non_errors = l:counts.total - l:all_errors
return l:counts.total == 0 ? '' : printf('%d ▲', all_non_errors)
endfunction

function! g:LightlineLinterErrors() abort
let l:counts = ale#statusline#Count(bufnr(''))
let l:all_errors = l:counts.error + l:counts.style_error
let l:all_non_errors = l:counts.total - l:all_errors
return l:counts.total == 0 ? '' : printf('%d ✗', all_errors)
endfunction

function! g:LightlineLinterOK() abort
let l:counts = ale#statusline#Count(bufnr(''))
let l:all_errors = l:counts.error + l:counts.style_error
let l:all_non_errors = l:counts.total - l:all_errors
return l:counts.total == 0 ? '✓' : ''
endfunction
" }}}

" scroll window {{{
"
" @para mode  0 -- up  1 -- down
"
" @complain neovim don't support win_execute(). What a pity!!!
function tools#scroll_adjacent_window(mode)
    let l:left_winnr = winnr('h')
    let l:right_winnr = winnr('l')
    let l:cur_winnr = winnr()
    if l:left_winnr <= 0 && l:right_winnr <= 0
        echomsg "Unknown error in tools#scroll_adjacent_window()"
    endif

    if l:left_winnr != l:cur_winnr && l:right_winnr != l:cur_winnr
        echomsg "More than two adjcent windows"
        return 
    endif
    
    if l:left_winnr == l:right_winnr
        echomsg "Only a single window"
        return 
    endif

    let l:go_direction = 'h'
    let l:back_direction = 'l'
    if l:right_winnr != l:cur_winnr
        let l:go_direction = 'l'
        let l:back_direction = 'h'
    endif

    " scroll up
    noautocmd silent! wincmd p
    " echomsg "winnr " . l:winnr
    if a:mode == 0 
        exec "normal! \<ESC>\<C-W>" . l:go_direction . "\<C-U>\<C_W>" . l:back_direction
    elseif a:mode == 1
        exec "normal! \<ESC>\<C-W>" . l:go_direction . "\<C-D>\<C_W>" . l:back_direction
    endif
    noautocmd silent! wincmd p
endfunction
" }}}

" Create Qt project {{{
function tools#create_qt_project(type, to)
    if a:type != "QMainWindow" && a:type != "QWidget" && a:type != "QDialog"
        echoerr "Please input correct argument"
    endif
    if !isdirectory(a:to)
        echoerr "Please input correct argument"
    endif
    call system("cp " . "$HOME/.config/nvim/tools/Qt/" . a:type . "/* " . a:to)
endfunction
" }}}

" disassembly current file {{{
"
" only impletemt C and C++
function tools#disassembly()
    let path = ''
    if &filetype == 'c'
        let path = '/tmp/' . substitute(expand('%:t'), '\.c$', '\.s', '')
        try
            call system('gcc -S ' . expand('%') . ' -o ' . path)
        catch *
            echomsg "tools#disassembly: compile error"
        endtry
    elseif &filetype == 'cpp'
        "Because symbol mangling, I disassembly from executable or object file 
        let path = '/tmp/' . substitute(expand('%:t'), '\.\(cc\|cpp\)$', '\.s', '')
        let executable = substitute(path, '\.s', '', '')
        echomsg 'path: ' . path
        echomsg 'executable: ' . executable
        silent exec '!g++ -std=c++17 ' . expand('%') . ' -o ' . executable
        echomsg 'system: ' . 'g++ -std=c++17 ' . expand('%') . ' -o ' . executable 
        if v:shell_error
            silent exec '!g++ -std=c++17 -c ' . expand('%') . ' -o ' . executable
            echomsg 'system: ' . 'g++ -std=c++17 -c ' . expand('%') . ' -o ' . executable
            if v:shell_error
                echomsg "tools#disassembly: compile error"
                return 
            endif
        endif
        silent exec '!objdump -d -C -M sufix ' . executable . ' > ' . path
        echomsg 'system: ' .'objdump -d -C -M sufix ' . executable . ' > ' . path
        if v:shell_error
            echomsg "tools#disassembly: objdump error"
            return 
        endif
    else
        echomsg &filetype . ' : not impletemted'
    endif
    echomsg 'vsp ' . path
    call execute('vsp ' . path)
    let src_window_id = win_getid(winnr('#'))
    call win_gotoid(src_window_id)
endfunction

command -nargs=0 Disassembly call tools#disassembly()
" }}}
