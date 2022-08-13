let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" make_menu()
"-------------------------------------------------------
function! s:make_menu(mid) abort
	let menu = []

	if a:mid == 'MAIN'
		call add(menu, " Search pattern:   ".s:grPattern)
		call add(menu, " Directory:        ".s:grStrDir[0])
		call add(menu, " Filter:           ".s:grFilter)
		call add(menu, printf(" Word search:      %s", and(s:grOption, 0x01) ? "on" : "off"))
		call add(menu, printf(" Case-sensitive:   %s", and(s:grOption, 0x02) ? "on" : "off"))
		let s:short_cut_key = 'sdfwc'

		if g:Gr_Grep_Proc == 'rg'
			call add(menu, printf(" Regexp(.*foo):    %s", and(s:grOption, 0x04) ? "on" : "off"))
			call add(menu, printf(" Encord:           %s", and(s:grOption, 0x08) ? "sijs" : "utf8"))
			let s:short_cut_key .= 're'
		endif

	elseif a:mid == 'DIR'
		let menu = copy(s:grStrDir)
		call map(menu, '" ".v:val')
    	call add(menu, " < current directory >")
		let s:short_cut_key = ''
	endif

	return menu
endfunction

"-------------------------------------------------------
" input_search_pattern()
"-------------------------------------------------------
function! s:input_search_pattern() abort
	let instr = input('Search for pattern: ')
	echo "\r"
	let s:grPattern = empty(instr) ? s:grPattern : instr
endfunction

"-------------------------------------------------------
" input_file_filter()
"-------------------------------------------------------
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:grFilter = empty(instr) ? '*' : instr
endfunction

"-------------------------------------------------------
" input_start_dir()
"-------------------------------------------------------
function! s:input_start_dir(idx) abort
	let init_dir = a:idx ? s:grStrDir[a:idx - 1] : expand('%:p:h')
	let dir = input('Start searching from directory: ', init_dir, 'dir')
	echo "\r"
	if empty(dir) | return 0 | endif

	if isdirectory(dir)
		let temp = fnamemodify(dir, ':p:h')
		let index = len(s:grStrDir) - 1
		for n in range(0, len(s:grStrDir) - 1)
			if s:grStrDir[n] == temp
				let index = n
				break
			endif
		endfor
		call remove(s:grStrDir, index)
		call insert(s:grStrDir, temp, 0)
		call s:create_popup("MAIN")
	else
		echohl WarningMsg | echomsg 'Error: Directory ' . dir. " doesn't exist" | echohl None
		sleep 1
		call s:create_popup("DIR")
	endif
endfunction

"-------------------------------------------------------
" set_grep_option()
"-------------------------------------------------------
function! s:set_grep_option(opt) abort
	let val = {'w':0x01, 'c':0x02, 'r':0x04, 'e':0x08}
	let lno = {'w':4, 'c':5, 'r':6, 'e':7}
	let s:grOption = xor(s:grOption, val[a:opt])
endfunction

"-------------------------------------------------------
" make_grep_cmd_rg()
"-------------------------------------------------------
function! s:make_grep_cmd_rg(search_pattern) abort
	let opt = ''
	"Word Search
	let opt .= and(s:grOption, 0x1) ? 'w' : ''
	"Case-senstive 	
	let opt .= and(s:grOption, 0x2) ? 'i' : ''
	"Disable Regular expressions
	let opt .= and(s:grOption, 0x4) ? 'F' : ''
	if strlen(opt)
		let opt = '-'.opt
	endif
	" Encording(sjis/utf-8)
	let opt .= and(s:grOption, 0x8) ? ' -E sjis' : ' -E utf8'

	let cmd = 'grep! '.opt.' -g *.{'.s:grFilter.'} "'.a:search_pattern. '" '.s:grStrDir[0]

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_grep()
"-------------------------------------------------------
function! s:make_grep_cmd_grep(search_pattern) abort
	let cmd = 'vimgrep! '
	"Word Search
	let cmd .= and(s:grOption, 0x1) ? '/\<'.a:search_pattern : '/'.a:search_pattern
	"Case-senstive	
	let cmd .= and(s:grOption, 0x2) ? '\C' : '\c'
	"Word Search
	let cmd .= and(s:grOption, 0x1) ? '\>/j ' : '/j '
	"Start search directory
	let cmd .= s:grStrDir[0]
	"File filter
	let cmd .= '/**/*.'.substitute(s:grFilter, ",", " **/*.", "g") 

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_vim()
"-------------------------------------------------------
function! s:make_grep_cmd_vim(search_pattern) abort
	let opt = ''
	"Word Search
	let opt .= and(s:grOption, 0x1) ? 'w' : ''
	"Case-senstive 	
	let opt .= and(s:grOption, 0x2) ? 'i' : ''

	"Filter
	if stridx(s:grFilter, ',') >= 0
		let filter = "--include={*.".substitute(s:grFilter, ",", ",*.", "g")."}"
	elseif  s:grFilter!= '*'
		let filter = "--include=*.".s:grFilter
	endif

	let cmd = printf('grep! -r%s %s %s %s', opt, a:search_pattern, s:grStrDir[0], filter)

	return cmd
endfunction

"-------------------------------------------------------
" run_grep()
"-------------------------------------------------------
function! s:run_grep() abort
	if empty(s:grPattern) | return 1 | endif

	" Save search option, Filter and directory
	let g:GREPOPT = s:grOption
	let g:GREPDIR = copy(s:grStrDir)
	let g:GREPFLT = s:grFilter

	" Close the QuickFix
	cclose

	" Move latest quickfix
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" escape meta character
	let search_pattern = escape(s:grPattern, ' *?[{`$%#"|!<>();&' . "'\t\n")

	" Run grep
	if g:Gr_Grep_Proc == 'rg'
		let cmd = s:make_grep_cmd_rg(search_pattern)
	elseif g:Gr_Grep_Proc == 'grep'
		let cmd = s:make_grep_cmd_grep(search_pattern)
	else
		let cmd = s:make_grep_cmd_vim(search_pattern)
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
            \ 'title': ' gr ',
            \ 'callback': handler,
            \ 'filter': 's:popup_menu_filter',
            \ 'filtermode': 'n'
            \ })
    call popup_filter_menu(winid,'k')

	let s:current_mid = a:mid
endfunction

"-------------------------------------------------------
" popup_menu_filter()
"-------------------------------------------------------
function! s:popup_menu_filter(winid, key) abort
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
	"  When pressed 'q' key
	" ---------------------------
	if a:key == 'q'
		call popup_close(a:winid, 99)
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
		call popup_close(a:winid, 0x80)
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
	if a:result == 0x80		 " Run grep
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
" cted_handler()
"-------------------------------------------------------
function! s:dir_menu_selected_handler(winid, result) abort
	if a:result >= 1 && a:result <= 5
		let temp = s:grStrDir[a:result - 1]
		call remove(s:grStrDir, a:result - 1)
		call insert(s:grStrDir, temp, 0)
		call s:create_popup("MAIN")

	elseif a:result == 6
		call s:input_start_dir(0)

	elseif a:result >= 0x81 && a:result <= 0x85
		call s:input_start_dir(and(a:result, 0x7F))
	endif
endfunction

"-------------------------------------------------------
" Gr()
"-------------------------------------------------------
function! Gr#Gr(range, line1, line2) abort
	if a:range
		let temp = @@
		silent normal gvy
		let s:grPattern = @@
		let @@ = temp
	else
		let s:grPattern = expand('<cword>')
	endif

	let s:grStrDir = copy(g:GREPDIR)
	let s:grFilter = g:GREPFLT
	let s:grOption = g:GREPOPT

	call s:create_popup("MAIN")
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
