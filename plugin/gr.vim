let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_GR')
	finish
endif
let g:loaded_GR = 1

" Grep type
if !exists('g:GR_GrepCommand')
	let g:GR_GrepCommand = 'vimgrep'
endif

if executable('rg') && g:GR_GrepCommand == 'ripgrep'
	let &grepprg = 'rg --vimgrep --hidden'
	set grepformat=%f:%l:%c:%m
endif

command! -nargs=0 -range Gr call gr#start(<range>, <line1>, <line2>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
