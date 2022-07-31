let s:save_cpo = &cpoptions
set cpoptions&vim

"=======================================================
" Common Section
"=======================================================
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
		let s:short_cut_key = '12345c'
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
	call s:redraw("MAIN")
endfunction

"-------------------------------------------------------
" input_file_filter()
"-------------------------------------------------------
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:grFilter = empty(instr) ? '*' : instr
	call s:redraw("MAIN")
endfunction

"-------------------------------------------------------
" input_start_dir()
"-------------------------------------------------------
function! s:input_start_dir(idx) abort
	let init_dir = a:idx ? s:grStrDir[a:idx - 1] : expand("%:p:h")
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
		call s:redraw("MAIN")
	else
		echohl WarningMsg | echomsg 'Error: Directory ' . dir. " doesn't exist" | echohl None
		sleep 1
		call s:redraw("DIR")
	endif
endfunction

"-------------------------------------------------------
" set_grep_option()
"-------------------------------------------------------
function! s:set_grep_option(opt) abort
	let val = {'w':0x01, 'c':0x02, 'r':0x04, 'e':0x08}
	let s:grOption = xor(s:grOption, val[a:opt])
	call s:redraw("MAIN")
endfunction

"-------------------------------------------------------
" make_grep_cmd_rg()
"-------------------------------------------------------
function! s:make_grep_cmd_rg(search_pattern) abort
	let opt = ''

	" Search option
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
	"Word Search
	let opt = ''
	if and(s:grOption, 0x1)			"Word Search ?
		let opt = opt.'w'
	endif
	if and(s:grOption, 0x2) == 0	"Case-senstive ?
		let opt = opt.'i'
	endif

	"Filter
	let filter = ""
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
	if bufwinnr('-gr-') != -1
		silent! close
	endif

	if empty(s:grPattern) | return 1 | endif

	" Save search option, Filter and directory
	let g:GREPOPT = s:grOption
	let g:GREPDIR = copy(s:grStrDir)
	let g:GREPFLT = s:grFilter

	" Close the QuickFix
	cclose

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

"=======================================================
" vim Popup menu Section
"=======================================================
"-------------------------------------------------------
" create_popup()
"-------------------------------------------------------
function! s:create_popup(mid) abort
	let menu = s:make_menu(a:mid)
	if a:mid == "MAIN"
		let handler = "s:main_menu_selected_handler"
	else
		let handler = "s:dir_menu_selected_handler"
	endif

	call popup_menu(menu, #{
			\ filter: 's:popup_menu_filter',
			\ callback: handler,
			\ border: [0,0,0,0],
			\ padding: [1,1,1,1]
			\ })

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

	elseif a:result == 2	 " Start searching from directory
		call s:redraw("DIR")

	elseif a:result == 3	 " file filter
		call s:input_file_filter()

	elseif a:result == 4	 " Search option (Word Search)
		call s:set_grep_option('w')

	elseif a:result == 5	" Search option (Case-senstive)
		call s:set_grep_option('c')

	elseif a:result == 6	" Regular expressions
		call s:set_grep_option('r')

	elseif a:result == 7	" Encording
		call s:set_grep_option('e')
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
		call s:redraw("MAIN")

	elseif a:result == 6
		call s:input_start_dir(0)

	elseif a:result >= 0x81 && a:result <= 0x85
		call s:input_start_dir(and(a:result, 0x7F))
	endif
endfunction

"=======================================================
" vim buffer menu Section
"=======================================================
"-------------------------------------------------------
" parent_menu()
"-------------------------------------------------------
function! s:parent_menu()
	if s:current_mid == 'MAIN'
		close
	else
		call s:redraw("MAIN")
	endif
endfunction

"-------------------------------------------------------
" set_keymap()
"-------------------------------------------------------
function! s:set_keymap(mid) abort
	if a:mid == 'MAIN'
		nnoremap <buffer> <silent> <CR> :call <SID>main_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> l :call <SID>main_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> g :call <SID>run_grep()<CR>
		nnoremap <buffer> <silent> s :call <SID>input_search_pattern()<CR>
		nnoremap <buffer> <silent> d :call <SID>redraw_floating_window("DIR")<CR>
		nnoremap <buffer> <silent> f :call <SID>input_file_filter()<CR>
		nnoremap <buffer> <silent> w :call <SID>set_grep_option('w')<CR>
		nnoremap <buffer> <silent> c :call <SID>set_grep_option('c')<CR>
		nnoremap <buffer> <silent> r :call <SID>set_grep_option('r')<CR>
		nnoremap <buffer> <silent> e :call <SID>set_grep_option('e')<CR>
		nnoremap <buffer> <silent> h :call <SID>parent_menu()<CR>
		nnoremap <buffer> <silent> q :close<CR>

	elseif a:mid == 'DIR'
		nnoremap <buffer> <silent> <CR> :call <SID>dir_menu_selected_handler(line('.'))<CR>
		nnoremap <buffer> <silent> l :call <SID>dir_menu_selected_handler(line('.'))<CR>
		nnoremap <buffer> <silent> g <nop>
		nnoremap <buffer> <silent> s <nop>
		nnoremap <buffer> <silent> d <nop>
		nnoremap <buffer> <silent> f <nop>
		nnoremap <buffer> <silent> w <nop>
		nnoremap <buffer> <silent> c <nop>
		nnoremap <buffer> <silent> r <nop>
		nnoremap <buffer> <silent> e :call <SID>input_start_dir(line('.'))<CR>
	endif
endfunction

"-------------------------------------------------------
" redraw_buffer()
"-------------------------------------------------------
function! s:redraw_buffer(mid) abort
	let menu = s:make_menu(a:mid)

	execute "resize ".len(menu)
	setlocal modifiable
	silent! %delete _
	silent! 0put = menu
	silent! $delete _
	normal! gg
	if s:current_mid != a:mid
		call s:set_keymap(a:mid)
	endif
	setlocal nomodifiable

	let s:current_mid = a:mid
endfunction

"-------------------------------------------------------
" s:create_buffer()
"-------------------------------------------------------
function! s:create_buffer(mid) abort
	let menu = s:make_menu(a:mid)

	let winnum = bufwinnr('-gr-')
	if winnum != -1
		" Already in the window, jump to it
		exe winnum.'wincmd w'
	else
		" Open a new floating window
		if has('nvim')
			let win_id = nvim_open_win(bufnr('%'), v:true, {
				\   'width': 70,
				\   'height': len(menu),
				\   'relative': 'cursor',
				\   'anchor': "NW",
				\   'row': 1,
				\   'col': 0,
				\   'external': v:false,
				\})
			enew
			file `= '-gr-'`
		else
			exe 'silent! botright '.len(menu).'split -gr-'
		    setlocal winfixheight winfixwidth
		endif
	endif

	setlocal modifiable
	silent! %delete _

	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal noswapfile
	setlocal nobuflisted
	setlocal nowrap
	setlocal nonumber
	setlocal filetype=gr

	call s:set_keymap(a:mid)

	" Put to buffer
	silent! 0put = menu

	" Delete the empty line at the end of the buffer
	silent! $delete _

	" Move the cursor to the beginning of the file
	normal! gg
	normal! h

	execute 'syntax match gr "^.*\: "'
	highlight link gr Directory
"	highlight MyNormal guibg=#303030
"	setlocal winhighlight=Normal:MyNormal

	setlocal nomodifiable

	let s:current_mid = a:mid
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

	if has('nvim')
		let s:redraw = function('s:redraw_buffer')
		call s:create_buffer("MAIN")
	elseif v:version >= 802
		let s:redraw = function('s:create_popup')
		call s:create_popup("MAIN")
	else
		let s:redraw = function('s:redraw_buffer')
		call s:create_buffer("MAIN")
	endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
