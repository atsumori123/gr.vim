let s:save_cpo = &cpoptions
set cpoptions&vim

let s:main_popup_winid = 0
let s:sub_popup_winid = 0
let s:opttbl = {'word' : 0x01, 'ignorecase' : 0x02, 'highlight' : 0x04, 'encoding' : 0x08}
let s:menu = []

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

"-------------------------------------------------------
" make_menu
"-------------------------------------------------------
function! s:make_menu() abort
	let menu = []

	" 検索パターン
	call add(menu, s:set_property('p. ' . s:search_pattern, 2))

	" 検索開始ディレクトリ
	call add(menu, s:set_property('d. ' . s:start_directory, 2))

	" 検索フィルタ
	call add(menu, s:set_property('f. ' . s:file_filter, 2))

	" 区切り
	call add(menu, s:set_property("", 0))

	" 単語検索
	call add(menu, s:set_property(printf("%-15s%s", 'w. Word', gr#is_opt('word') ? "*" : ""), 15))

	" 大文字/小文字
	call add(menu, s:set_property(printf("%-15s%s", 'i. Ignorecase', gr#is_opt('ignorecase') ? "*" : ""), 15))

	" 検索パターンのハイライト
	call add(menu, s:set_property(printf("%-15s%s", '1. Highlight', gr#is_opt('highlight') ? "*" : ""), 15))

	" エンコード(rgのみ)
	if g:gr_grep_command ==# 'rg'
		call add(menu, s:set_property(printf("%-15s%s", '2. Encoding', gr#is_opt('encoding') ? "*" : ""), 15))
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
	let s:menu = s:make_menu()

	call popup_settext(a:winid, s:menu)
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

	elseif a:key ==# 'p' || unqkey ==# '1e'		" 検索パターン
		call s:input_search_pattern(a:winid)
		return 1

	elseif unqkey ==# '1l'
		" 検索パターン履歴
		call s:open_sub_popup('Search pattern', s:gr.old_pattern)
		return 1

	elseif a:key ==# 'd' || unqkey ==# '2e'		" 検索開始ディレクトリ
		call s:input_start_directory(a:winid)
		return 1

	elseif unqkey ==# '2l'
		" 検索パターン履歴
		call s:open_sub_popup('Directory', s:gr.old_directory)
		return 1

	elseif unqkey ==# '3j' || unqkey ==# '3\<DOWN>'
		" 空白行をスキップ (2行目で'j')
		call win_execute(a:winid, 'normal! 2j')
		return 1

	elseif a:key ==# 'f' || unqkey ==# '3l'		" 検索フィルタ
		call s:input_file_filter(a:winid)
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

	elseif a:key ==# '1' || unqkey ==# '7l'
		" hlsearch option
		call s:set_grep_option(0x04)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# '2' || unqkey ==# '8l'
		" Encoding
		call s:set_grep_option(0x08)
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

"-------------------------------------------------------
" input_search_pattern
"-------------------------------------------------------
function! s:input_search_pattern(winid) abort
	let instr = input('Search pattern: ')
	echo "\r" | echo ""

	" 入力なしの場合は処理を中断
	if empty(instr) | return | endif

	" 検索パターンを更新
	let s:search_pattern = instr

	" メニューを更新
	let s:menu[0].text = s:menu[0].text[:2] . s:search_pattern
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" input_start_directory
"-------------------------------------------------------
function! s:input_start_directory(winid) abort
	let dir = input('Search start directory: ', s:start_directory, 'dir')
	echo "\r" | echo ""

	" 入力なしの場合は処理を中断
	if empty(dir) | return | endif

	" 入力したディレクトリが存在するかチェック
	if !isdirectory(dir)
		echohl WarningMsg | echomsg 'Error: ' . dir . " doesn't exist" | echohl None
		return
	endif

	" 検索開始ディレクトリを更新
	let dir = substitute(dir, has('unix') ? "/$" : "\$", "", "")
	let dir = fnamemodify(dir, ':p:h')
	let s:start_directory = dir

	" メニューを更新
	let s:menu[1].text = s:menu[1].text[:2] . s:start_directory
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" input_file_filter
"-------------------------------------------------------
function! s:input_file_filter(winid) abort
	let instr = input('Search in files matching pattern: ')
	echo "\r" | echo ""

	" 入力なしの場合は全ファイルが対象
	let s:file_filter = empty(instr) ? '*' : instr

	" メニューを更新
	let s:menu[2].text = s:menu[2].text[:2] . s:file_filter
	call popup_settext(a:winid, s:menu)
endfunction

"*******************************************************
" Set grep option
"*******************************************************
function! s:set_grep_option(opt) abort
	let s:gr.opt = xor(s:gr.opt, a:opt)
endfunction

"-------------------------------------------------------
" update_history
"-------------------------------------------------------
function! s:update_history(list, item) abort
	let new_list = copy(a:list)

	" 既存の同一要素を削除
	call filter(new_list, 'v:val !=# a:item')

	" 先頭に追加
	call insert(new_list, a:item, 0)

	" 最大 5 個まで保持
	return new_list[:4]
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
	let s:gr.old_filter	 = s:update_history(s:gr.old_filter, s:file_filter)

	" >>> grep executing >>>.
	echohl Search | echomsg ">>> grep executing >>>" | echohl None

	" 検索開始ディレクトリに移動
	execute 'lcd '.s:start_directory

	" Run grep
	let start_time = reltime()
	silent! execute gr#grepcmd#grep_command(s:search_pattern, s:start_directory, s:file_filter, s:gr.opt)
	let proc_time = substitute(reltimestr(reltime(start_time)), " ", "", "g")

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if len(getqflist())
		exe 'botright copen'
		redraw!
		set modifiable
		set nowrap
		echo len(getqflist())." hits.  (".proc_time." sec)"

		if gr#is_opt('highlight')
			let @/ = gr#is_opt('word') ? '\<' . s:search_pattern . '\>' : s:search_pattern 
			call matchadd('Search', @/)
		endif
	else
		redraw!
		echo "Search pattern not found.  (".proc_time." sec)"
	endif
endfunction

"-------------------------------------------------------
" gr#is_opt
"-------------------------------------------------------
function! gr#is_opt(opt) abort
	let v = get(s:opttbl, a:opt, -1)
	if v == -1 | return 0 | endif
	return and(s:gr.opt, v)
endfunction

"-------------------------------------------------------
" gr#start
"-------------------------------------------------------
function! gr#start(range, start, end) abort
	let current_dir = expand('%:p:h')
	let ext = expand('%:e')
	if !exists('s:gr')
		let s:gr = {}
		let s:gr.old_pattern	= ["", "", "", "", ""]
		let s:gr.old_directory	= [current_dir, getcwd(), getcwd(), getcwd(), current_dir]
		let s:gr.old_filter		= [(empty(ext) ? '*' : ext), 'c,cpp', 'h', 'vim']
		let s:gr.opt			= (s:opttbl.word + s:opttbl.highlight)
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
	let s:file_filter = s:gr.old_filter[0]

	" 初期検索フィルタは履歴トップのフィルタ
	let s:gr.old_directory[4] = current_dir

	let s:menu = s:make_menu()

	call s:open_main_popup(s:menu)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

