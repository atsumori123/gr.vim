let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_gr')
	finish
endif
let g:loaded_gr = 1

if !exists('g:GR')
	let g:GR = {}
	let g:GR["DIR"] = [getcwd(), getcwd(), getcwd(), getcwd(), getcwd()]
	let g:GR["FILTER"] = 'c,cpp'
	let g:GR["OPT"] = 0x07
endif

" Grep type
if !exists('g:Gr_Grep_Proc')
	let g:Gr_Grep_Proc = 'vimgrep'
endif

if executable('rg') && g:Gr_Grep_Proc == 'rg'
    let &grepprg = 'rg --vimgrep --hidden'
	set grepformat=%f:%l:%c:%m
endif

command! -nargs=0 -range Gr call Gr#Gr(<range>, <line1>, <line2>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
