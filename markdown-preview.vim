" ========== Simple Markdown Preview Plugin ==========

function! s:PreviewWinnr()
  for winnr in range(1, winnr('$'))
    if getwinvar(winnr, 'is_markdown_preview', 0)
      return winnr
    endif
  endfor
  return 0
endfunction

function! s:ScrollToTop(timer_id)
  let l:winnr = s:PreviewWinnr()
  if l:winnr > 0
    let l:cur = winnr()
    execute l:winnr . 'wincmd w'
    normal! gg
    execute l:cur . 'wincmd w'
  endif
endfunction

function! s:OnGlowFinish(temp_file, job, status)
  call timer_start(50, function('s:ScrollToTop'))
  call delete(a:temp_file)
endfunction

function! ToggleMarkdownPreview()
  let l:winnr = s:PreviewWinnr()
  if l:winnr > 0
    " Found preview window, close it and return to source
    let l:source_winnr = getwinvar(l:winnr, 'source_winnr', 0)
    execute l:winnr . 'wincmd w'
    quit!
    if l:source_winnr > 0 && l:source_winnr <= winnr('$')
      execute l:source_winnr . 'wincmd w'
    endif
    return
  endif

  " No preview found, create one
  let l:source_winnr = winnr()
  let l:width = float2nr(&columns * 0.5)

  if executable('glow') && has('terminal')
    " Read content before switching windows, then open vertical split
    let l:temp_file = tempname() . '.md'
    let l:content = getline(1, '$')
    call writefile(l:content, l:temp_file)
    execute 'rightbelow vnew'
    execute 'vertical resize ' . l:width
    call term_start(['glow', '-s', 'dark', l:temp_file], {
      \ 'curwin': 1,
      \ 'exit_cb': function('s:OnGlowFinish', [l:temp_file]),
      \ })
  else
    " Basic fallback - create buffer with content directly
    execute 'rightbelow vnew'
    execute 'vertical resize ' . l:width

    setlocal buftype=nofile noswapfile nobuflisted
    let l:content = getbufline('#', 1, '$')
    call setline(1, l:content)
    setlocal ft=markdown readonly nomodifiable
  endif

  " Mark this window as preview and store source
  let w:is_markdown_preview = 1
  let w:source_winnr = l:source_winnr

  " Simple quit mapping - just close window and return to source
  nnoremap <buffer> q :call ToggleMarkdownPreview()<CR>
  if has('terminal') && &buftype == 'terminal'
    tnoremap <buffer> q <C-\><C-n>:call ToggleMarkdownPreview()<CR>
  endif
endfunction

" Auto-resize preview when window is resized
function! ResizeMarkdownPreview()
  let l:winnr = s:PreviewWinnr()
  if l:winnr > 0
    let l:width = float2nr(&columns * 0.5)
    execute l:winnr . 'wincmd w'
    execute 'vertical resize ' . l:width
    execute 'wincmd p'
  endif
endfunction

" Set up auto-resize
augroup MarkdownPreview
  autocmd!
  autocmd VimResized * call ResizeMarkdownPreview()
augroup END

" Command and mapping
command! MarkdownPreviewToggle call ToggleMarkdownPreview()
nnoremap mp :MarkdownPreviewToggle<CR>
