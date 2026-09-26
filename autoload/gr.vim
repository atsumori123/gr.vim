let s:save_cpo = &cpoptions
set cpoptions&vim

let s:menu = []
let s:m_id = ""
let s:match_id = 0
let s:match_winid = 0

" gr用のハイライトグループを定義
if empty(prop_type_get('gr'))
	call prop_type_add('gr', {'highlight': 'Identifier'})
endif

"-------------------------------------------------------
" msg
"-------------------------------------------------------
function! s:msg(hl, msg) abort
	execute 'echohl ' . a:hl | echo a:msg | echohl None
endfunction

"-------------------------------------------------------
" str2dic
"-------------------------------------------------------
function! s:str2dic(a, b) abort
	return {'text': a:a . a:b, 'props': [#{col: 1, length: len(a:a), type: 'gr'}]}
endfunction

"-------------------------------------------------------
" get_item
"-------------------------------------------------------
function! s:get_item(key) abort
	return get(s:gr, a:key, -1)
endfunction

"-------------------------------------------------------
" make_menu
"-------------------------------------------------------
function! s:make_menu() abort
	let menu = []

	" 検索パターン
	call add(menu, s:str2dic('p. ', s:gr.p.value))

	" 検索開始ディレクトリ
	call add(menu, s:str2dic('d. ', s:gr.d.value))

	" 検索フィルタ
	call add(menu, s:str2dic('f. ', s:gr.f.value))

	" 区切り
	call add(menu, s:str2dic("", ""))

	" 単語検索
	call add(menu, s:str2dic(printf("%-15s", 'w. Word'), gr#is_opt('w') ? "*" : ""))

	" 大文字/小文字
	call add(menu, s:str2dic(printf("%-15s", 'i. Ignorecase'), gr#is_opt('i') ? "*" : ""))

	" 検索パターンのハイライト
	call add(menu, s:str2dic(printf("%-15s", 'h. Highlight'), gr#is_opt('h') ? "*" : ""))

	" エンコード(rgのみ)
	if g:gr_grepprg ==# 'rg'
		call add(menu, s:str2dic(printf("%-15s", '2. Encoding'), gr#is_opt('e') ? "*" : ""))
	endif

	let s:m_id = "m"

	return menu
endfunction

"-------------------------------------------------------
" open_popup
"-------------------------------------------------------
function! s:open_popup() abort
	let s:menu = s:make_menu()

	let opts = {
			\ 'border'		: [1,1,1,1],
			\ 'borderchars'	: has('unix') ? [] : ['─','│','─','│','┌','┐','┘','└'],
			\ 'padding'		: [1,2,1,2],
			\ 'minwidth'	: 50,
			\ 'cursorline'	: 1,
			\ 'mapping'		: v:false,
			\ 'title'		: printf(" G. %s ", g:gr_grepprg),
			\ 'filter'		: function('s:popup_filter'),
			\ 'callback'	: function('s:popup_callback'),
			\ 'filtermode'	: 'n',
			\ 'zindex'		: 1
			\ }

	let _ = popup_menu(s:menu, opts)
endfunction

"-------------------------------------------------------
" rerender_popup
"-------------------------------------------------------
function! s:rerender_popup(winid, cursor_pos) abort
	" メニューを作成
	let s:menu = s:make_menu()

	" タイトルとメニューをバッファに設定
	call popup_settext(a:winid, s:menu)
	call popup_setoptions(a:winid, {'title' : printf(" G. %s ", g:gr_grepprg)})

	" カーソルを指定のポジションに設定
	call win_execute(a:winid, printf("call cursor(%d, 1)", a:cursor_pos))
endfunction

"-------------------------------------------------------
" show_history
"-------------------------------------------------------
function! s:show_history(winid, key, title) abort
	" 指定されたキーの要素を取得
	let item = s:get_item(a:key)
	if type(item) != v:t_dict | return | endif

	" 画面IDを更新
	let s:m_id = a:key

	" リストをコピーしてメニューの高さになるように不足行を補う
	let list = copy(item.old)
	for i in range(len(item.old), len(s:menu) - 1 , 1)
		call add(list, "")
	endfor

	" タイトルとメニューを表示
	call popup_settext(a:winid, list)
	call popup_setoptions(a:winid, {'title' : printf(" %s history ", a:title)})

	" カーソルを1行目に設定
	call win_execute(a:winid, 'call cursor(1, 1)')
endfunction

"-------------------------------------------------------
" popup_filter
"-------------------------------------------------------
function! s:popup_filter(winid, key) abort
	" CRキーは'l'に化かす
	let key  = a:key ==# "\<CR>" ? "l" : a:key

	" 行番号とキーを組み合わせてユニークなキーコードをつくる
	call win_execute(a:winid, 'let w:lnum = line(".")')
	let lnum = getwinvar(a:winid, 'lnum', 0)
	let unqkey = lnum . key

	if s:m_id ==# 'm'
		if key ==# 'q'								" Exit
			call popup_close(a:winid, -1)
			return 1

		elseif key ==# 'g'							" grep
			" Run grep
			call popup_close(a:winid, 0)
			return 1

		elseif key ==# 'G'							" grepprgの切り替え
			call gr#grepcmd#change_grepprg()
			call s:rerender_popup(a:winid, 1)
			return 1

		elseif key ==# 'p' || unqkey ==# '1e'		" 検索パターン
			call s:input_search_pattern(a:winid)
			return 1

		elseif unqkey ==# '1l'						" 検索パターン履歴
			call s:show_history(a:winid, 'p', 'Search pattern')
			return 1

		elseif key ==# 'd' || unqkey ==# '2e'		" 検索開始ディレクトリ
			call s:input_start_directory(a:winid)
			return 1

		elseif unqkey ==# '2l'						" 検索開始ディレクトリ履歴
			call s:show_history(a:winid, 'd', 'Start directory')
			return 1

		elseif unqkey ==# '3j'						" 空白行をスキップ (2行目で'j')
			call win_execute(a:winid, 'normal! 2j')
			return 1

		elseif key ==# 'f' || unqkey ==# '3e'		" 検索フィルタ
			call s:input_file_filter(a:winid)
			return 1

		elseif unqkey ==# '3l'						" 検索フィルタ
			call s:show_history(a:winid, 'f', 'File filter')
			return 1

		elseif unqkey ==# '5k'						" 空白行をスキップ (4行目で'k')
			call win_execute(a:winid, 'normal! 2k')
			return 1

		elseif key ==# 'w' || unqkey ==# '5l'		" 単語検索
			call s:toggle_option(a:winid, 'w')
			return 1

		elseif key ==# 'i' || unqkey ==# '6l'		" 大文字小文字
			call s:toggle_option(a:winid, 'i')
			return 1

		elseif key ==# 'h' || unqkey ==# '7l'		" hlsearch
			call s:toggle_option(a:winid, 'h')
			return 1

		elseif key ==# '2' || unqkey ==# '8l'		" Encoding
			call s:toggle_option(a:winid, 'e')
			return 1
		endif

	else
		if key ==# 'h' || key ==# 'q'
			let item = s:get_item(s:m_id)
			if type(item) == v:t_dict
				call s:rerender_popup(a:winid, item.no)
			endif
			return 1

		elseif key ==# 'l'
			let item = s:get_item(s:m_id)
			if type(item) == v:t_dict
				let item.value = get(item.old, lnum - 1, "")
				call s:rerender_popup(a:winid, item.no)
			endif
			return 1

		elseif key ==# 'j' || key ==# 'k'
			let item = s:get_item(s:m_id)
			if type(item) == v:t_dict
				let next = lnum + (key ==# 'j' ? 1 : -1)
				let next = len(item.old) < next ? 1 : next < 1 ? len(item.old) : next
				call win_execute(a:winid, printf("call cursor(%d, 1)", next))
			endif
			return 1
		endif
	endif

	" Other, pass to normal filter
	return popup_filter_menu(a:winid, a:key)
endfunction

"-------------------------------------------------------
" popup_callback
"-------------------------------------------------------
function! s:popup_callback(winid, result) abort
	if a:result == 0	"Run grep
		call s:run_grep()
	endif
endfunction

"-------------------------------------------------------
" input_search_pattern
"-------------------------------------------------------
function! s:input_search_pattern(winid) abort
	let item = s:get_item('p')
	if type(item) != v:t_dict | return | endif

	let instr = input('Search pattern: ', item.value)
	echo "\r" | echo ""

	" 入力なしの場合は処理を中断
	if empty(instr) | return | endif

	" 検索パターンを更新
	let item.value = instr

	" メニューを更新
	let s:menu[item.no - 1].text = s:menu[item.no - 1].text[:2] . item.value
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" input_start_directory
"-------------------------------------------------------
function! s:input_start_directory(winid) abort
	let item = s:get_item('d')
	if type(item) != v:t_dict | return | endif

	let dir = input('Search start directory: ', item.value, 'dir')
	echo "\r" | echo ""

	" 入力なしの場合は処理を中断
	if empty(dir) | return | endif

	" 入力したディレクトリが存在するかチェック
	if !isdirectory(dir)
		call s:msg("WarningMsg", 'Error: ' . dir . " doesn't exist")
		return
	endif

	" 検索開始ディレクトリを更新
	let dir = substitute(dir, has('unix') ? "/$" : "\$", "", "")
	let dir = fnamemodify(dir, ':p:h')
	let item.value = dir

	" メニューを更新
	let s:menu[item.no - 1].text = s:menu[item.no - 1].text[:2] . item.value
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" input_file_filter
"-------------------------------------------------------
function! s:input_file_filter(winid) abort
	let item = s:get_item('f')
	if type(item) != v:t_dict | return | endif

	let instr = input('Search in files matching pattern: ')
	echo "\r" | echo ""

	" 入力なしの場合は処理を中断
	if empty(instr) | return | endif

	" 検索フィルタを更新
	let item.value = empty(instr) ? '*' : instr

	" メニューを更新
	let s:menu[item.no - 1].text = s:menu[item.no - 1].text[:2] . item.value
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" toggle_option
"-------------------------------------------------------
function! s:toggle_option(winid, key) abort
	let item = s:get_item(a:key)
	if type(item) != v:t_dict | return | endif

	" 設定を反転
	let item.value = xor(item.value, 1)

	" メニューを更新
	let s:menu[item.no -1].text = s:menu[item.no -1].text[:14] . (item.value ? '*' : '')
	call popup_settext(a:winid, s:menu)
endfunction

"-------------------------------------------------------
" update_history
"-------------------------------------------------------
function! s:update_history() abort
	for key in ['p', 'd', 'f']
		let item = s:get_item(key)
		if type(item) != v:t_dict | continue | endif

		let new_list = copy(item.old)

		" 同一要素を削除
		call filter(new_list, 'v:val !=# item.value')

		" 先頭に追加
		call insert(new_list, item.value, 0)

		" 最大 5 個まで保持
		let item.old = new_list[:4]
	endfor
endfunction

"-------------------------------------------------------
" clear_match
"-------------------------------------------------------
function! s:clear_match() abort
	if s:match_id != 0
		if win_id2win(s:match_winid) != 0
			call matchdelete(s:match_id, s:match_winid)
		endif
		let s:match_id = 0
		let s:match_winid = 0
	endif
endfunction

"-------------------------------------------------------
" Run grep
"-------------------------------------------------------
function! s:run_grep() abort
	" 検索パターンが空の場合は中断
	if empty(s:gr.p.value)
		call s:msg("WarningMsg", "No search pattern")
		return 1
	endif

	" Close the QuickFix. and Move latest quickfix
	cclose
	let cnew_count = getqflist({'nr':'$'}).nr - getqflist({'nr':0}).nr
	if cnew_count
		execute printf('cnew %d', cnew_count)
	endif

	" 新しいものは履歴の先頭に追加し、古いものを捨てる
	call s:update_history()

	" >>> grep executing >>>.
	call s:msg("Search", ">>> grep executing >>>")

	" 検索開始ディレクトリに移動
	execute 'lcd '.s:gr.d.value

	" Run grep
	let start_time = reltime()
	silent! execute gr#grepcmd#grep(s:gr.p.value , s:gr.d.value , s:gr.f.value)
	let proc_time = substitute(reltimestr(reltime(start_time)), " ", "", "g")

	" ヒット件数を取得
	let hit_count = getqflist({'size': 1}).size

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if hit_count
		" quicfixウィンドウを開く
		execute 'botright copen'

		" ハイライト消去用augroupを定義
		augroup gr_quickfix_match
			autocmd!
			autocmd BufWinLeave <buffer> call <SID>clear_match()
		augroup END

		" バッファ設定
		set modifiable
		set nowrap

		call s:msg('Special', printf(" %d hits. (%s sec)", hit_count, proc_time))

		" ハイライトが有効の場合の設定
		if gr#is_opt('h')
			let @/ = gr#is_opt('w') ? '\<' . s:gr.p.value . '\>' : s:gr.p.value
			let s:match_winid = win_getid()
			let s:match_id = matchadd('Special', @/)
		endif
	else
		call s:msg("WarningMsg", printf("Search pattern not found. (%s sec)", proc_time))
	endif
endfunction

"-------------------------------------------------------
" gr#is_opt
"-------------------------------------------------------
function! gr#is_opt(key) abort
	let item = s:get_item(a:key)
	if type(item) != v:t_dict | return 0 | endif

	return item.value
endfunction

"-------------------------------------------------------
" gr#start
"-------------------------------------------------------
function! gr#start(range, start, end) abort
	let current_dir = expand('%:p:h')
	let ext = expand('%:e')
	if !exists('s:gr')
		let s:gr = {}
		let s:gr.p = {'no':1, 'value':'', 'old': []}
		let s:gr.d = {'no':2, 'value':'', 'old': [current_dir]}
		let s:gr.f = {'no':3, 'value':'', 'old': [(empty(ext) ? '*' : ext), 'c,cpp', 'h', 'vim', '*']}
		let s:gr.w = {'no':5, 'value':1}
		let s:gr.i = {'no':6, 'value':0}
		let s:gr.h = {'no':7, 'value':0}
		let s:gr.e = {'no':8, 'value':0}
	endif

	if a:range
		" ビジュアルモードで範囲選択している場合は、選択部分をgrep対象にする
		let temp = @@
		silent normal gvy
		let s:gr.p.value = @@
		let @@ = temp
	else
		" 範囲選択されていない場合は、単語をgrep対象にする
		let s:gr.p.value = expand('<cword>')
	endif

	" 初期検索開始ディレクトリは履歴トップのディレクトリ
	let s:gr.d.value = s:gr.d.old[0]

	" 初期検索フィルタは履歴トップのフィルタ
	let s:gr.f.value = s:gr.f.old[0]

	" カレントディレクトリを履歴に追加する
	if index(s:gr.d.old, current_dir) < 0
		let s:gr.d.old = s:gr.d.old[:3]
		call add(s:gr.d.old, current_dir)
	endif

	" ポップアップを表示
	call s:open_popup()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

