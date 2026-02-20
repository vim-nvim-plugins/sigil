" sigil.vim - Variable panel for Vim  github.com/zblauser/sigil
" :Sigil  :SigilX or :q  :SigilR
" Panel: Enter=jump  o=jump(keep)  n/p=cycle  r=rename  /=filter  Esc=clear  q=close
" Source: <leader>s=open  <leader>n=next  <leader>p=prev  <leader>r=rename

if exists('g:loaded_sigil') | finish | endif
let g:loaded_sigil = 1

let g:sigil_height = get(g:, 'sigil_height', 12)
let g:sigil_python = get(g:, 'sigil_python', 'python3')
let g:sigil_script = get(g:, 'sigil_script',
	\ fnamemodify(resolve(expand('<sfile>:p')), ':h:h') . '/scripts/sigil.py')

highlight default SigilMatch   ctermbg=58  guibg=#5f5f00 ctermfg=228 guifg=#ffff87
highlight default SigilCurrent ctermbg=136 guibg=#af8700 ctermfg=232 guifg=#080808

let s:data = [] | let s:filter = '' | let s:source_buf = -1 | let s:source_file = ''
let s:match_ids = [] | let s:current = '' | let s:occ_idx = 0 | let s:occs = []

" Parse

function! s:Parse(file, filter)
	let l:out = system(g:sigil_python . ' ' . shellescape(g:sigil_script)
		\ . ' ' . shellescape(a:file)
		\ . (a:filter != '' ? ' ' . shellescape(a:filter) : ''))
	if v:shell_error
		echohl ErrorMsg | echo 'Sigil: ' . l:out | echohl None
		return []
	endif
	return map(filter(map(split(l:out, "\n"),
		\ 'split(v:val, "|")'),
		\ 'len(v:val) == 3'),
		\ '{"context": v:val[0], "name": v:val[1], "lines": map(split(v:val[2], ","), "str2nr(v:val)")}')
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
		\ ['SigilClass',  'class',  170, '#df87df'],
		\ ['SigilLocal',  'local',   74, '#5fafd7'],
		\ ['SigilParam',  'param',  114, '#87d787'],
		\ ['SigilLoop',   'loop',   183, '#d7afff'],
		\ ['SigilComp',   'comp',   174, '#d78787'],
		\ ['SigilExcept', 'except', 167, '#d75f5f']]
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
	let s:data = s:Parse(s:source_file, s:filter)
	call s:Render()
endfunction

function! s:ClearFilter()
	let s:filter = ''
	let s:data = s:Parse(s:source_file, '')
	call s:Render()
endfunction

function! s:DoRename(old)
	let l:new = input('Rename "' . a:old . '" to: ')
	if l:new == '' || l:new == a:old | return | endif
	call s:FocusSource() | call s:ClearHighlights()
	execute '%s/\<' . escape(a:old, '/\') . '\>/' . escape(l:new, '/\') . '/g'
	echo 'Sigil: renamed "' . a:old . '" → "' . l:new . '"'
	let s:current = l:new
	let s:data = s:Parse(s:source_file, s:filter)
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
	let s:data = s:Parse(s:source_file, s:filter)
	call s:OpenWindow() | call s:Render()
endfunction

function! s:Close()
	call s:ClearHighlights()
	let l:w = s:WinNr()
	if l:w != -1 | execute l:w . 'wincmd w' | close | endif
	let l:sw = bufwinnr(s:source_buf)
	if l:sw != -1 | execute l:sw . 'wincmd w' | endif
endfunction

" Commands/Maps

command! Sigil       call s:Open()
command! SigilX  call s:Close()
command! SigilR call s:RenameUnderCursor()

nnoremap <silent> <leader>s :call <SID>Open()<CR>
nnoremap <silent> <leader>n :call <SID>Cycle(1)<CR>
nnoremap <silent> <leader>p :call <SID>Cycle(-1)<CR>
nnoremap <silent> <leader>r :call <SID>RenameUnderCursor()<CR>
