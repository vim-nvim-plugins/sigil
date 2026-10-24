let g:limit = 3
let s:count = 0
function! Scale(value, factor) abort
	let l:total = a:value * a:factor
	for l:i in range(g:limit)
		let l:total += l:i
	endfor
	let s:count += 1
	return l:total
endfunction
echo "total limit" Scale(g:limit, 2) " total in a comment
