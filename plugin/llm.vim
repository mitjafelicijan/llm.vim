if exists('g:loaded_llm')
	finish
endif
let g:loaded_llm = 1

if !get(g:, 'llm_disable_mappings', 0)
	xnoremap <leader>l :<C-u>call llm#RequestCompletion(1)<CR>
	nnoremap <leader>k :call llm#AskQuestion(0)<CR>
	xnoremap <leader>k :<C-u>call llm#AskQuestion(1)<CR>
endif

command! -nargs=? -complete=customlist,llm#CompleteModel LLMModel call llm#SwitchModel(<q-args>)
