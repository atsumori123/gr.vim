let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" make_menu()
"-------------------------------------------------------
function! s:make_menu(mid) abort
	let menu = []

	if a:mid == 'MAIN'
		call add(menu, " Search pattern:   ".s:GR.search_pattern)
		call add(menu, " Directory:        ".s:GR.start_dir[0])
		call add(menu, " Filter:           ".s:GR.filter)
		call add(menu, printf(" Word search:      %s", and(s:GR.option, 0x01) ? "on" : "off"))
		call add(menu, printf(" Case-sensitive:   %s", and(s:GR.option, 0x02) ? "on" : "off"))

		if g:Gr_Grep_Proc == 'ripgrep'
			call add(menu, printf(" Regexp(.*foo):    %s", and(s:GR.option, 0x04) ? "on" : "off"))
			call add(menu, printf(" Encording:        %s", and(s:GR.option, 0x08) ? "sijs" : "utf8"))
		endif

	elseif a:mid == 'DIR'
		let menu = map(copy(s:GR.start_dir), '" ".v:val')
		call insert(menu, " [ current directory ]", 0)
	endif

	return menu
endfunction

"-------------------------------------------------------
" draw_line()
"-------------------------------------------------------
function! s:draw_line(id) abort
	if a:id == 1
		let menu = " Search pattern:   ".s:GR.search_pattern
	elseif a:id == 2
		let menu = " Directory:        ".s:GR.start_dir[0]
	elseif a:id == 3
		let menu = " Filter:           ".s:GR.filter
	elseif a:id == 4
		let menu = printf(" Word search:      %s", and(s:GR.option, 0x01) ? "on" : "off")
	elseif a:id == 5
		let menu = printf(" Case-sensitive:   %s", and(s:GR.option, 0x02) ? "on" : "off")
	elseif a:id == 6
		let menu = printf(" Regexp(.*foo):    %s", and(s:GR.option, 0x04) ? "on" : "off")
	elseif a:id == 7
		let menu = printf(" Encord:           %s", and(s:GR.option, 0x08) ? "sijs" : "utf8")
	else
		let menu = ""
	endif

	setlocal modifiable
	if has('nvim')
		call nvim_win_set_config(s:win_id, {
			\	'width': s:get_buffer_width(),
			\	})
	endif
	call setline(a:id, menu)
	setlocal nomodifiable
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
	call s:draw_line(1)
endfunction

"-------------------------------------------------------
" input_file_filter()
"-------------------------------------------------------
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:GR.filter = empty(instr) ? '*' : instr
	call s:draw_line(3)
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
	call s:draw_line(lno[a:opt])
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
	if bufwinnr('-gr-') != -1
		silent! close
	endif

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
" main_menu_selected_handler()
"-------------------------------------------------------
function! s:main_menu_selected_handler(winid, result) abort
	if a:result == 0x8000	 " Run grep
		call s:run_grep()

	elseif a:result == 1	 " Search pattern
		call s:input_search_pattern()

	elseif a:result == 2	 " Start searching from directory
		call s:draw_buffer("DIR")

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
" dir_menu_selected_handler()
"-------------------------------------------------------
function! s:dir_menu_selected_handler(winid, result) abort
	if a:result == 1
		let ret = s:input_start_dir("current", 0)
		call s:draw_buffer(ret ? "MAIN" : "DIR")

	elseif a:result >= 2 && a:result <= 6
		let temp = s:GR.start_dir[a:result - 2]
		call remove(s:GR.start_dir, a:result - 2)
		call insert(s:GR.start_dir, temp, 0)
		call s:draw_buffer("MAIN")

	elseif a:result >= 0x82 && a:result <= 0x86
		let ret = s:input_start_dir("edit", and(a:result, 0x7F) - 2)
		call s:draw_buffer(ret ? "MAIN" : "DIR")
	endif
endfunction

"=======================================================
" vim buffer menu Section
"=======================================================
"-------------------------------------------------------
" set_keymap()
"-------------------------------------------------------
function! s:set_keymap(mid) abort
	if a:mid == 'MAIN'
		nnoremap <buffer> <silent> <CR> :call <SID>main_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> l :call <SID>main_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> g :call <SID>run_grep()<CR>
		nnoremap <buffer> <silent> s :call <SID>input_search_pattern()<CR>
		nnoremap <buffer> <silent> d :call <SID>draw_buffer("DIR")<CR>
		nnoremap <buffer> <silent> f :call <SID>input_file_filter()<CR>
		nnoremap <buffer> <silent> w :call <SID>set_grep_option('w')<CR>
		nnoremap <buffer> <silent> c :call <SID>set_grep_option('c')<CR>
		nnoremap <buffer> <silent> r :call <SID>set_grep_option('r')<CR>
		nnoremap <buffer> <silent> e :call <SID>set_grep_option('e')<CR>
		nnoremap <buffer> <silent> <ESC> :close<CR>
		nnoremap <buffer> <silent> h :close<CR>
		nnoremap <buffer> <silent> q :close<CR>

	elseif a:mid == 'DIR'
		nnoremap <buffer> <silent> <CR> :call <SID>dir_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> l :call <SID>dir_menu_selected_handler(0, line('.'))<CR>
		nnoremap <buffer> <silent> g <nop>
		nnoremap <buffer> <silent> s <nop>
		nnoremap <buffer> <silent> d <nop>
		nnoremap <buffer> <silent> f <nop>
		nnoremap <buffer> <silent> w <nop>
		nnoremap <buffer> <silent> c <nop>
		nnoremap <buffer> <silent> r <nop>
		nnoremap <buffer> <silent> h :call <SID>draw_buffer("MAIN")<CR>
		nnoremap <buffer> <silent> e :call <SID>input_start_dir(line('.'))<CR>
	endif
endfunction

"-------------------------------------------------------
" get_buffer_width()
"-------------------------------------------------------
function! s:get_buffer_width() abort
	if !has('nvim') | return | endif

	let width = len(s:GR.search_pattern) > len(s:GR.start_dir[0])
				\ ? len(s:GR.search_pattern)
				\ : len(s:GR.start_dir[0])
	let width += 20

	return width
endfunction

"-------------------------------------------------------
" draw_buffer()
"-------------------------------------------------------
function! s:draw_buffer(mid) abort
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

	if has('nvim')
		call nvim_win_set_config(s:win_id, {
			\	'width': s:get_buffer_width(),
			\	})
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
			let s:win_id = nvim_open_win(bufnr('%'), v:true, {
				\   'width': s:get_buffer_width(),
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
	if has('nvim')
		highlight MyNormal guibg=#404040
		setlocal winhighlight=Normal:MyNormal
	endif

	setlocal nomodifiable

	let s:current_mid = a:mid
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

	call s:create_buffer("MAIN")
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
