let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" make vimgrep command
"-------------------------------------------------------
function! s:make_vimgrep_cmd(search_pattern, start_directory, file_filter) abort
	" 制御コードをエスケープする
	let p = escape(a:search_pattern, "\'\",.^$*[]~\(){}+?")

	let cmd = 'vimgrep! '
	" Word Search
	let cmd .= gr#is_opt('w') ? '/\<' . p : '/'. p
	" Ignore case
	let cmd .= gr#is_opt('i') ? '\c' : '\C'
	" Word Search
	let cmd .= gr#is_opt('w') ? '\>/j ' : '/j '
	" Start search directory
	let cmd .= fnameescape(a:start_directory)
	" File filter
	let cmd .= '/ **/*.'.substitute(a:file_filter, ",", " **/*.", "g")

	return cmd
endfunction

"-------------------------------------------------------
" make grep command
"-------------------------------------------------------
function! s:make_grep_cmd(search_pattern, start_directory, file_filter) abort
	let o = ''
	" Word Search
	let o .= gr#is_opt('w') ? ' -w' : ''
	" Ignore case
	let o .= gr#is_opt('i') ? ' -i' : ' -F'

	" File_Filter
	if stridx(a:file_filter, ',') >= 0
		let f = " --include={*.".substitute(a:file_filter, ",", ",*.", "g")."}"
	elseif a:file_filter != '*'
		let f = ' --include=*.' . a:file_filter
	else
		let f = ''
	endif

	let p = a:search_pattern
	let d = a:start_directory

	return 'grep! ' . o . f . ' -- ' . p . ' ' . d
endfunction

"-------------------------------------------------------
" make grep git grep
"-------------------------------------------------------
function! s:make_gitgrep_cmd(search_pattern, start_directory, file_filter) abort
	let o = ''
	"Word Search
	let o .= gr#is_opt('w') ? ' -w' : ''
	" Ignore case
	let o .= gr#is_opt('i') ? ' -i' : ' -F'

	" File filter
	let f = ''
	if a:file_filter != '*'
		let sep = has('unix') ? '/' : '/'
		let s = split(a:file_filter, ',')
		for ext in s
			let  f .= ' ' . a:start_directory . sep . '*.' . ext
		endfor
	els
		let f .= ' ' . a:start_directory
	endif
	let f = f ==# '' ? '' : ' -- ' . f

	let p = a:search_pattern

    return 'grep! ' . o . ' ' . p . f
endfunction

"-------------------------------------------------------
" make ripgrep command
"-------------------------------------------------------
function! s:make_ripgrep_cmd(search_pattern, start_directory, file_filter) abort
	let o = ''
	" Word Search
	let o .= gr#is_opt('w') ? ' -w' : ''
	" Ignore case
	let o .= gr#is_opt('i') ? ' -i' : ''
	" Encording(sjis/utf-8)
	let o .= gr#is_opt('e') ? ' -E sjis' : ' -E utf8'

	let p = a:search_pattern
	let f = '*.{' . a:file_filter . '}'
	let d = a:start_directory

	return 'grep! ' . o . ' -g ' . f . ' -e ' . p . ' ' . d
endfunction

"-------------------------------------------------------
" Change grepprg
"-------------------------------------------------------
function! gr#grepcmd#change_grepprg() abort
	" vimgrep --> grep"
	if g:gr_grepprg == 'vim grep'
		let g:gr_grepprg = 'grep'
		set grepprg=grep\ -nHR\ --binary-files=without-match
		" -n : 行番号を表示
		" -H : ファイル名を表示
		" -R : 指定ディレクトリ以下を再帰的に検索
		" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		" --binary-files=without-match : バイナリファイルを検索対象から除外する
		set grepformat=%f:%l:%m

	" grep --> git grep"
	elseif g:gr_grepprg == 'grep'
		let g:gr_grepprg = 'git grep'
		set grepprg=git\ grep\ -nI\ --no-color
		" -n : 行番号を表示
		" -I : バイナリファイルを除外する
		" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		" ---no-color : 出力の色付けを無効にする
		" --full-name : カレントディレクトリではなく、Gitリポジトリのルートからの相対パスでファイル名を表示する
		set grepformat=%f:%l:%m

	" git grep --> ripgrep"
	elseif g:gr_grepprg == 'git grep'
		let g:gr_grepprg='rip grep'
		set grepprg=rg\ --vimgrep\ --hidden
		set grepformat=%f:%l:%m

	" ripgrep --> vimgrep"
	else
		let g:gr_grepprg='vim grep'
		set grepprg=internal
		set grepformat=%f:%l:%m,%f:%l%m,%f\ \ %l%m
	endif
endfunction

"-------------------------------------------------------
" Make grep command
"-------------------------------------------------------
function! gr#grepcmd#grep(search_pattern, start_directory, file_filter) abort
	if g:gr_grepprg ==# "grep"
		let Func = function('s:make_grep_cmd')
	elseif g:gr_grepprg ==# "git grep"
		let Func = function('s:make_gitgrep_cmd')
	elseif g:gr_grepprg ==# "rip grep"
		let Func = function('s:make_ripgrep_cmd')
	else
		let Func = function('s:make_vimgrep_cmd')
	end

	return Func(a:search_pattern, a:start_directory, a:file_filter)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

