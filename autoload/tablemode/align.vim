" ==============================  Header ======================================
" File:          autoload/tablemode/align.vim
" Description:   Table mode for vim for creating neat tables.
" Author:        Dhruva Sagar <http://dhruvasagar.com/>
" License:       MIT (http://www.opensource.org/licenses/MIT)
" Website:       https://github.com/dhruvasagar/vim-table-mode
" Note:          This plugin was heavily inspired by the 'CucumberTables.vim'
"                (https://gist.github.com/tpope/287147) plugin by Tim Pope.
"
" Copyright Notice:
"                Permission is hereby granted to use and distribute this code,
"                with or without modifications, provided that this copyright
"                notice is copied with it. Like anything else that's free,
"                table-mode.vim is provided *as is* and comes with no warranty
"                of any kind, either expressed or implied. In no event will
"                the copyright holder be liable for any damamges resulting
"                from the use of this software.
" =============================================================================

" Borrowed from Tabular
" Private Functions {{{1
" Return the number of bytes in a string after expanding tabs to spaces.  {{{2
" This expansion is done based on the current value of 'tabstop'
if exists('*strdisplaywidth')
  " Needs vim 7.3
  let s:Strlen = function("strdisplaywidth")
else
  function! s:Strlen(string)
    " Implement the tab handling part of strdisplaywidth for vim 7.2 and
    " earlier - not much that can be done about handling doublewidth
    " characters.
    let rv = 0
    let i = 0

    for char in split(a:string, '\zs')
      if char == "\t"
        let rv += &ts - i
        let i = 0
      else
        let rv += 1
        let i = (i + 1) % &ts
      endif
    endfor

    return rv
  endfunction
endif
" function! s:StripTrailingSpaces(string) - Remove all trailing spaces {{{2
" from a string.
function! s:StripTrailingSpaces(string)
  return matchstr(a:string, '^.\{-}\ze\s*$')
endfunction

function! s:Padding(string, length, where) "{{{3
  let gap_length = a:length - s:Strlen(a:string)
  if a:where =~# 'l'
    return a:string . repeat(" ", gap_length)
  elseif a:where =~# 'r'
    return repeat(" ", gap_length) . a:string
  elseif a:where =~# 'c'
    let right = spaces / 2
    let left = right + (right * 2 != gap_length)
    return repeat(" ", left) . a:string . repeat(" ", right)
  endif
endfunction

" Public Functions {{{1
function! tablemode#align#sid() "{{{2
  return maparg('<sid>', 'n')
endfunction
nnoremap <sid> <sid>

function! tablemode#align#scope() "{{{2
  return s:
endfunction

" function! tablemode#align#Split() - Split a string into fields and delimiters {{{2
" Like split(), but include the delimiters as elements
" All odd numbered elements are delimiters
" All even numbered elements are non-delimiters (including zero)
function! tablemode#align#Split(string, delim)
  let rv = []
  let beg = 0

  let len = len(a:string)
  let searchoff = 0

  while 1
    let mid = match(a:string, a:delim, beg + searchoff, 1)
    if mid == -1 || mid == len
      break
    endif

    let matchstr = matchstr(a:string, a:delim, beg + searchoff, 1)
    let length = strlen(matchstr)

    if length == 0 && beg == mid
      " Zero-length match for a zero-length delimiter - advance past it
      let searchoff += 1
      continue
    endif

    if beg == mid
      let rv += [ "" ]
    else
      let rv += [ a:string[beg : mid-1] ]
    endif

    let rv += [ matchstr ]

    let beg = mid + length
    let searchoff = 0
  endwhile

  let rv += [ strpart(a:string, beg) ]

  return rv
endfunction

function! tablemode#align#alignments(lnum, ncols) "{{{2
  let alignments = repeat(['l'], a:ncols) " For each column
  if tablemode#table#IsHeader(a:lnum+1)
    let hcols = tablemode#align#Split(getline(a:lnum+1), '[' . g:table_mode_corner . g:table_mode_corner_corner . ']')
    for idx in range(len(hcols))
      " Right align if header
      if hcols[idx] =~# g:table_mode_align_char . '$' | let alignments[idx] = 'r' | endif
      if hcols[idx] !~# '[^0-9\.]' | let alignments[idx] = 'r' | endif
    endfor
  end
  return alignments
endfunction

function! tablemode#align#Align(lines) "{{{2
  let lines = map(a:lines, 'map(v:val, "v:key =~# \"text\" ? tablemode#align#Split(v:val, g:table_mode_separator) : v:val")')

  for line in lines
    let stext = line.text
    if len(stext) <= 1 | continue | endif

    if stext[0] !~ tablemode#table#StartExpr()
      let stext[0] = s:StripTrailingSpaces(stext[0])
    endif
    if len(stext) >= 2
      for i in range(1, len(stext)-1)
        let stext[i] = tablemode#utils#strip(stext[i])
      endfor
    endif
  endfor

  let maxes = []
  for line in lines
    let stext = line.text
    if len(stext) <= 1 | continue | endif
    for i in range(len(stext))
      if i == len(maxes)
        let maxes += [ s:Strlen(stext[i]) ]
      else
        let maxes[i] = max([ maxes[i], s:Strlen(stext[i]) ])
      endif
    endfor
  endfor

  let alignments = tablemode#align#alignments(lines[0].lnum, len(lines[0].text))

  for idx in range(len(lines))
    let tlnum = lines[idx].lnum
    let tline = lines[idx].text

    if len(tline) <= 1 | continue | endif
    for jdx in range(len(tline))
      let field = s:Padding(tline[jdx], maxes[jdx], alignments[jdx])
      let tline[jdx] = field . (jdx == 0 || jdx == len(tline) ? '' : ' ')
    endfor

    let lines[idx].text = s:StripTrailingSpaces(join(tline, ''))
  endfor

  return lines
endfunction
