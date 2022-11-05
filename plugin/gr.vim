let s:save_cpo = &cpoptions
set cpoptions&vim

if exists('g:loaded_gr')
	finish
endif
let g:loaded_gr = 1

if !exists('g:GR')
	let g:GR = {}
	let g:GR['search_pattern'] = ""
	let g:GR['start_dir'] = [getcwd(), getcwd(), getcwd(), getcwd(), getcwd()]
	let g:GR['filter'] = "c,cpp"
	let g:GR['option'] = 7
endif

" Grep type
if !exists('g:Gr_Grep_Proc')
	let g:Gr_Grep_Proc = 'vimgrep'
elseif g:Gr_Grep_Proc == 'ripgrep'&& executable('rg')
	let &grepprg = 'rg --vimgrep --hidden'
	set grepformat=%f:%l:%c:%m
elseif g:Gr_Grep_Proc != 'grep' && g:Gr_Grep_Proc != 'vimgrep'
	let g:Gr_Grep_Proc = 'vimgrep'
endif

command! -nargs=0 -range Gr call gr#Gr(<range>, <line1>, <line2>)

let &cpoptions = s:save_cpo
unlet s:save_cpo
