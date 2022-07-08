if exists('g:loaded_gr')
	finish
endif
let g:loaded_gr = 1

" start directory
if !exists('g:GREPDIR')
	let g:GREPDIR= [getcwd(), getcwd(), getcwd(), getcwd(), getcwd()]
else
	for i in range(len(g:GREPDIR), 5)
		call add(g:GREPDIR, getcwd)
	endfor
endif

" File filter
if !exists('g:GREPFILTER')
	let g:GREPFLT = 'c,cpp'
endif

" Search option
if !exists('g:GREPOPT')
	let g:GREPOPT = 7
endif

" Popup menu
if !exists('g:Gr_Popup_Enabled')
	let g:Gr_Popup_Enabled = 0
endif

" Grep type
if !exists('g:Gr_Grep_Proc')
	let g:Gr_Grep_Proc = 'vimgrep'
endif

if executable('rg') && g:Gr_Grep_Proc == 'rg'
    let &grepprg = 'rg --vimgrep --hidden'
	set grepformat=%f:%l:%c:%m
endif

command! -nargs=0 -range Gr call Gr(<range>, <line1>, <line2>)

