let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" make_menu()
"-------------------------------------------------------
function! s:make_menu(mid) abort
	let menu = []

	if a:mid == 'MAIN'
		call add(menu, " Search pattern    ".s:GR.search_pattern)
		call add(menu, " Directory         ".s:GR.start_dir[0])
		call add(menu, " Filter            ".s:GR.filter)
		call add(menu, printf(" Word search       %s", and(s:GR.option, 0x01) ? "on" : "off"))
		call add(menu, printf(" Case-sensitive    %s", and(s:GR.option, 0x02) ? "on" : "off"))
		let s:short_cut_key = 'sdfwc'

		if g:Gr_Grep_Proc == 'ripgrep'
			call add(menu, printf(" Regexp(.*foo)     %s", and(s:GR.option, 0x04) ? "on" : "off"))
			call add(menu, printf(" Encording         %s", and(s:GR.option, 0x08) ? "sijs" : "utf8"))
			let s:short_cut_key .= 're'
		endif

	elseif a:mid == 'DIR'
		let s:short_cut_key = 'c'
		let menu = map(copy(s:GR.start_dir), '" ".v:val')
		call insert(menu, " [ current directory ]", 0)
	endif

	return menu
endfunction

"-------------------------------------------------------
" input_search_pattern()
"-------------------------------------------------------
function! s:input_search_pattern() abort
	let instr = input('Search for pattern: ')
	echo "\r"
	let s:GR.search_pattern = empty(instr) ?
			\ s:GR.search_pattern :
   			\ escape(instr, '^$.*[]/~\')
endfunction

"-------------------------------------------------------
" input_file_filter()
"-------------------------------------------------------
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:GR.filter = empty(instr) ? '*' : instr
endfunction

"-------------------------------------------------------
" input_start_dir()
"-------------------------------------------------------
function! s:input_start_dir(mode, idx) abort
	if a:mode == "current"
		let dir = input('Start searching from directory: ', expand('%:p:h'), 'dir')
	else
		let dir = input('Start searching from directory: ', s:GR.start_dir[a:idx], 'dir')
	endif
	echo "\r"

	if empty(dir) | return 0 | endif
	let dir = substitute(dir, has('unix') ? "/$" : "\$", "", "")

	if isdirectory(dir)
		let temp = fnamemodify(dir, ':p:h')
		call remove(s:GR.start_dir, index(s:GR.start_dir, temp))
		call insert(s:GR.start_dir, temp, 0)
		return 1
	else
		echohl WarningMsg | echomsg 'Error: Directory ' . dir. " doesn't exist" | echohl None
		return 0
	endif
endfunction

"-------------------------------------------------------
" set_grep_option()
"-------------------------------------------------------
function! s:set_grep_option(opt) abort
	let val = {'w':0x01, 'c':0x02, 'r':0x04, 'e':0x08}
	let lno = {'w':4, 'c':5, 'r':6, 'e':7}
	let s:GR.option = xor(s:GR.option, val[a:opt])
endfunction

"-------------------------------------------------------
" make_grep_cmd_rg()
"-------------------------------------------------------
function! s:make_grep_cmd_rg() abort
	let opt = ''
	"Word Search
	let opt .= and(s:GR.option, 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:GR.option, 0x2) ? 'i' : ''
	"Disable Regular expressions
	let opt .= and(s:GR.option, 0x4) ? 'F' : ''
	if strlen(opt)
		let opt = '-'.opt
	endif
	" Encording(sjis/utf-8)
	let opt .= and(s:GR.option, 0x8) ? ' -E sjis' : ' -E utf8'

	let cmd = 'grep! '.opt.' -g *.{'.s:GR.filter.'} "'.s:GR.search_pattern. '" '.s:GR.start_dir[0]

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_vim()
"-------------------------------------------------------
function! s:make_grep_cmd_vim() abort
	let cmd = 'vimgrep! '
	"Word Search
	let cmd .= and(s:GR.option, 0x1) ? '/\<'.s:GR.search_pattern : '/'.s:GR.search_pattern
	"Case-senstive
	let cmd .= and(s:GR.option, 0x2) ? '\C' : '\c'
	"Word Search
	let cmd .= and(s:GR.option, 0x1) ? '\>/j ' : '/j '
	"Start search directory
	let cmd .= s:GR.start_dir[0]
	"File filter
	let cmd .= '/**/*.'.substitute(s:GR.filter, ",", " **/*.", "g")

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_grep()
"-------------------------------------------------------
function! s:make_grep_cmd_grep() abort
	let opt = ''
	"Word Search
	let opt .= and(s:GR.option, 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:GR.option, 0x2) ? 'i' : ''

	"Filter
	if stridx(s:GR.filter, ',') >= 0
		let filter = "--include={*.".substitute(s:GR.filter, ",", ",*.", "g")."}"
	elseif  s:GR.filter != '*'
		let filter = "--include=*.".s:GR.filter
	else
		let filter = ""
	endif

	let cmd = printf('grep! -r%s %s %s %s', opt, s:GR.search_pattern, s:GR.start_dir[0], filter)

	return cmd
endfunction

"-------------------------------------------------------
" run_grep()
"-------------------------------------------------------
function! s:run_grep() abort
	if empty(s:GR.search_pattern) | return 1 | endif

	" Save search option, Filter and directory
	let g:GR = copy(s:GR)

	" Close the QuickFix. and Move latest quickfix
	cclose
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" Run grep
	if g:Gr_Grep_Proc == 'ripgrep'
		let cmd = s:make_grep_cmd_rg()
	elseif g:Gr_Grep_Proc == 'grep'
		let cmd = s:make_grep_cmd_grep()
	else
		let cmd = s:make_grep_cmd_vim()
	endif
	silent! execute cmd

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if len(getqflist())
		exe 'botright copen'
		redraw!
		set modifiable
		set nowrap
	else
		redraw!
		echo "Search pattern not found"
	endif
endfunction

"-------------------------------------------------------
" create_popup()
"-------------------------------------------------------
function! s:create_popup(mid) abort
	let menu = s:make_menu(a:mid)
	let handler = a:mid == "MAIN" ?
		\ "s:main_menu_selected_handler" :
		\ "s:dir_menu_selected_handler"

    const winid = popup_create(menu, {
            \ 'border': [1,1,1,1],
	        \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
            \ 'cursorline': 1,
            \ 'wrap': v:false,
            \ 'mapping': v:false,
            \ 'title': ' '.g:Gr_Grep_Proc.' ',
            \ 'callback': handler,
            \ 'filter': 'Gr_popup_menu_filter',
            \ 'filtermode': 'n'
            \ })
    call popup_filter_menu(winid,'k')

	let s:current_mid = a:mid
endfunction

"-------------------------------------------------------
" Gr_popup_menu_filter()
"-------------------------------------------------------
function! Gr_popup_menu_filter(winid, key) abort
	" ---------------------------
	"  When pressed 'l' key
	" ---------------------------
	if a:key == 'l'
		call win_execute(a:winid, 'let w:lnum = line(".")')
		let index = getwinvar(a:winid, 'lnum', 0)
		call popup_close(a:winid, index)
		return 1
	endif

	" ---------------------------
	"  When pressed 'h' key
	" ---------------------------
	if a:key == 'h' && s:current_mid == "DIR"
		call popup_close(a:winid, -10)
		return 1
	endif

	" ---------------------------
	"  When pressed 'q' key
	" ---------------------------
	if a:key == 'q'
		call popup_close(a:winid, -11)
		return 1
	endif

	" ---------------------------
	"  When pressed shortcut key
	" ---------------------------
	let index = stridx(s:short_cut_key, a:key)
	if index >= 0
		call popup_close(a:winid, index + 1)
		return 1
	endif

	" ---------------------------
	"  press 'g' at MAIN
	" ---------------------------
	if a:key == 'g' && s:current_mid == "MAIN"
		call popup_close(a:winid, 0x8000)
		return 1
	endif

	" ---------------------------
	"  press 'e' at DIR
	" ---------------------------
	if a:key == 'e' && s:current_mid == "DIR"
		call win_execute(a:winid, 'let w:lnum = line(".")')
		let edit_no = getwinvar(a:winid, 'lnum', 0)
		let index = or(0x80, edit_no)
		call popup_close(a:winid, index)
		return 1
	endif

	" --------------------------------
	"  Other, pass to normal filter
	" --------------------------------
	return popup_filter_menu(a:winid, a:key)
endfunction

"-------------------------------------------------------
" main_menu_selected_handler()
"-------------------------------------------------------
function! s:main_menu_selected_handler(winid, result) abort
	if a:result == 0x8000	 " Run grep
		call s:run_grep()

	elseif a:result == 1	 " Search pattern
		call s:input_search_pattern()
		call s:create_popup('MAIN')

	elseif a:result == 2	 " Start searching from directory
		call s:create_popup("DIR")

	elseif a:result == 3	 " file filter
		call s:input_file_filter()
		call s:create_popup('MAIN')

	elseif a:result == 4	 " Search option (Word Search)
		call s:set_grep_option('w')
		call s:create_popup('MAIN')

	elseif a:result == 5	" Search option (Case-senstive)
		call s:set_grep_option('c')
		call s:create_popup('MAIN')

	elseif a:result == 6	" Regular expressions
		call s:set_grep_option('r')
		call s:create_popup('MAIN')

	elseif a:result == 7	" Encording
		call s:set_grep_option('e')
		call s:create_popup('MAIN')
	endif
endfunction

"-------------------------------------------------------
" dir_menu_selected_handler()
"-------------------------------------------------------
function! s:dir_menu_selected_handler(winid, result) abort
	if a:result == 1
		let ret = s:input_start_dir("current", 0)
		call s:create_popup(ret ? "MAIN" : "DIR")

	elseif a:result >= 2 && a:result <= 6
		let temp = s:GR.start_dir[a:result - 2]
		call remove(s:GR.start_dir, a:result - 2)
		call insert(s:GR.start_dir, temp, 0)
		call s:create_popup("MAIN")

	elseif a:result >= 0x82 && a:result <= 0x86
		let ret = s:input_start_dir("edit", and(a:result, 0x7F) - 2)
		call s:create_popup(ret ? "MAIN" : "DIR")

	elseif a:result == -10
		call s:create_popup("MAIN")
	endif
endfunction

"-------------------------------------------------------
" Gr()
"-------------------------------------------------------
function! gr#Gr(range, line1, line2) abort
	let s:GR = copy(g:GR)
	if a:range
		let temp = @@
		silent normal gvy
		let search_pattern = @@
		let @@ = temp
	else
		let search_pattern = expand('<cword>')
	endif
	let s:GR.search_pattern = escape(search_pattern, '^$.*[]/~\')

	call s:create_popup("MAIN")
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
