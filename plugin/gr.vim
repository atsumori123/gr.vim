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
	set grepprg=grep\ -nH\ $*
	" -n : 行番号を表示
	" -H : ファイル名を表示
	" $* : grepコマンドの引数をここに展開する
	set grepformat=%f:%l:%m
elseif g:GR_GrepCommand == 'git grep'
	set grepprg=git\ grep\ -I\ --line-number
	" -I : バイナリファイルを除外する
	" --line-number : 行番号を表示する
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
