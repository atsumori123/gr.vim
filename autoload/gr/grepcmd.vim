let s:save_cpo = &cpoptions
set cpoptions&vim

"-------------------------------------------------------
" make vimgrep command
"-------------------------------------------------------
function! s:make_vimgrep_cmd(search_pattern, start_directory, filter, option) abort
	" 制御コードをエスケープする
	let p = escape(a:search_pattern, '.^$*[]~\(){}+?')

	let cmd = 'vimgrep! '
	" Word Search
	let cmd .= and(a:option, 0x1) ? '/\<' . p : '/'. p
	" Ignore case
	let cmd .= and(a:option, 0x2) ? '\c' : '\C'
	" Word Search
	let cmd .= and(a:option, 0x1) ? '\>/j ' : '/j '
	" Start search directory
	let cmd .= a:start_directory
	" File filter
	let cmd .= '/ **/*.'.substitute(a:filter, ",", " **/*.", "g")

	return cmd
endfunction

"-------------------------------------------------------
" make grep command
"-------------------------------------------------------
function! s:make_grep_cmd(search_pattern, start_directory, filter, option) abort
	let o = ''
	" Word Search
	let o .= and(a:option, 0x1) ? ' -w' : ''
	" Ignore case
	let o .= and(a:option, 0x2) ? ' -i' : ' -F'

	" Filter
	if stridx(a:filter, ',') >= 0
		let f = " --include={*.".substitute(a:filter, ",", ",*.", "g")."}"
	elseif a:filter != '*'
		let f = ' --include=' . shellescape('*.' . a:filter)
	else
		let f = ''
	endif

	let p = shellescape(a:search_pattern)
	let d = shellescape(a:start_directory)

	return 'grep! ' . o . f . ' -- ' . p . ' ' . d
endfunction

"-------------------------------------------------------
" make grep git grep
"-------------------------------------------------------
function! s:make_gitgrep_cmd(search_pattern, start_directory, filter, option) abort
	let o = ''
	"Word Search
	let o .= and(a:option, 0x1) ? ' -w' : ''
	" Ignore case
	let o .= and(a:option, 0x2) ? ' -i' : ' -F'

	" Filter
	let f = ''
	if a:filter != '*'
		let sep = has('unix') ? '/' : '\'
		let s = split(a:filter, ',')
		for ext in s
			let  f.= ' ' . a:start_directory . sep . '*.' . ext
		endfor
	els
		let f .= ' ' . a:start_directory
	endif
	let f = f ==# '' ? '' : ' -- ' . f

	let p = shellescape(a:search_pattern)

    return 'grep! ' . o . ' ' . p . f
endfunction

"-------------------------------------------------------
" make ripgrep command
"-------------------------------------------------------
function! s:make_rg_cmd() abort
	let o = ''
	" Word Search
	let o .= and(a:option, 0x1) ? ' -w' : ''
	" Ignore case
	let o .= and(a:option, 0x2) ? ' -i' : ''
	" Disable Regular expressions
	let o .= and(a:option, 0x8) ? '' : ' -F'
	" Encording(sjis/utf-8)
	let o .= and(a:option, 0x10) ? ' -E sjis' : ' -E utf8'

	let p = shellescape(a:search_pattern)
	let f = shellescape('*.{' . a:option . '}')
	let d = shellescape(a:start_directory)

	return 'grep! ' . o . ' -g ' . f . ' -e ' . p . ' ' . d
endfunction

"-------------------------------------------------------
" Change grepprg
"-------------------------------------------------------
function! gr#grepcmd#change_grepprg() abort
	" vimgrep --> grep"
	if g:GR_GrepCommand == 'internal'
		let g:GR_GrepCommand = 'grep'
		set grepprg=grep\ -nHR\ --binary-files=without-match
		" -n : 行番号を表示
		" -H : ファイル名を表示
		" -R : 指定ディレクトリ以下を再帰的に検索
		" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
		" --binary-files=without-match : バイナリファイルを検索対象から除外する
		set grepformat=%f:%l:%m

	" grep --> git grep"
	elseif g:GR_GrepCommand == 'grep'
		let g:GR_GrepCommand = 'git grep'
		set grepprg=git\ grep\ -nI\ --no-color
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

"-------------------------------------------------------
" Make grep command
"-------------------------------------------------------
function! gr#grepcmd#grep_command(search_pattern, start_directory, filter, option) abort
	if g:GR_GrepCommand ==# "grep"
		let Func = function('s:make_grep_cmd')
	elseif g:GR_GrepCommand ==# "gitgrep"
		let Func = function('s:make_gitgrep_cmd')
	elseif g:GR_GrepCommand ==# "rg"
		let Func = function('s:make_rg_cmd')
	else
		let Func = function('s:make_vimgrep_cmd')
	end

	return Func(a:search_pattern, a:start_directory, a:filter, a:option)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

