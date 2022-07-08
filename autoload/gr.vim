"-------------------------------------------------------
" make_menu()
"-------------------------------------------------------
function! s:make_menu(id) abort
	let s:menu = []

	if a:id == 'MAIN' 		" main menu
		call add(s:menu, "Search pattern:   ".s:grPattern)
		call add(s:menu, "Directory:        ".s:grStrDir[0])
		call add(s:menu, "Filter:           ".s:grFilter)
		call add(s:menu, and(s:grOption, 0x1) ? "Word search:      on" : "Word search:      off")
		call add(s:menu, and(s:grOption, 0x2) ? "Case-sensitive:   on" : "Case-sensitive:   off")
		let s:short_cut_key = 'sdfwc'
		if g:Gr_Grep_Proc == 'rg'
			call add(s:menu, and(s:grOption, 0x4) ? "Regexp(.*foo):    on" : "Regexp(.*foo):    off")
			call add(s:menu, and(s:grOption, 0x8) ? "Encord:           sjis" : "Encord:           utf8")
			let s:short_cut_key .= 're'
		endif

	elseif a:id == 'DIR'	" search directory select menu
		let s:menu = copy(s:grStrDir)
		map(s:menu, 'v:key+1.". ".v:val')
    	call add(s:menu, "c: < current directory >")
		let s:short_cut_key = '12345c'
	endif
endfunction

"-------------------------------------------------------
" Input()
"-------------------------------------------------------
function! s:Input(msg, default) abort
	let instr = input(a:msg)
	echo "\r"
	return  empty(instr) ? a:default : instr
endfunction

"-------------------------------------------------------
" Set_gr_option()
"-------------------------------------------------------
function! s:Set_gr_option(key) abort
	let opt = {'w':0x01, 'c':0x02, 'r':0x04, 'e':0x08}
	let s:grOption = xor(s:grOption, opt[a:key])
endfunction

"-------------------------------------------------------
" Set_gr_option()
"-------------------------------------------------------
function! s:Check_dir(dir) abort
	if empty(a:dir) | return -1 | endif

	if !isdirectory(a:dir)
		echohl WarningMsg | echomsg 'Error: Directory ' . a:dir. " doesn't exist" | echohl None
		sleep 1
		return -1
	endif

	" Search for a match in the history 
	let temp = fnamemodify(a:dir, ':p:h')
	let index = len(s:grStrDir) - 1
	for n in range(0, len(s:grStrDir) - 1)
		if s:grStrDir[n] == temp
			let index = n
			break
		endif
	endfor

	call remove(s:grStrDir, index)
	call insert(s:grStrDir, temp, 0)

endfunction

"-------------------------------------------------------
" Popup_menu()
"-------------------------------------------------------
function! s:Popup_menu(id, handler) abort
	let s:current_menu = a:id
	call s:make_menu(a:id)
	call popup_menu(s:menu, #{
			\ filter: 'Popup_menu_filter',
			\ callback: a:handler,
			\ border: [0,0,0,0],
			\ padding: [1,5,1,5]
			\ })
endfunction

"-------------------------------------------------------
" s:Popup_menu_filter()
"-------------------------------------------------------
function! Popup_menu_filter(winid, key) abort

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
	if a:key == 'g' && s:current_menu == "MAIN"
		call popup_close(a:winid, 0x80)
		return 1
	endif

	" ---------------------------
	"  press 'e' at DIR
	" ---------------------------
	if a:key == 'e' && s:current_menu == "DIR"
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
" s:Main_menu_selected_handler()
"-------------------------------------------------------
function! s:Main_menu_selected_handler(winid, result) abort
	if a:result == 0x80		 " Run grep
		call s:run_grep()

	elseif a:result == 1	 " Search pattern
		let s:grPattern = s:Input('Search for pattern: ', s:grPattern)
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")

	elseif a:result == 2	 " Start searching from directory
		call s:Popup_menu("DIR", "s:Dir_menu_selected_handler")

	elseif a:result == 3	 " file filter
		let s:grFilter = s:Input('Search in files matching pattern: ', '*')
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")

	elseif a:result == 4	 " Search option (Word Search)
		call s:Set_gr_option('w')
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")

	elseif a:result == 5	" Search option (Case-senstive)
		call s:Set_gr_option('c')
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")

	elseif a:result == 6	" Regular expressions
		call s:Set_gr_option('r')
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")

	elseif a:result == 7	" Encording
		call s:Set_gr_option('e')
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")
	endif
endfunction

"-------------------------------------------------------
" Dir_menu_selected_handler()
"-------------------------------------------------------
function! s:Dir_menu_selected_handler(winid, result) abort
	if a:result >= 1 && a:result <= 5
		" Select from history
		let temp = s:grStrDir[a:result - 1]
		call remove(s:grStrDir, a:result - 1)
		call insert(s:grStrDir, temp, 0)

	elseif a:result == 6
		let temp = input('Start searching from directory: ', expand("%:p:h"), 'dir')
		echo "\r"
		call s:Check_dir(temp)

	elseif a:result >= 0x81 && a:result <= 0x85
		let temp = input('Start searching from directory: ', s:grStrDir[and(a:result, 0x0F) - 1], 'dir')
		echo "\r"
		call s:Check_dir(temp)
	endif

	call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")
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

	" Close the QuickFix, and clear
	cclose
	call setqflist([], 'r')

	" escape meta character
	let search_pattern = escape(s:grPattern, ' *?[{`$%#"|!<>();&' . "'\t\n")

	if g:Gr_Grep_Proc == 'rg'
		" Search option
		let opt = ''
		if and(s:grOption, 0x1)			"Word Search ?
			let opt = opt.'w'
		endif
		if !and(s:grOption, 0x2)		"Case-senstive ?
			let opt = opt.'i'
		endif
		if !and(s:grOption, 0x4)		"Disable Regular expressions?
			let opt = opt.'F'
		endif
		if strlen(opt)
			let opt = '-'.opt
		endif

		" Encording
		if and(s:grOption, 0x8)			"shift-jis ?
			let opt = opt.' -E sjis'
		else							"UTF-8
			let opt = opt.' -E utf8'
		endif

		let cmd = 'grep! '.opt.' -g *.{'.s:grFilter.'} "'.search_pattern. '" '.s:grStrDir[0]

	elseif g:Gr_Grep_Proc == 'vimgrep' 
		let cmd = 'vimgrep! '
		"Word Search
		let cmd .= and(s:grOption, 0x1) ? '/\<'.search_pattern : '/'.search_pattern
		"Case-senstive	
		let cmd .= and(s:grOption, 0x2) ? '\C' : '\c'
		"Word Search
		let cmd .= and(s:grOption, 0x1) ? '\>/j ' : '/j '
		"Start search directory
		let cmd .= s:grStrDir[0]
		"File filter
		let cmd .= '/**/*.'.substitute(s:grFilter, ",", " **/*.", "g") 

	elseif g:Gr_Grep_Proc == 'grep' 
		"Word Search
		let opt = ''
		if and(s:grOption, 0x1)			"Word Search ?
			let opt = opt.'w'
		endif
		if and(s:grOption, 0x2) == 0	"Case-senstive ?
			let opt = opt.'i'
		endif

		"Filter
		if stridx(s:grFilter, ',') >= 0
			let filter = "--include={*.".substitute(s:grFilter, ",", ",*.", "g")."}"
		elseif  s:grFilter!= '*'
			let filter = "--include=*.".s:grFilter
		else
			let filter = ""
		endif
		
		let cmd = printf('grep! -r%s %s %s %s', opt, search_pattern, s:grStrDir[0], filter)
	endif

	" Run grep
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
" Buffer_menu_selected_handler()
"-------------------------------------------------------
function! s:Buffer_menu_selected_handler(key) abort
	if a:key == '*'
		if s:current_menu == "MAIN"
			let tbl = {1:'s', 2:'d', 3:'f', 4:'w', 5:'c', 6:'r', 7:'e'}
		else
			let tbl = {1:'1', 2:'2', 3:'3', 4:'4', 5:'5', 6:'c'}
		endif
		let pos = getpos(".")
		let c = get(tbl, pos[1], "q")
	else
		let c = a:key
	endif

	if s:current_menu == "MAIN"
		if c == 'g'
			silent! close
			call s:run_grep()

		elseif c == 's'
			let s:grPattern = s:Input('Search for pattern: ', s:grPattern)
			call s:Buffer_menu("MAIN")

		elseif c == 'd'
			call s:Buffer_menu("DIR")

		elseif c == 'f'
			let s:grFilter = s:Input('Search in files matching pattern: ', '*')
			call s:Buffer_menu("MAIN")
		   
		elseif c == 'w'
			call s:Set_gr_option('w')
			call s:Buffer_menu("MAIN")

		elseif c == 'c'
			call s:Set_gr_option('c')
			call s:Buffer_menu("MAIN")

		elseif c == 'r'
			call s:Set_gr_option('r')
			call s:Buffer_menu("MAIN")

		elseif c == 'e'
			call s:Set_gr_option('e')
			call s:Buffer_menu("MAIN")

		elseif c == 'q'
			close
		endif

	elseif s:current_menu == "DIR"
		if c >= 1 && c <= 5
			echo c
			let temp = s:grStrDir[c - 1]
			call remove(s:grStrDir, c - 1)
			call insert(s:grStrDir, temp, 0)
			call s:Buffer_menu("MAIN")

		elseif c == 'c'
			let temp = input('Start searching from directory: ', expand("%:p:h"), 'dir')
			echo "\r"
			if !empty(temp)
				call s:Check_dir(temp)
				call s:Buffer_menu("MAIN")
			endif

		elseif c == 'e'
			let pos = getpos(".")
			let temp = input('Start searching from directory: ', s:grStrDir[pos[1] - 1], 'dir')
			echo "\r"
			if !empty(temp)
				call s:Check_dir(temp)
				call s:Buffer_menu("MAIN")
			endif

		elseif c == 'q'
			call s:Buffer_menu("MAIN")
		endif
	endif
endfunction

"-------------------------------------------------------
" Buffer_menu()
"-------------------------------------------------------
function! s:Buffer_menu(id) abort
	call s:make_menu(a:id)
	let s:current_menu = a:id

	execute "resize ".len(s:menu)
	setlocal modifiable
	silent! %delete _
	silent! 0put =s:menu
	silent! $delete _
	normal! gg
	setlocal nomodifiable
endfunction

"-------------------------------------------------------
" OpenBuffer()
"-------------------------------------------------------
function! s:OpenBuffer(id) abort
	" Make main menu
	let s:current_menu = a:id
	call s:make_menu(a:id)

	let winnum = bufwinnr('-gr-')
	if winnum != -1
		" Already in the window, jump to it
		exe winnum.'wincmd w'
	else
		" Open a new window at the bottom
		exe 'silent! botright '.len(s:menu).'split -gr-'
	endif

	" Delete the contents of the buffer to the black-hole register
	setlocal modifiable
	silent! %delete _

	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal noswapfile
	setlocal nobuflisted
	setlocal nowrap
	setlocal filetype=gr
    setlocal winfixheight winfixwidth

	" Setup the cpoptions properly for the maps to work
	let old_cpoptions = &cpoptions
	set cpoptions&vim

	nnoremap <buffer> <silent> <CR> :call <SID>Buffer_menu_selected_handler('*')<CR>
	nnoremap <buffer> <silent> l :call <SID>Buffer_menu_selected_handler('*')<CR>
	nnoremap <buffer> <silent> g :call <SID>Buffer_menu_selected_handler('g')<CR>
	nnoremap <buffer> <silent> s :call <SID>Buffer_menu_selected_handler('s')<CR>
	nnoremap <buffer> <silent> d :call <SID>Buffer_menu_selected_handler('d')<CR>
	nnoremap <buffer> <silent> f :call <SID>Buffer_menu_selected_handler('f')<CR>
	nnoremap <buffer> <silent> w :call <SID>Buffer_menu_selected_handler('w')<CR>
	nnoremap <buffer> <silent> c :call <SID>Buffer_menu_selected_handler('c')<CR>
	nnoremap <buffer> <silent> r :call <SID>Buffer_menu_selected_handler('r')<CR>
	nnoremap <buffer> <silent> e :call <SID>Buffer_menu_selected_handler('e')<CR>
	nnoremap <buffer> <silent> 1 :call <SID>Buffer_menu_selected_handler('1')<CR>
	nnoremap <buffer> <silent> 2 :call <SID>Buffer_menu_selected_handler('2')<CR>
	nnoremap <buffer> <silent> 3 :call <SID>Buffer_menu_selected_handler('3')<CR>
	nnoremap <buffer> <silent> 4 :call <SID>Buffer_menu_selected_handler('4')<CR>
	nnoremap <buffer> <silent> 5 :call <SID>Buffer_menu_selected_handler('5')<CR>
	nnoremap <buffer> <silent> q :call <SID>Buffer_menu_selected_handler('q')<CR>

	" Restore the previous cpoptions settings
	let &cpoptions = old_cpoptions

	" Put to buffer
	silent! 0put =s:menu

	" Delete the empty line at the end of the buffer
	silent! $delete _

	" Move the cursor to the beginning of the file
	normal! gg

	execute 'syntax match gr "^.*: "'
	highlight link gr Identifier

	setlocal nomodifiable
endfunction

"-------------------------------------------------------
" Gr()
"-------------------------------------------------------
function! Gr(range, line1, line2) abort
	let s:popup_enable = v:version >= 802 ? 1 : 0

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

	if s:popup_enable
		call s:Popup_menu("MAIN", "s:Main_menu_selected_handler")
	else
		call s:OpenBuffer("MAIN")
	endif
endfunction
	
