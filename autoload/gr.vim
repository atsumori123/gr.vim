let s:save_cpo = &cpoptions
set cpoptions&vim

let s:main_popup_winid = 0
let s:sub_popup_winid = 0

" gr用のハイライトグループを定義
if empty(prop_type_get('gr'))
	call prop_type_add('gr', {'highlight': 'Identifier'})
endif

"-------------------------------------------------------
" set_property
"-------------------------------------------------------
function! s:set_property(v, len) abort
	return {'text': a:v, 'props': [#{col: 1, length: a:len, type: 'gr'}]}
endfunction

"*******************************************************
" Make main menu
"*******************************************************
function! s:make_main_menu() abort
	let menu = []

	" 検索パターン
	call add(menu, s:set_property('p. ' . s:search_pattern, 2))

	" 検索開始ディレクトリ
	call add(menu, s:set_property('d. ' . s:start_directory, 2))

	" 検索フィルタ
	call add(menu, s:set_property('f. ' . s:gr.search_filter, 2))

	" 区切り
	call add(menu, s:set_property("", 0))

	" 単語検索
	call add(menu, s:set_property(printf("%-15s%s", 'w. Word', and(s:gr.opt, 0x01) ? "*" : ""), 15))

	" 大文字/小文字
	call add(menu, s:set_property(printf("%-15s%s", 'i. Ignorecase', and(s:gr.opt, 0x02) ? "*" : ""), 15))

	" 検索パターンのハイライト
	call add(menu, s:set_property(printf("%-15s%s", '1. Highlight', and(s:gr.opt, 0x04) ? "*" : ""), 15))

	" エンコード(rgのみ)
	if g:gr_grep_command ==# 'rg'
		call add(menu, s:set_property(printf("%-15s%s", '2. Encoding', and(s:gr.opt, 0x10) ? "*" : ""), 15))
	endif

	return menu
endfunction

"*******************************************************
" Open main popup
"*******************************************************
function! s:open_main_popup(menu) abort
	let opts = {
			\ 'border'		: [1,1,1,1],
			\ 'borderchars'	: has('unix') ? [] : ['─','│','─','│','┌','┐','┘','└'],
			\ 'padding'		: [1,2,1,2],
			\ 'minwidth'	: 50,
			\ 'cursorline'	: 1,
			\ 'mapping'		: v:false,
			\ 'title'		: ' G. '.g:gr_grep_command.' ',
			\ 'filter'		: function('s:main_menu_filter'),
			\ 'callback'	: function('s:main_menu_callback'),
			\ 'filtermode'	: 'n',
			\ 'zindex'		: 1
			\ }

	let s:main_popup_winid = popup_menu(a:menu, opts)
endfunction

"*******************************************************
" Update popup menu
"*******************************************************
function! s:update_main_popup(winid) abort
	let output = s:make_main_menu()

	call popup_settext(a:winid, output)
	call popup_setoptions(a:winid, {'title' : ' G. '.g:gr_grep_command.' '})
endfunction

"*******************************************************
" Main menu filter
"*******************************************************
function! s:main_menu_filter(winid, key) abort
	" 行番号とキーを組み合わせてユニークなキーコードをつくる
	call win_execute(a:winid, 'let w:lnum = line(".")')
	let lnum = getwinvar(a:winid, 'lnum', 0)
	let unqkey = lnum . a:key

	" ショートカットキー処理
	if a:key ==# 'q'
		" Exit
		call popup_close(a:winid, -1)
		return 1

	elseif a:key ==# 'g'
		" Run grep
		call popup_close(a:winid, 0)
		return 1

	elseif a:key ==# 'G'
		" Change grepprg
		call gr#grepcmd#change_grepprg()
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 's' || unqkey ==# '1e'
		" Search pattern
		call s:input_search_pattern()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '1l'
		" 検索パターン履歴
		call s:open_sub_popup('Search pattern', s:gr.old_pattern)
		return 1

	elseif a:key ==# 'd' || unqkey ==# '2e'
		" Start search directory
		call s:edit_start_dir()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '2l'
		" 検索パターン履歴
		call s:open_sub_popup('Directory', s:gr.old_directory)
		return 1

	elseif unqkey ==# '3j' || unqkey ==# '3\<DOWN>'
		" 空白行をスキップ (2行目で'j')
		call win_execute(a:winid, 'normal! 2j')
		return 1

	elseif a:key ==# 'f' || unqkey ==# '3l'
		" file filter
		call s:input_file_filter()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '5k'
		" 空白行をスキップ (4行目で'k')
		call win_execute(a:winid, 'normal! 2k')
		return 1

	elseif a:key ==# 'w' || unqkey ==# '5l'
		" Search option (Word Search)
		call s:set_grep_option(0x01)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 'i' || unqkey ==# '6l'
		" Search option (Ignore case)
		call s:set_grep_option(0x02)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 'h' || unqkey ==# '7l'
		" hlsearch option
		call s:set_grep_option(0x04)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# '1' || unqkey ==# '8l'
		" Encording
		call s:set_grep_option(0x10)
		call s:update_main_popup(a:winid)
		return 1

	endif

	" Other, pass to normal filter
	return popup_filter_menu(a:winid, a:key)
endfunction

"*******************************************************
" Main menu callback
"*******************************************************
function! s:main_menu_callback(winid, result) abort
	if a:result == 0	"Run grep
		call s:run_grep()
	endif
endfunction

"*******************************************************
" Open sub popup menu
"*******************************************************
function! s:open_sub_popup(title, menu) abort
	let opts = {
			\ 'border'		: [1,1,1,1],
			\ 'borderchars'	: has('unix') ? [] : ['─','│','─','│','┌','┐','┘','└'],
			\ 'padding'		: [1,2,1,2],
			\ 'cursorline'	: 1,
			\ 'mapping'		: v:false,
			\ 'title'		: ' '.a:title.' ',
			\ 'filter'		: function('s:sub_menu_filter'),
			\ 'callback'	: function('s:sub_menu_callback'),
			\ 'zindex'		: 2
			\ }

	let s:sub_popup_winid = popup_menu(a:menu, opts)
endfunction

"*******************************************************
" Sub menu filter
"*******************************************************
function! s:sub_menu_filter(winid, key) abort
	if a:key ==# 'q' || a:key ==# 'h'
		call popup_close(a:winid, -1)
		return 1

	elseif a:key ==# "\<CR>" || a:key ==# 'l'
		let options = popup_getoptions(a:winid)
		let title = get(options, 'title', '')

		call win_execute(a:winid, 'let w:lnum = line(".")')
		let lnum = getwinvar(a:winid, 'lnum', 0)

		if title =~ 'Pattern'
			let s:search_pattern = s:gr.old_pattern[lnum - 1]
		else
			let s:start_directory = s:gr.old_directory[lnum - 1]
		endif

		call popup_close(a:winid, -1)
		return 1
	endif

	" Other, pass to normal filter
	return popup_filter_menu(a:winid, a:key)
endfunction

"*******************************************************
" Sub menu callback
"*******************************************************
function! s:sub_menu_callback(winid, result) abort
	call s:update_main_popup(s:main_popup_winid)
endfunction

"*******************************************************
" Input search pattern
"*******************************************************
function! s:input_search_pattern() abort
	let instr = input('Search pattern: ')
	echo "\r"
	if !empty(instr) | let s:search_pattern = instr | endif
endfunction

"*******************************************************
" Edit start directory
"*******************************************************
function! s:edit_start_dir() abort
	let dir = input('Search start directory: ', s:start_directory, 'dir')
	echo "\r"

	if empty(dir)
		return

	elseif isdirectory(dir)
		let dir = substitute(dir, has('unix') ? "/$" : "\$", "", "")
		let dir = fnamemodify(dir, ':p:h')
		let s:start_directory = dir

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
	let s:gr.search_filter = empty(instr) ? '*' : instr
endfunction

"*******************************************************
" Set grep option
"*******************************************************
function! s:set_grep_option(opt) abort
	let s:gr.opt = xor(s:gr.opt, a:opt)
endfunction

"*******************************************************
" Update history
"*******************************************************
function! s:update_history(list, item) abort
	let new_list = a:list
	call remove(new_list, index(a:list, a:item))
	call insert(new_list, a:item, 0)
	return new_list[0:4]
endfunction

"*******************************************************
" Run grep
"*******************************************************
function! s:run_grep() abort
	if empty(s:search_pattern) | return 1 | endif

	" Close the QuickFix. and Move latest quickfix
	cclose
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" 新しいものは履歴の先頭に追加し、古いものを捨てる
	let s:gr.old_pattern = s:update_history(s:gr.old_pattern, s:search_pattern)
	let s:gr.old_directory = s:update_history(s:gr.old_directory, s:start_directory)

	" >>> grep executing >>>.
	echohl Search | echomsg ">>> grep executing >>>" | echohl None

	" 検索開始ディレクトリに移動
	execute 'lcd '.s:start_directory

	" Run grep
	let start_time = reltime()
	silent! execute gr#grepcmd#grep_command(s:search_pattern, s:start_directory, s:gr.search_filter, s:gr.opt)
	let proc_time = substitute(reltimestr(reltime(start_time)), " ", "", "g")

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if len(getqflist())
		exe 'botright copen'
		redraw!
		set modifiable
		set nowrap
		echo len(getqflist())." hits.  (".proc_time." sec)"

		if and(s:gr.opt, 0x4)
			let @/ = and(s:gr.opt, 0x1) ? '\<' . s:search_pattern . '\>' : s:search_pattern 
			call matchadd('Search', @/)
		endif
	else
		redraw!
		echo "Search pattern not found.  (".proc_time." sec)"
	endif
endfunction

"*******************************************************
" Start grep
"*******************************************************
function! gr#start(range, start, end) abort
	let current_dir = expand('%:p:h')
	if !exists('s:gr')
		let s:gr = {}
		let s:gr.old_pattern	= ["", "", "", "", ""]
		let s:gr.old_directory	= [current_dir, getcwd(), getcwd(), getcwd(), current_dir]
		let s:gr.search_filter	= 'c,cpp'
		let s:gr.opt = 0x05
	endif

	if a:range && mode() =~# '^[vV]' 
		" ビジュアルモードで範囲選択している場合は、選択部分をgrep対象にする
		let temp = @@
		silent normal gvy
		let s:search_pattern = @@
		let @@ = temp
	else
		" 範囲選択されていない場合は、単語をgrep対象にする
		let s:search_pattern = expand('<cword>')
	endif

	" 初期検索開始ディレクトリは履歴トップのディレクトリ
	let s:start_directory = s:gr.old_directory[0]

	" 初期検索フィルタは履歴トップのフィルタ
	let s:gr.old_directory[4] = current_dir

	call s:open_main_popup(s:make_main_menu())
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

