let s:save_cpo = &cpoptions
set cpoptions&vim

let s:main_popup_winid = 0
let s:sub_popup_winid = 0

" gr用のハイライトグループを定義
if empty(prop_type_get('gr'))
	call prop_type_add('gr', {'highlight': 'Identifier'})
endif

"*******************************************************
" Make main menu
"*******************************************************
function! s:make_main_menu() abort
	let menu = []
	call add(menu, "(s) Search patterni   ".s:search_pattern)
	call add(menu, "(d) Directory         ".s:start_directory)
	call add(menu, "")
	call add(menu, "(f) File filter       ".s:gr["FILTER"])
	call add(menu, "(w) Word search       ".(and(s:gr["OPT"], 0x01) ? "*" : ""))
	call add(menu, "(c) Case sensitive    ".(and(s:gr["OPT"], 0x02) ? "*" : ""))
	call add(menu, "(r) Regular Exp       ".(and(s:gr["OPT"], 0x08) ? "*" : ""))
	if g:GR_GrepCommand == 'rg'
		call add(menu, "(0) Encording         ".(and(s:gr["OPT"], 0x10) ? "sijs" : "utf8"))
	endif

	return menu
endfunction

"*******************************************************
" Open main popup
"*******************************************************
function! s:open_main_popup(menu) abort
	let output = []
	for v in a:menu
		call add(output, {'text':v, 'props':[#{col: 1, length: 21, type: "gr"}]})
	endfor

	let opts = {
			\ 'border': [1,1,1,1],
			\ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
			\ 'padding': [1,2,1,2],
			\ 'minwidth':50,
			\ 'cursorline': 1,
			\ 'mapping': v:false,
			\ 'title': ' (G) '.g:GR_GrepCommand.' ',
			\ 'filter': function('s:main_menu_filter'),
			\ 'callback': function('s:main_menu_callback'),
			\ 'filtermode': 'n',
			\ 'zindex': 1
			\ }

	let s:main_popup_winid = popup_menu(output, opts)
endfunction

"*******************************************************
" Update popup menu
"*******************************************************
function! s:update_main_popup(winid) abort
	let output = []
	for v in s:make_main_menu()
		call add(output, {'text':v, 'props':[#{col: 1, length: 21, type: "gr"}]})
	endfor

	call popup_settext(a:winid, output)
	call popup_setoptions(a:winid, {'title' : ' (G) '.g:GR_GrepCommand.' '})
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
		call s:change_grepprg()
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 's' || unqkey ==# '1e'
		" Search pattern
		call s:input_search_pattern()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '1l'
		" 検索パターン履歴
		call s:open_sub_popup('Search pattern', s:gr['PATTERN'])
		return 1

	elseif a:key ==# 'd' || unqkey ==# '2e'
		" Start search directory
		call s:edit_start_dir()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '2l'
		" 検索パターン履歴
		call s:open_sub_popup('Directory', s:gr['DIR'])
		return 1

	elseif unqkey ==# '2j' || unqkey ==# '2\<DOWN>'
		" 空白行をスキップ (2行目で'j')
		call win_execute(a:winid, 'normal! 2j')
		return 1

	elseif a:key ==# 'f' || unqkey ==# '4l'
		" file filter
		call s:input_file_filter()
		call s:update_main_popup(a:winid)
		return 1

	elseif unqkey ==# '4k'
		" 空白行をスキップ (4行目で'k')
		call win_execute(a:winid, 'normal! 2k')
		return 1

	elseif a:key ==# 'w' || unqkey ==# '5l'
		" Search option (Word Search)
		call s:set_grep_option(0x01)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 'c' || unqkey ==# '6l'
		" Search option (Case-senstive)
		call s:set_grep_option(0x02)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# 'r' || unqkey ==# '7l'
		" Regular expressions
		call s:set_grep_option(0x08)
		call s:update_main_popup(a:winid)
		return 1

	elseif a:key ==# '2' || unqkey ==# '8l'
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
			\ 'border': [1,1,1,1],
			\ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
			\ 'padding': [1,2,1,2],
			\ 'cursorline': 1,
			\ 'mapping': v:false,
			\ 'title': ' '.a:title.' ',
			\ 'filter': function('s:sub_menu_filter'),
			\ 'callback': function('s:sub_menu_callback'),
			\ 'zindex': 2
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
			let s:search_pattern = s:gr["PATTERN"][lnum - 1]
		else
			let s:start_directory = s:gr["DIR"][lnum - 1]
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
	let s:gr["FILTER"] = empty(instr) ? '*' : instr
endfunction

"*******************************************************
" Set grep option
"*******************************************************
function! s:set_grep_option(opt) abort
	let s:gr["OPT"] = xor(s:gr["OPT"], a:opt)
endfunction

"*******************************************************
" Change grepprg
"*******************************************************
function! s:change_grepprg() abort
	" vimgrep --> grep"
	if g:GR_GrepCommand == 'internal'
		let g:GR_GrepCommand = 'grep'
		set grepprg=grep\ -nHRF\ --binary-files=without-match
		" -n : 行番号を表示
		" -H : ファイル名を表示
		" -R : 指定ディレクトリ以下を再帰的に検索
		" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		" --binary-files=without-match : バイナリファイルを検索対象から除外する
		set grepformat=%f:%l:%m

	" grep --> git grep"
	elseif g:GR_GrepCommand == 'grep'
		let g:GR_GrepCommand = 'git grep'
"		set grepprg=git\ grep\ -nIF\
		set grepprg=git\ grep\ -nIF\ --no-color\ --full-name
		" -n : 行番号を表示
		" -I : バイナリファイルを除外する
		" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		" ---no-color : 出力の色付けを無効にする
		" --full-name : カレントディレクトリではなく、Gitリポジトリのルートからの相対パスでファイル名を表示する
		set grepformat=%f:%l:%m

	" git grep --> ripgrep"
	elseif g:GR_GrepCommand == 'git grep'
		let g:GR_GrepCommand='rg'
		set grepprg=rg\ --vimgrep\ --hidden
		set grepformat=%f:%l:%m

	" ripgrep --> vimgrep"
	else
		let g:GR_GrepCommand = 'rg'
		let g:GR_GrepCommand='internal'
		set grepprg=internal
		set grepformat=%f:%l:%m,%f:%l%m,%f\ \ %l%m
	endif
endfunction

"*******************************************************
" make vimgrep command
"*******************************************************
function! s:make_cmd_vimgrep() abort
	" 制御コードをエスケープする
	let pattern = escape(s:search_pattern, '.^$*[]~\(){}+?')

	let cmd = 'vimgrep! '
	" Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '/\<'.pattern : '/'.pattern
	" Case-senstive
	let cmd .= and(s:gr["OPT"], 0x2) ? '\C' : '\c'
	" Word Search
	let cmd .= and(s:gr["OPT"], 0x1) ? '\>/j ' : '/j '
	" Start search directory
	let cmd .= s:start_directory
	" File filter
	let cmd .= '/ **/*.'.substitute(s:gr["FILTER"], ",", " **/*.", "g")

	return cmd
endfunction

"*******************************************************
" make grep command
"*******************************************************
function! s:make_cmd_grep() abort
	let opt = ''
	" Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? ' -w' : ''
	" Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? '' : ' -i'

	" Filter
	if stridx(s:gr["FILTER"], ',') >= 0
		let filter = ' --include=' . shellescape('*.{' . substitute(s:gr["FILTER"], ',', ',*.', 'g') . '}')
	elseif s:gr["FILTER"] != '*'
		let filter = ' --include=' . shellescape('*.' . s:gr["FILTER"])
	else
		let filter = ''
	endif

	let pattern = shellescape(s:search_pattern)
	let dir		= shellescape(s:start_directory)

	return 'grep! ' . opt . filter . ' -- ' . pattern . ' ' . dir
endfunction

"*******************************************************
" make grep git grep
"*******************************************************
function! s:make_cmd_git_grep() abort
	let opt = ''
	"Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? ' -w' : ''
	"Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? '' : ' -i'

	" Filter
	if stridx(s:gr["FILTER"], ',') >= 0
		let glob = '*.{'. substitute(s:gr["FILTER"], ',', ',*.', 'g') . '}'
	elseif s:gr["FILTER"] != '*'
		let glob = '*.' . s:gr["FILTER"]
	else
		let glob = ''
	endif

	let pattern = shellescape(s:search_pattern)
	let dir		= shellescape(s:start_directory)

	" glob はパスspec として扱われるので shellescape しない
	let glob_arg = glob ==# '' ? '' : ' -- ' . glob

	" git grep を直接呼ぶ（grepprg に邪魔されない）
    return 'grep! ' . opt . ' ' . pattern . glob_arg . ' ' . dir
endfunction

"*******************************************************
" make ripgrep command
"*******************************************************
function! s:make_cmd_ripgrep() abort
	let opt = ''
	" Word Search
	let opt .= and(s:gr["OPT"], 0x1) ? ' -w' : ''
	" Case-senstive
	let opt .= and(s:gr["OPT"], 0x2) ? '' : ' -i'
	" Disable Regular expressions
	let opt .= and(s:gr["OPT"], 0x8) ? '' : ' -F'
	" Encording(sjis/utf-8)
	let opt .= and(s:gr["OPT"], 0x10) ? ' -E sjis' : ' -E utf8'

	let pattern = shellescape(s:search_pattern)
	let glob	= shellescape('*.{' . s:gr['FILTER'] . '}')
	let dir		= shellescape(s:start_directory)

	return 'grep! ' . opt . ' -g ' . glob . ' -e ' . pattern . ' ' . dir
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
	let s:gr["PATTERN"] = s:update_history(s:gr["PATTERN"], s:search_pattern)
	let s:gr["DIR"] = s:update_history(s:gr["DIR"], s:start_directory)

	" >>> grep executing >>>.
	echohl Search | echomsg ">>> grep executing >>>" | echohl None

	" 検索開始ディレクトリに移動
	execute 'lcd '.s:start_directory

	" Run grep
	let start_time = reltime()
	if g:GR_GrepCommand == 'rg'
		silent! execute s:make_cmd_ripgrep()
	elseif g:GR_GrepCommand == 'grep'
		silent! execute s:make_cmd_grep()
	elseif g:GR_GrepCommand == 'git grep'
		silent! execute s:make_cmd_git_grep()
	else
		silent! execute s:make_cmd_vimgrep()
	endif
	let proc_time = substitute(reltimestr(reltime(start_time)), " ", "", "g")

	" If there is a hit as a result of the search, display the QuickFix and set it to be rewritable.
	if len(getqflist())
		exe 'botright copen'
		redraw!
		set modifiable
		set nowrap
		echo len(getqflist())." hits.  (".proc_time." sec)"
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
		let s:gr["PATTERN"] = ["", "", "", "", ""]
		let s:gr["DIR"] = [current_dir, getcwd(), getcwd(), getcwd(), current_dir]
		let s:gr["FILTER"] = 'c,cpp'
		let s:gr["OPT"] = 0x03
	endif

	if a:range
		let temp = @@
		silent normal gvy
		let s:search_pattern = @@
		let @@ = temp
	else
		let s:search_pattern = expand('<cword>')
	endif

	let s:start_directory = s:gr["DIR"][0]
	let s:gr["DIR"][4] = current_dir

	call s:open_main_popup(s:make_main_menu())
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

