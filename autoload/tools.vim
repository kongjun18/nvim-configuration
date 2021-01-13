" Some tools for Vim
" Last Change: 2021-01-13
" Author: Kong Jun <kongjun18@outlook.com>
" Github: https://github.com/kongjun18
" License: GPL-3.0

" guard {{{
if exists('g:loaded_tools_vim') || &cp || version < 700
    finish
endif
let g:loaded_tools_vim = 1

" }}}

" create_gitignore() -- Create gitignore template {{{
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

" rm_gtags() -- Delete gtags cache {{{

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

" scroll_adjacent_window() -- Scroll adjcent window without change focus {{{
"
" @para dir  0 -- up  1 -- down
" @para mode 'i' -- insert 'n' -- normal
"
" @complain neovim don't support win_execute(). What a pity!!!
function tools#scroll_adjacent_window(dir, mode)
    function! s:switch_to_insert(old_cursor, tail_cursor) abort
        if a:old_cursor == a:tail_cursor - 1
            noautocmd wincmd p
            startinsert!
        else
            noautocmd wincmd p
            exec 'normal l'
            noautocmd wincmd p
            startinsert
            noautocmd wincmd p
        endif
    endfunction

    let left_winnr = winnr('h')
    let right_winnr = winnr('l')
    let cur_winnr = winnr()
    let old_cursor = col(".")
    let tail_cursor = col("$")
    if left_winnr <= 0 && right_winnr <= 0
        echomsg "Unknown error in tools#scroll_adjacent_window()"
        if a:mode == 'i'
            call s:switch_to_insert(old_cursor, tail_cursor)
        endif
        return
    endif

    " only one window?
    if left_winnr == right_winnr
        echomsg "Only a single window"
        if a:mode == 'i'
            call s:switch_to_insert(old_cursor, tail_cursor)
        endif
        return
    endif

    let win_num = tabpagewinnr(tabpagenr(), '$')
    if  win_num != 2 && !(win_num == 3 && getqflist({'winid': 0}).winid != 0)
        echomsg "More than two adjcent windows"
        if a:mode == 'i'
            call s:switch_to_insert(old_cursor, tail_cursor)
        endif
        return
    endif

    let go_direction = 'h'
    let back_direction = 'l'
    if right_winnr != cur_winnr
        let go_direction = 'l'
        let back_direction = 'h'
    endif

    noautocmd silent! wincmd p
    if a:dir == 0
        exec "normal! \<ESC>\<C-W>" . go_direction . "\<C-U>\<C_W>" . back_direction
    elseif a:dir == 1
        exec "normal! \<ESC>\<C-W>" . go_direction . "\<C-D>\<C_W>" . back_direction
    endif
    " scroll in insert mode?
    if a:mode == 'i'
        call s:switch_to_insert(old_cursor, tail_cursor)
    else
        noautocmd wincmd p
    endif
endfunction
" }}}

" scroll_quickfix() -- Scroll quickfix without change focus {{{
"
" @para dir  0 -- up  1 -- down
" @para mode 'i' -- insert 'n' -- normal
"
function tools#scroll_quickfix(dir, mode)
    let current_winid = win_getid()
    let quickfix_winid = getqflist({'winid': 0}).winid
    if quickfix_winid == 0
        echomsg "There is no quickfix window"
        return
    endif
    " scroll
    call win_gotoid(quickfix_winid)
    if a:dir == 0
        exec "normal! \<C-U>"
    elseif a:dir == 1
        exec "normal! \<C-D>"
    endif
    call win_gotoid(current_winid)
    if a:mode == 'i'
        exec "normal! l"
        startinsert
    endif

endfunction

" " }}}

" ensure_dir_exist() -- Ensure directory exists {{{
" if @dir exists, just exit.
" if @dir not exists, create it
function! tools#ensure_dir_exist(dir)
    if !isdirectory(a:dir)
        call mkdir(a:dir, 'p')
    endif
endfunction
"}}}

" create_qt_project() -- Create Qt project {{{
function tools#create_qt_project(type, to)
    if a:type != "QMainWindow" && a:type != "QWidget" && a:type != "QDialog"
        echoerr "Please input correct argument"
    endif
    if !isdirectory(a:to)
        echoerr "Please input correct argument"
    endif
    call system("cp " . "$HOME/.config/nvim/tools/Qt/" . a:type . "/* " . a:to)
    call writefile("", ".root");
    silent !cmake -S. -B_builds
    call system("ln -s _builds/compile_commands.json .")
    if !v:shell_error
        echomsg "create_qt_project(): successfull"
    else
        echomsg "create_qt_project(): failed to copy templates"
    endif
endfunction
" }}}

" disassembly() -- Disassembly current file {{{
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
        " echomsg 'path: ' . path
        " echomsg 'executable: ' . executable
        silent exec '!g++ -std=c++17 ' . expand('%') . ' -o ' . executable
        " echomsg 'system: ' . 'g++ -std=c++17 ' . expand('%') . ' -o ' . executable
        if v:shell_error
            silent exec '!g++ -std=c++17 -c ' . expand('%') . ' -o ' . executable
            " echomsg 'system: ' . 'g++ -std=c++17 -c ' . expand('%') . ' -o ' . executable
            if v:shell_error
                echomsg "tools#disassembly: compile error"
                return
            endif
        endif
        silent exec '!objdump -d -C -M sufix ' . executable . ' > ' . path
        " echomsg 'system: ' .'objdump -d -C -M sufix ' . executable . ' > ' . path
        if v:shell_error
            echomsg "tools#disassembly: objdump error"
            return
        endif
    else
        echomsg &filetype . ' : not impletemted'
    endif

    " echomsg 'vsp ' . path
    if !bufexists(path) || bufexists(path) && empty(getbufinfo(path)[0].windows)
        call execute('vsp ' . path)
        " set autoread
        " when we disassembly again, the buffer will change automatically
        call setbufvar(path, '&autoread', 1)
        let src_window_id = win_getid(winnr('#'))
        call win_gotoid(src_window_id)
    else
        if !bufloaded(path)
            call bufload(path)
        endif
    endif
endfunction

command -nargs=0 Disassembly call tools#disassembly()
" }}}

" nvim_is_latest() -- Determine whether neovim is lastest {{{
"
" This function is hard-coded. Only check neovim is whether 0.5.0 or not because neovim installed in different ways has
" different version output.
"
" I write this function to determine whether install nvim-treesitter which
" requires lastest neovim or not.
"
function! tools#nvim_is_latest()
    if !has('nvim')
        return 0
    endif
    redir => l:s
    silent! version
    redir END
    let l:version_message =  matchstr(l:s, 'NVIM v\zs[^\n]*')
    let l:nvim_version = matchstr(l:version_message, '\d\.\d\.\d')
    let l:nvim_version_list = split(l:nvim_version, '\.')
    if l:nvim_version_list[0] != 0
        return 0
    elseif l:nvim_version_list[1] < 5
        return 0
        " Because lastest version is 0.5.0, so don't need check last number.
    endif

    return 1
endfunction
"}}}

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

" Debug gutentags {{{
function tools#debug_gutentgs()
    let g:gutentags_define_advanced_commands = 1
    let g:gutentags_trace = 1
endfunction

function tools#undebug_gutentags()
    let g:gutentags_define_advanced_commands = 0
    let g:gutentags_trace = 0
endfunction
" }}}

" Use static tag system {{{
function tools#use_static_tag() abort
    nnoremap <silent> gs :GscopeFind s <C-R><C-W><cr>:cnext<CR>zz
    nnoremap <silent> gd :GscopeFind g <C-R><C-W><cr>:cnext<CR>zz
endfunction
"}}}

" Plugin operations {{{
function tools#plugin_clean()
	let unused_plugin_dir = dein#check_clean()
	if len(unused_plugin_dir) == 0
		echomsg "There is no unused plugin"
		return
	endif
	for dir in unused_plugin_dir
		try
			call delete(dir, 'rf')
		catch /.*/
			echoerr "remove unused plugin directory failed"
		endtry
		echomsg "removed unused plugin directory"
	endfor
endfunction

function tools#plugin_recache()
	try
		call dein#clear_state()
		call dein#recache_runtimepath()
	catch /.*/
		echoerr "Error in tools#PluginRecache"
	endtry
endfunction

function tools#plugin_reinstall(list)
    if type(a:list) == type([])
        call call('dein#reinstall', a:list)
    endif
endfunction
"}}}
