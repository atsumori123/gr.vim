let s:save_cpo = &cpoptions
set cpoptions&vim

let s:menu = []

"*******************************************************
" Open popup menu
"*******************************************************
function! s:open_popup() abort
	const winid = popup_menu(s:menu, {
			\ 'border': [1,1,1,1],
			\ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
			\ 'cursorline': 1,
			\ 'wrap': v:false,
			\ 'mapping': v:false,
			\ 'title': ' '.g:GR_GrepCommand.' ',
			\ 'callback': 's:grep_menu_selected_handler',
			\ 'filter': 's:grep_menu_filter',
			\ 'filtermode': 'n'
			\ })
endfunction

"*******************************************************
" Get window width
"*******************************************************
function! s:get_window_width() abort
	let width = 0
	for v in s:menu
		if width < strlen(v) | let width = strlen(v) | endif
	endfor
	return (&columns - 10) < width ? (&columns - 10) : width
endfunction

"*******************************************************
" ReDraw menu
"*******************************************************
function! s:redraw() abort
	call s:make_menu()

	if has('nvim')
		setlocal modifiable
		" Delete the contents of the buffer to the black-hole register
		silent! %delete _
		silent! 0put = s:menu
		" Delete the empty line at the end of the buffer
		silent! $delete _
		" Move the cursor to the beginning of the file
		call setpos(".", [0, 1, 1, 0])
		setlocal nomodifiable

		" Re.set window layout
		let width = s:get_window_width()
		call nvim_win_set_config(win_getid(), {
			\ 'width': width,
			\ 'height': len(s:menu),
			\ 'relative': 'editor',
			\ 'row': (&lines - len(s:menu)) / 2,
			\ 'col': (&columns - width) / 2,
			\})

	else
		call s:open_popup()
	endif
endfunction

"*******************************************************
" Open floating window
"*******************************************************
function! s:open_floating_window()
	" open floating window
	let width = s:get_window_width()
	let height = len(s:menu)

	let win_id = nvim_open_win(bufnr('%'), v:true, {
		\	'title': ' '.g:GR_GrepCommand.' ',
		\	'width': width,
		\	'height': height,
		\	'relative': 'editor',
		\	'anchor': "NW",
		\	'row': (&lines - height) / 2,
		\	'col': (&columns - width) / 2,
		\	'external': v:false,
		\	'border': "single",
		\})

	" draw to new buffer
	enew
	call setline('.', s:menu)

	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal nomodifiable
	setlocal noswapfile
	setlocal nowrap
	setlocal nonumber
	setlocal nocursorcolumn
	setlocal nocursorline

	nnoremap <buffer> <silent> <CR> :call <SID>grep_menu_selected_handler(0, line("."))<CR>
	nnoremap <buffer> <silent> s :call <SID>grep_menu_selected_handler(0, 1)<CR>
	nnoremap <buffer> <silent> 1 :call <SID>grep_menu_selected_handler(0, 2)<CR>
	nnoremap <buffer> <silent> 2 :call <SID>grep_menu_selected_handler(0, 3)<CR>
	nnoremap <buffer> <silent> 3 :call <SID>grep_menu_selected_handler(0, 4)<CR>
	nnoremap <buffer> <silent> 4 :call <SID>grep_menu_selected_handler(0, 5)<CR>
	nnoremap <buffer> <silent> 5 :call <SID>grep_menu_selected_handler(0, 6)<CR>
	nnoremap <buffer> <silent> f :call <SID>grep_menu_selected_handler(0, 7)<CR>
	nnoremap <buffer> <silent> w :call <SID>grep_menu_selected_handler(0, 8)<CR>
	nnoremap <buffer> <silent> c :call <SID>grep_menu_selected_handler(0, 9)<CR>
	nnoremap <buffer> <silent> r :call <SID>grep_menu_selected_handler(0, 10)<CR>
	nnoremap <buffer> <silent> n :call <SID>grep_menu_selected_handler(0, 11)<CR>
	nnoremap <buffer> <silent> e :call <SID>grep_menu_selected_handler(0, or(0x100, line(".")))<CR>
	nnoremap <buffer> <silent> g :call <SID>grep_menu_selected_handler(0, 0)<CR>
	nnoremap <buffer> <silent> q :close<CR>

	syntax match GrLabel '^ .*: '
	highlight default link GrLabel Label
	highlight default link FloatBorder Normal
	set winhighlight=Normal:Normal
endfunction

"*******************************************************
"* Function name: s:grep_menu_filter()
"* Function		: Filtering when popup-menu is selected
"*
"* Argument		: winid : Winddow ID
"*				  key	: Pressed key
"*******************************************************
function! s:grep_menu_filter(winid, key) abort
	if a:key == 'q'
		" when pressed 'q'(Terminate) key
		call popup_close(a:winid, -1)
		return 1
	endif

	" When pressed 'e'(edit) key
	if a:key == 'e'
		call win_execute(a:winid, 'let w:lnum = line(".")')
		let lnum = getwinvar(a:winid, 'lnum', 0)
		if lnum >= 2 && lnum <= 6
			call popup_close(a:winid, or(0x100, lnum))
			return 1
		endif
	endif

	" When pressed shortcut key
	let index = stridx(s:short_cut_key, a:key)
	if index >= 0
		call popup_close(a:winid, index)
		return 1
	endif

	" Other, pass to normal filter
	return popup_filter_menu(a:winid, a:key)
endfunction

"*******************************************************
" Make menu
"*******************************************************
function! s:make_menu() abort
	let s:menu = []

	call add(s:menu, " Search pattern  : ".s:gr["PATTERN"]." ")
	call add(s:menu, " Directory 1     : ".s:gr["DIR"][0]." ")
	call add(s:menu, "           2     : ".s:gr["DIR"][1]." ")
	call add(s:menu, "           3     : ".s:gr["DIR"][2]." ")
	call add(s:menu, "           4     : ".s:gr["DIR"][3]." ")
	call add(s:menu, "           5     : ".s:gr["DIR"][4]." ")
	call add(s:menu, " File filter     : ".s:gr["FILTER"])
	call add(s:menu, " Word search     : ".(and(s:gr["OPT"], 0x01) ? "on" : "off"))
	call add(s:menu, " Case sensitive  : ".(and(s:gr["OPT"], 0x02) ? "on" : "off"))
	call add(s:menu, " RegExp          : ".(and(s:gr["OPT"], 0x04) ? "on" : "off"))
	let s:short_cut_key = 'gs12345fwcr'
	if g:GR_GrepCommand == 'ripgrep'
		call add(s:menu, " Encording       : ".(and(s:gr["OPT"], 0x08) ? "sijs" : "utf8"))
		let s:short_cut_key .= 'e'
	endif
endfunction

"*******************************************************
" Input search pattern
"*******************************************************
function! s:input_search_pattern() abort
	let instr = input('Search for pattern: ')
	echo "\r"
	if !empty(instr) | let s:gr["PATTERN"] = instr | endif
endfunction

"*******************************************************
" Selected start directory
"*******************************************************
function! s:select_start_dir(n) abort
	let idx = a:n < 5 ? a:n : 4
	let temp = remove(s:gr["DIR"], idx)
	call insert(s:gr["DIR"], temp, 0)
endfunction

"*******************************************************
" Edit start directory
"*******************************************************
function! s:edit_start_dir(n) abort
	let dir = input('Start searching from directory: ', s:gr["DIR"][a:n], 'dir')
	echo "\r"

	if empty(dir)
		return

	elseif isdirectory(dir)
		let dir = substitute(dir, has('unix') ? "/$" : "\$", "", "")
		let dir = fnamemodify(dir, ':p:h')
		call remove(s:gr["DIR"], index(s:gr["DIR"], dir))
		call insert(s:gr["DIR"], dir, 0)
		let s:gr["DIR"][4] = s:current_dir

	else
		echohl WarningMsg | echomsg 'Error: Directory ' . dir. " doesn't exist" | echohl None
		sleep 1
	endif
endfunction

"*******************************************************
" Input file filter
"*******************************************************
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:gr["FILTER"] = empty(instr) ? '*' : instr
endfunction

"*******************************************************
" Set grep option
"*******************************************************
function! s:set_grep_option(opt) abort
	let val = {'w':0x01, 'c':0x02, 'r':0x04, 'e':0x08}
	let s:gr["OPT"] = xor(s:gr["OPT"], val[a:opt])
endfunction

"*******************************************************
" Generate ripgrep command
"*******************************************************
function! s:generate_cmd_ripgrep() abort
	let opt = ''
	"Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? '' : 'i'
	"Disable Regular expressions
	let opt .= and(s:gr["OPT"], 0x4) ? '' : 'F'
	if strlen(opt)
		let opt = '-'.opt
	endif
	" Encording(sjis/utf-8)
	let opt .= and(s:gr["OPT"], 0x8) ? ' -E sjis' : ' -E utf8'

	let cmd = 'grep! '.opt.' -g *.{'.s:gr["FILTER"].'} "'.s:gr["PATTERN"]. '" '.s:gr["DIR"][0]

	return cmd
endfunction

"*******************************************************
" Generate vimgrep command
"*******************************************************
function! s:generate_cmd_vimgrep() abort
	let cmd = 'vimgrep! '
	"Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '/\<'.s:gr["PATTERN"] : '/'.s:gr["PATTERN"]
	"Case-senstive
	let cmd .= and(s:gr["OPT"], 0x2) ? '\C' : '\c'
	"Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '\>/j ' : '/j '
	"Start search directory
	let cmd .= s:gr["DIR"][0]
	"File filter
	let cmd .= '/ **/*.'.substitute(s:gr["FILTER"], ",", " **/*.", "g")

	return cmd
endfunction

"*******************************************************
" Generate grep command
"*******************************************************
function! s:generate_cmd_grep() abort
	let opt = ''
	"Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? '' : 'i'

	"Filter
	if stridx(s:gr["FILTER"], ',') >= 0
		let filter = "--include={*.".substitute(s:gr["FILTER"], ",", ",*.", "g")."}"
	elseif	s:gr["FILTER"] != '*'
		let filter = "--include=*.".s:gr["FILTER"]
	else
		let filter = ""
	endif

	let cmd = printf('grep! -r%s %s %s %s', opt, s:gr["PATTERN"], s:gr["DIR"][0], filter)

	return cmd
endfunction

"*******************************************************
" Run grep
"*******************************************************
function! s:run_grep() abort
	if empty(s:gr["PATTERN"]) | return 1 | endif

	" Close the QuickFix. and Move latest quickfix
	cclose
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" Display grep executing...
	echohl Search | echomsg ">>> grep executing..." | echohl None

	" if reglar expression is disabled then escape meta character
	if and(s:gr['OPT'], 0x04) == 0
		let s:gr["PATTERN"] = escape(s:gr["PATTERN"], ' *?[]{}`$%#"|!<>();&' . "'\t\n")
	endif

	execute 'lcd '.s:gr["DIR"][0]

	"let start_time = reltime()
	" Run grep
	if g:GR_GrepCommand == 'ripgrep'
		silent! execute s:generate_cmd_ripgrep()
	elseif g:GR_GrepCommand == 'grep'
		silent! execute s:generate_cmd_grep()
	else
		silent! execute s:generate_cmd_vimgrep()
	endif

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if len(getqflist())
		exe 'botright copen'
		redraw!
		set modifiable
		set nowrap
		echo len(getqflist())." hits"
	else
		redraw!
		echo "Search pattern not found"
	endif
	"echo reltimestr(reltime(start_time))
endfunction

"*******************************************************
" Selected handler of grep menu
"*******************************************************
function! s:grep_menu_selected_handler(winid, result) abort

	if	   a:result == 0	"Run grep
		if has('nvim') | close | endif
		call s:run_grep()

	elseif a:result == 1	" Search pattern
		call s:input_search_pattern()
		call s:redraw()

	elseif a:result >= 2 && a:result <= 6	 " Start searching from directory
		call s:select_start_dir(a:result - 2)
		call s:redraw()

	elseif a:result == 7	" file filter
		call s:input_file_filter()
		call s:redraw()

	elseif a:result == 8	" Search option (Word Search)
		call s:set_grep_option('w')
		call s:redraw()

	elseif a:result == 9	" Search option (Case-senstive)
		call s:set_grep_option('c')
		call s:redraw()

	elseif a:result == 10	" Regular expressions
		call s:set_grep_option('r')
		call s:redraw()

	elseif a:result == 11	" Encording
		call s:set_grep_option('e')
		call s:redraw()

	elseif a:result >= 0x102 && a:result <= 0x107	" Edit
		call s:edit_start_dir(and(a:result, 0xFF) - 2)
		call s:redraw()
	endif

endfunction

"*******************************************************
" Start grep
"*******************************************************
function! gr#start(range, start, end) abort
	let s:current_dir = expand('%:p:h')
	if !exists('s:gr')
		let s:gr = {}
		let s:gr["PATTERN"] = ""
		let s:gr["DIR"] = [s:current_dir, getcwd(), getcwd(), getcwd(), s:current_dir]
		let s:gr["FILTER"] = 'c,cpp'
		let s:gr["OPT"] = 0x03
	endif

	if a:range
		let temp = @@
		silent normal gvy
		let s:gr["PATTERN"] = @@
		let @@ = temp
	else
		let s:gr["PATTERN"] = expand('<cword>')
	endif
	"let s:gr["PATTERN"] = escape(s:gr["PATTERN"], '^$.*[]/~\')
	let s:gr["DIR"][4] = s:current_dir

	call s:make_menu()
	if has('nvim')
		call s:open_floating_window()
	else
		call s:open_popup()
	endif
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

