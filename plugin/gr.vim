let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_GR')
	finish
endif
let g:loaded_GR = 1

" Grep type
if !exists('g:GR_GrepCommand')
	let g:GR_GrepCommand = 'internal'
endif

" Set grepprg & grepformat
if g:GR_GrepCommand == 'grep'
	set grepprg=grep\ -nHRF\ --binary-files=without-match
	" -n : 行番号を表示
	" -H : ファイル名を表示
	" -R : 指定ディレクトリ以下を再帰的に検索
	" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
	" --binary-files=without-match : バイナリファイルを検索対象から除外する
	set grepformat=%f:%l:%m
elseif g:GR_GrepCommand == 'git grep'
"	set grepprg=git\ grep\ -n\ --no-color\ --fixed-strings\ --full-name\ --recurse-submodules\ --
	set grepprg=git\ grep\ -nIF\ --no-color\ --full-name
	" -n : 行番号を表示
	" -I : バイナリファイルを除外する
	" -F-: 検索語を正規表現ではなく、ただの文字列として扱う
	" ---no-color : 出力の色付けを無効にする
	" --full-name : カレントディレクトリではなく、Gitリポジトリのルートからの相対パスでファイル名を表示する
	set grepformat=%f:%l:%m
elseif g:GR_GrepCommand == 'rg'
	set grepprg=rg\ --vimgrep\ --hidden
	set grepformat=%f:%l:%m
else
	set grepprg=internal
	set grepformat=%f:%l:%m,%f:%l%m,%f\ \ %l%m
endif

command! -nargs=0 -range Gr call gr#start(<range>, <line1>, <line2>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
