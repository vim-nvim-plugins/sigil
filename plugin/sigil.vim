" sigil.vim - Variable panel for Vim  github.com/vim-nvim-plugins/sigil
" :Sigil  :SigilX or :q  :SigilR
" Panel: Enter=jump  o=jump(keep)  n/p=cycle  r=rename  /=filter  Esc=clear  q=close
" Source: <leader>s=open  <leader>n=next  <leader>p=prev  <leader>r=rename

if exists('g:loaded_sigil') | finish | endif
let g:loaded_sigil = 1

let g:sigil_height = get(g:, 'sigil_height', 12)
let g:sigil_binary = get(g:, 'sigil_binary',
	\ fnamemodify(resolve(expand('<sfile>:p')), ':h:h') . '/bin/sigil')

highlight default SigilMatch   ctermbg=58  guibg=#5f5f00 ctermfg=228 guifg=#ffff87
highlight default SigilCurrent ctermbg=136 guibg=#af8700 ctermfg=232 guifg=#080808

let s:data = [] | let s:filter = '' | let s:source_buf = -1 | let s:source_file = ''
let s:match_ids = [] | let s:current = '' | let s:occ_idx = 0 | let s:occs = []

" Parse

" One path for every language: bin/sigil (built by `make`) parses with tree-sitter and
" prints context|name|line,line,... per variable.

" Write current buffer to a tempfile so unsaved edits are reflected.
function! s:BufferTempfile()
	let l:ext = fnamemodify(s:source_file, ':e')
	let l:tmp = tempname() . (l:ext != '' ? '.' . l:ext : '')
	call writefile(getbufline(s:source_buf, 1, '$'), l:tmp)
	return l:tmp
endfunction

function! s:Run(file, lang)
	if !executable(g:sigil_binary)
		echohl ErrorMsg
		echo 'Sigil: helper not built. Run make in ' . fnamemodify(g:sigil_binary, ':h:h')
		echohl None
		return []
	endif
	let l:out = system(shellescape(g:sigil_binary) . ' ' . shellescape(a:lang) . ' ' . shellescape(a:file))
	if v:shell_error
		echohl ErrorMsg | echo 'Sigil: ' . substitute(trim(l:out), '^sigil: ', '', '') | echohl None
		return []
	endif
	return map(filter(map(split(l:out, "\n"),
		\ 'split(v:val, "|")'),
		\ 'len(v:val) == 3'),
		\ '{"context": v:val[0], "name": v:val[1], "lines": map(split(v:val[2], ","), "str2nr(v:val)")}')
endfunction

let s:ctx_rank = {'global': 0, 'param': 1, 'local': 2, 'field': 3}
function! s:CmpItems(a, b)
	let l:ra = get(s:ctx_rank, a:a.context, 9)
	let l:rb = get(s:ctx_rank, a:b.context, 9)
	if l:ra != l:rb | return l:ra - l:rb | endif
	return a:a.name ==# a:b.name ? 0 : a:a.name ># a:b.name ? 1 : -1
endfunction

function! s:Parse(filter)
	" The buffer's filetype names the language; the extension covers unset filetypes.
	let l:lang = getbufvar(s:source_buf, '&filetype')
	if l:lang == '' | let l:lang = fnamemodify(s:source_file, ':e') | endif
	let l:tmp = s:BufferTempfile()
	try
		let l:items = s:Run(l:tmp, l:lang)
	finally
		call delete(l:tmp)
	endtry
	if a:filter != ''
		call filter(l:items, 'stridx(tolower(v:val.name), tolower(a:filter)) != -1')
	endif
	return sort(l:items, function('s:CmpItems'))
endfunction

" Window

function! s:BufNr()
	for l:b in range(1, bufnr('$'))
		if getbufvar(l:b, 'is_sigil', 0) | return l:b | endif
	endfor
	return -1
endfunction

function! s:WinNr()
	let l:b = s:BufNr()
	return l:b == -1 ? -1 : bufwinnr(l:b)
endfunction

function! s:OpenWindow()
	let l:w = s:WinNr()
	if l:w != -1 | execute l:w . 'wincmd w' | return | endif

	execute 'botright ' . g:sigil_height . 'new'
	setlocal buftype=nofile bufhidden=wipe nobuflisted noswapfile
	setlocal nowrap cursorline nonumber norelativenumber filetype=sigil
	let b:is_sigil = 1

	for [l:grp, l:pat, l:cterm, l:gui] in [
		\ ['SigilGlobal', 'global', 214, '#ffaf00'],
		\ ['SigilField',  'field',  170, '#df87df'],
		\ ['SigilLocal',  'local',   74, '#5fafd7'],
		\ ['SigilParam',  'param',  114, '#87d787']]
		execute 'syntax match ' . l:grp . ' /^\[' . l:pat . '\s*\]/'
		execute 'highlight default ' . l:grp . ' ctermfg=' . l:cterm . ' guifg=' . l:gui
	endfor

	nnoremap <buffer> <silent> <CR>  :call <SID>Jump(1)<CR>
	nnoremap <buffer> <silent> o     :call <SID>Jump(0)<CR>
	nnoremap <buffer> <silent> n     :call <SID>Cycle(1)<CR>
	nnoremap <buffer> <silent> p     :call <SID>Cycle(-1)<CR>
	nnoremap <buffer> <silent> r     :call <SID>RenameFromPanel()<CR>
	nnoremap <buffer> <silent> q     :call <SID>Close()<CR>
	nnoremap <buffer> <silent> <Esc> :call <SID>ClearFilter()<CR>
	nnoremap <buffer> <silent> /     :call <SID>PromptFilter()<CR>
endfunction

" Render

function! s:Render()
	let l:w = s:WinNr()
	if l:w == -1 | return | endif
	let l:prev = winnr()
	execute l:w . 'wincmd w'
	setlocal modifiable
	silent %delete _

	let l:hdr = '  Sigil: ' . fnamemodify(s:source_file, ':t')
		\ . (s:filter != '' ? '  [filter: ' . s:filter . ']' : '')
		\ . '  (' . len(s:data) . ' vars)'
	call setline(1, l:hdr)
	call setline(2, repeat('─', winwidth(0)))

	let l:row = 3
	for l:item in s:data
		call setline(l:row, printf('[%-6s]', l:item['context'])
			\ . '  ' . l:item['name']
			\ . '  (' . len(l:item['lines']) . 'x)'
			\ . '  lines: ' . join(l:item['lines'], ', '))
		let l:row += 1
	endfor
	if l:row == 3 | call setline(3, '  (no variables found)') | endif

	setlocal nomodifiable
	execute l:prev . 'wincmd w'
endfunction

" Navigation

function! s:Item()
	let l:i = line('.') - 3
	return (l:i >= 0 && l:i < len(s:data)) ? s:data[l:i] : {}
endfunction

function! s:FocusSource()
	let l:w = bufwinnr(s:source_buf)
	execute (l:w != -1 ? l:w . 'wincmd w' : 'buffer ' . s:source_buf)
endfunction

function! s:Jump(close)
	let l:item = s:Item()
	if empty(l:item) | return | endif
	let [s:current, s:occs, s:occ_idx] = [l:item['name'], l:item['lines'], 0]
	if a:close | call s:Close() | endif
	call s:FocusSource()
	call s:Highlight(l:item['name'])
	execute s:occs[0] | normal! zz
endfunction

function! s:Cycle(dir)
	if winnr() == s:WinNr()
		let l:item = s:Item()
		if !empty(l:item)
			let [s:current, s:occs, s:occ_idx] = [l:item['name'], l:item['lines'], 0]
		endif
	endif
	if empty(s:occs) | return | endif
	let l:len = len(s:occs)
	let s:occ_idx = ((s:occ_idx + a:dir) % l:len + l:len) % l:len
	call s:FocusSource()
	execute s:occs[s:occ_idx] | normal! zz
	echo 'Sigil: ' . s:current . ' [' . (s:occ_idx + 1) . '/' . l:len . ']'
endfunction

" Highlight

function! s:Highlight(name)
	call s:ClearHighlights()
	let l:w = bufwinnr(s:source_buf)
	if l:w == -1 | return | endif
	let l:prev = winnr()
	execute l:w . 'wincmd w'
	call add(s:match_ids, matchadd('SigilMatch', '\<' . escape(a:name, '/\') . '\>'))
	execute l:prev . 'wincmd w'
endfunction

function! s:ClearHighlights()
	let l:w = bufwinnr(s:source_buf)
	if l:w == -1 | return | endif
	let l:prev = winnr()
	execute l:w . 'wincmd w'
	for l:id in s:match_ids | try | call matchdelete(l:id) | catch | endtry | endfor
	let s:match_ids = []
	execute l:prev . 'wincmd w'
endfunction

" Filter/Rename

function! s:PromptFilter()
	let s:filter = input('Filter: ', s:filter)
	let s:data = s:Parse(s:filter)
	call s:Render()
endfunction

function! s:ClearFilter()
	let s:filter = ''
	let s:data = s:Parse('')
	call s:Render()
endfunction

function! s:DoRename(old)
	let l:new = input('Rename "' . a:old . '" to: ')
	if l:new == '' || l:new == a:old | return | endif
	call s:FocusSource() | call s:ClearHighlights()
	execute '%s/\<' . escape(a:old, '/\') . '\>/' . escape(l:new, '/\') . '/g'
	echo 'Sigil: renamed "' . a:old . '" → "' . l:new . '"'
	let s:current = l:new
	let s:data = s:Parse(s:filter)
	call s:Render() | call s:Highlight(l:new)
endfunction

function! s:RenameFromPanel()
	let l:item = s:Item()
	if !empty(l:item) | call s:DoRename(l:item['name']) | endif
endfunction

function! s:RenameUnderCursor()
	let l:name = expand('<cword>')
	if l:name != '' | call s:DoRename(l:name) | endif
endfunction

" Open/Close

function! s:Open()
	let s:source_buf  = bufnr('%')
	let s:source_file = expand('%:p')
	if s:source_file == '' | echo 'Sigil: no file to parse' | return | endif
	let s:data = s:Parse(s:filter)
	call s:OpenWindow() | call s:Render()

	augroup sigil_refresh
		autocmd!
		execute 'autocmd BufWritePost <buffer=' . s:source_buf . '> call <SID>Refresh()'
	augroup END
endfunction

function! s:Refresh()
	if s:WinNr() == -1 | return | endif
	let s:data = s:Parse(s:filter)
	call s:Render()
endfunction

function! s:Close()
	call s:ClearHighlights()
	let l:w = s:WinNr()
	if l:w != -1 | execute l:w . 'wincmd w' | close | endif
	let l:sw = bufwinnr(s:source_buf)
	if l:sw != -1 | execute l:sw . 'wincmd w' | endif
	augroup sigil_refresh | autocmd! | augroup END
endfunction

" Commands/Maps

command! Sigil  call s:Open()
command! SigilX call s:Close()
command! SigilR call s:RenameUnderCursor()

" <Plug> mappings users can rebind by mapping to these.
nnoremap <silent> <Plug>SigilOpen   :call <SID>Open()<CR>
nnoremap <silent> <Plug>SigilNext   :call <SID>Cycle(1)<CR>
nnoremap <silent> <Plug>SigilPrev   :call <SID>Cycle(-1)<CR>
nnoremap <silent> <Plug>SigilRename :call <SID>RenameUnderCursor()<CR>

" Default mappings only installed if user hasn't mapped <Plug> targets
" themselves and the key isn't already taken. Opt out with:
"   let g:sigil_no_default_mappings = 1
if !get(g:, 'sigil_no_default_mappings', 0)
	for [s:key, s:plug] in [
		\ ['<leader>s', '<Plug>SigilOpen'],
		\ ['<leader>n', '<Plug>SigilNext'],
		\ ['<leader>p', '<Plug>SigilPrev'],
		\ ['<leader>r', '<Plug>SigilRename']]
		if !hasmapto(s:plug, 'n') && empty(maparg(s:key, 'n'))
			execute 'nmap ' . s:key . ' ' . s:plug
		endif
	endfor
endif
