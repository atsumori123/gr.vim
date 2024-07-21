let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" refresh
"-------------------------------------------------------
function! s:refresh() abort
	let pos = getpos('.')
	call s:make_menu()
	setlocal modifiable

	silent! %delete _
	silent! 0put = s:menu
	silent! $delete _
	normal! gg

	setlocal nomodifiable
	call setpos('.', pos)
endfunction

"-------------------------------------------------------
" make_menu()
"-------------------------------------------------------
function! s:make_menu() abort
	let s:menu = []

	call add(s:menu, " Search Word  : '".s:search_pattern."' ")
	call add(s:menu, " Directory[".s:dirNo."] : ".s:gr["DIR"][s:dirNo])

	let str  = " Option       :"
	let str .= " Filetype=".s:gr["FILTER"]
	let str .= "  Word=".(and(s:gr["OPT"], 0x01) ? "*" : "-")
	let str .= "  Case=".(and(s:gr["OPT"], 0x02) ? "*" : "-")

	if g:Gr_Grep_Proc == 'rg'
		let str .= "  RegEx=".(and(s:gr["OPT"], 0x04) ? "*" : "-")
		let str .= "  Encord=".(and(s:gr["OPT"], 0x08) ? "sjis" : "utf8")
	endif
	call add(s:menu, str)
endfunction

"-------------------------------------------------------
" input_search_patter
"-------------------------------------------------------
function! s:input_search_pattern() abort
	let instr = input('Search for pattern: ')
	echo "\r"
	let s:search_pattern = empty(instr) ? s:search_pattern : instr
	call s:refresh()
endfunction

"-------------------------------------------------------
" input_file_filter
"-------------------------------------------------------
function! s:input_file_filter() abort
	let instr = input('Search in files matching pattern: ')
	echo "\r"
	let s:gr["FILTER"] = empty(instr) ? '*' : instr
	call s:refresh()
endfunction

"-------------------------------------------------------
" toggle_grep_option
"-------------------------------------------------------
function! s:toggle_grep_option(opt) abort
	let val = {1:0x01, 2:0x02, 3:0x04, 4:0x08}
	let s:gr["OPT"] = xor(s:gr["OPT"], val[a:opt])
	call s:refresh()
endfunction

"-------------------------------------------------------
" key_CR
"-------------------------------------------------------
function! s:key_CR() abort
	if line('.') == 1
		call s:input_search_pattern()
	elseif line('.') == 2
		call s:edit_start_dir()
	endif
endfunction

"-------------------------------------------------------
" select_start_dir
"-------------------------------------------------------
function! s:select_start_dir(dir) abort
	let s:dirNo = s:dirNo + a:dir
	if s:dirNo > 5
		let s:dirNo = 0
	elseif s:dirNo < 0
		let s:dirNo = 5
	endif
	call s:refresh()
endfunction

"-------------------------------------------------------
" toggle_grep_option
"-------------------------------------------------------
function! s:close() abort
	silent! close
endfunction

"-------------------------------------------------------
" make_grep_cmd_rg
"-------------------------------------------------------
function! s:make_grep_cmd_rg(search_pattern) abort
	let opt = ''
	"Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? 'i' : ''
	"Disable Regular expressions
	let opt .= and(s:gr["OPT"], 0x4) ? 'F' : ''
	if strlen(opt)
		let opt = '-'.opt
	endif
	" Encording(sjis/utf-8)
	let opt .= and(s:gr["OPT"], 0x8) ? ' -E sjis' : ' -E utf8'

	let cmd = 'grep! '.opt.' -g *.{'.s:gr["FILTER"].'} "'.a:search_pattern. '" '.s:gr["DIR"][0]

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_grep
"-------------------------------------------------------
function! s:make_grep_cmd_vim(search_pattern) abort
	let cmd = 'vimgrep! '
	"Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '/\<'.a:search_pattern : '/'.a:search_pattern
	"Case-senstive
	let cmd .= and(s:gr["OPT"], 0x2) ? '\C' : '\c'
	"Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '\>/j ' : '/j '
	"Start search directory
	let cmd .= s:gr["DIR"][0]
	"File filter
	let cmd .= '/**/*.'.substitute(s:gr["FILTER"], ",", " **/*.", "g")

	return cmd
endfunction

"-------------------------------------------------------
" make_grep_cmd_grep
"-------------------------------------------------------
function! s:make_grep_cmd_grep(search_pattern) abort
	let opt = ''
	"Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? 'w' : ''
	"Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? 'i' : ''

	"Filter
	if stridx(s:gr["FILTER"], ',') >= 0
		let filter = "--include={*.".substitute(s:gr["FILTER"], ",", ",*.", "g")."}"
	elseif  s:grFilter!= '*'
		let filter = "--include=*.".s:gr["FILTER"]
	endif

	let cmd = printf('grep! -r%s %s %s %s', opt, a:search_pattern, s:gr["DIR"][0], filter)

	return cmd
endfunction

"-------------------------------------------------------
" run_grep
"-------------------------------------------------------
function! s:run_grep() abort
	if bufwinnr('-gr-') != -1
		silent! close
	endif

	if empty(s:search_pattern) | return 1 | endif

	" Save search option, Filter and directory
	call s:organize_dir()
	let g:GR = s:gr

	" Close the QuickFix
	cclose
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" escape meta character
	let search_pattern = escape(s:search_pattern, ' *?[{`$%#"|!<>();&' . "'\t\n")

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
" organize_dir
"-------------------------------------------------------
function! s:organize_dir() abort
	" Get selected directory
	let temp = remove(s:gr["DIR"], s:dirNo)

	" Remove s:gr["DIR"][5] and [4]
	while len(s:gr["DIR"]) > 4
		call remove(s:gr["DIR"], -1)
	endwhile

	" Insert selected directory
	call insert(s:gr["DIR"], temp, 0)
endfunction

"-------------------------------------------------------
" edit_start_dir
"-------------------------------------------------------
function! s:edit_start_dir() abort
	let dir = input('Start searching from directory: ', s:gr["DIR"][s:dirNo], 'dir')
	echo "\r"
	if empty(dir) | return 0 | endif

	if isdirectory(dir)
		let temp = fnamemodify(dir, ':p:h')
		let index = len(s:gr["DIR"]) - 2
		for n in range(0, len(s:gr["DIR"]) - 2)
			if s:gr["DIR"][n] == temp
				let index = n
				break
			endif
		endfor
		let s:dirNo = 0
		call remove(s:gr["DIR"], index)
		call insert(s:gr["DIR"], temp, 0)
		call s:refresh()
	else
		echohl WarningMsg | echomsg 'Error: Directory ' . dir. " doesn't exist" | echohl None
		sleep 1
		call s:refresh()
	endif
endfunction

"-------------------------------------------------------
" s:create_buffe
"-------------------------------------------------------
function! s:create_buffer() abort
	"If Already in the window, jump to it
	let winnum = bufwinnr('-gr-')
	if winnum != -1
		exe winnum.'wincmd w'
		return
	endif

	"Open a new floating window
	exe 'silent! botright 3 '.'split -gr-'
    setlocal winfixheight winfixwidth

	"Start modify, Clear buffer
	setlocal modifiable
	silent! %delete _

	"Configure buffer
	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal noswapfile

	setlocal nobuflisted
	setlocal nowrap
	setlocal nonumber
	setlocal filetype=gr

	"Set keymap
	nnoremap <buffer> <silent> g :call <SID>run_grep()<CR>
	nnoremap <buffer> <silent> <CR> :call <SID>key_CR()<CR>
	nnoremap <buffer> <silent> <S-j> :call <SID>select_start_dir(1)<CR>
	nnoremap <buffer> <silent> <S-k> :call <SID>select_start_dir(-1)<CR>
	nnoremap <buffer> <silent> f :call <SID>input_file_filter()<CR>
	nnoremap <buffer> <silent> w :call <SID>toggle_grep_option(1)<CR>
	nnoremap <buffer> <silent> c :call <SID>toggle_grep_option(2)<CR>
	nnoremap <buffer> <silent> r :call <SID>toggle_grep_option(3)<CR>
	nnoremap <buffer> <silent> e :call <SID>toggle_grep_option(4)<CR>
	nnoremap <buffer> <silent> q :call <SID>close()<CR>

	" Put to buffer
	call s:make_menu()
	silent! 0put = s:menu

	" Delete the empty line at the end of the buffer
	silent! $delete _

	" Set highlight
	execute 'syntax match gr_dir "^ Directory.*"'
	execute 'syntax match gr_opt "^ Option.*"'
	highlight link gr_dir Directory
	highlight link gr_opt Label

	" Move the cursor to the beginning of the file
"	normal! gg
"	normal! h
	call setpos('.', [0, 0, 17, 0])

	setlocal nomodifiable
endfunction

"-------------------------------------------------------
" Gr
"-------------------------------------------------------
function! Gr#Gr(range, line1, line2) abort
	if a:range
		let temp = @@
		silent normal gvy
		let s:search_pattern = @@
		let @@ = temp
	else
		let s:search_pattern = expand('<cword>')
	endif

	let s:dirNo = 0
	let s:gr = deepcopy(g:GR)
	call add(s:gr["DIR"], expand('%:p:h'))
	call s:create_buffer()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
