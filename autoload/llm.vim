let g:llm_model = get(g:, 'llm_model', 'falcon3:latest')
let g:llm_url = get(g:, 'llm_url', 'http://127.0.0.1:11434')
let g:llm_scratch_bufnr = -1

" System Prompts
let g:llm_system_prompt_code = get(g:, 'llm_system_prompt_code', "Output ONLY raw code. No markdown. No commentary. Do not include comments. Keep logical units on a single line; do not split statements or function calls into multiple lines.")
let g:llm_system_prompt_question = get(g:, 'llm_system_prompt_question', "You are a helpful assistant. Clear and concise.")
let g:llm_visual_task_prompt = get(g:, 'llm_visual_task_prompt', "TASK: Replace the following selection. Output ONLY raw replacement code. No markdown formatting. No backticks. No commentary. Do not include comments. Constraint: Do not split statements or function calls into multiple lines; keep logical units on a single line.")

function! llm#GetOrCreateScratch()
	if g:llm_scratch_bufnr != -1 && bufexists(g:llm_scratch_bufnr)
		let l:winid = bufwinid(g:llm_scratch_bufnr)
		if l:winid != -1
			call win_gotoid(l:winid)
		else
			" execute 'topleft split'
			execute 'vertical botright split'
			execute 'buffer ' . g:llm_scratch_bufnr
		endif
	else
		" silent execute 'topleft 20new'
		silent execute 'vertical botright 80new'
		setlocal buftype=nofile bufhidden=hide noswapfile wrap
		let g:llm_scratch_bufnr = bufnr('%')
		silent! execute 'file [LLM Answer]'
	endif

	setlocal wrap filetype=markdown
	return g:llm_scratch_bufnr
endfunction

function! llm#GetStyleInstructions()
	let l:indent_type = &expandtab ? "spaces" : "tabs"
	let l:indent_width = &shiftwidth == 0 ? &tabstop : &shiftwidth
	return printf("Style: Use %d %s for indentation. Match the project's naming convention.", l:indent_width, l:indent_type)
endfunction

function! llm#GetSurroundingContext(line_start, line_end)
	let l:top = getline(1, 20)
	let l:local_start = max([1, a:line_start - 20])
	let l:local_end = max([1, a:line_start - 1])
	let l:local = getline(l:local_start, l:local_end)

	let l:ctx = "[File Skeleton]\n" . join(l:top, "\n") . "\n...\n"
	let l:ctx .= "[Local Context]\n" . join(l:local, "\n")
	return l:ctx
endfunction

function! llm#HandleCodeExit(context, job, status)
	let l:err_msg = ""
	if filereadable(a:context.err_file)
		let l:err_msg = join(readfile(a:context.err_file), " ")
	endif

	if a:status != 0
		redraw | echoerr "LLM Request Failed (" . a:status . "): " . l:err_msg
		call delete(a:context.res_file)
		call delete(a:context.req_file)
		call delete(a:context.err_file)
		return
	endif

	if !filereadable(a:context.res_file)
		redraw | echoerr "LLM: No response file found"
		call delete(a:context.req_file)
		call delete(a:context.err_file)
		return
	endif

	let l:content = join(readfile(a:context.res_file, 'b'), "")

	" Clean up temp files
	call delete(a:context.res_file)
	call delete(a:context.req_file)
	call delete(a:context.err_file)

	if empty(l:content)
		redraw | echoerr "LLM: Empty response"
		return
	endif

	try
		let l:json = json_decode(l:content)
		if type(l:json) == v:t_dict && has_key(l:json, 'response')
			let l:response = l:json['response']
			let l:response = substitute(l:response, '^```\w*\n', '', '')
			let l:response = substitute(l:response, '\n```$', '', '')
			let l:response = substitute(l:response, '^```', '', '')
			let l:response = substitute(l:response, '```$', '', '')
			let l:out_lines = split(l:response, "\n")

			if bufexists(a:context.bufnr)
				let l:start_line = 0
				let l:end_line = 0

				if a:context.is_replacing
					call deletebufline(a:context.bufnr, a:context.range_start, a:context.range_end)
					call appendbufline(a:context.bufnr, a:context.range_start - 1, l:out_lines)
					let l:start_line = a:context.range_start
					let l:end_line = a:context.range_start + len(l:out_lines) - 1
				else
					call appendbufline(a:context.bufnr, a:context.insert_pos, l:out_lines)
					let l:start_line = a:context.insert_pos + 1
					let l:end_line = a:context.insert_pos + len(l:out_lines)
				endif

				" Apply auto-formatting
				let l:winid = bufwinid(a:context.bufnr)
				if l:winid != -1 && l:start_line <= l:end_line
					call win_execute(l:winid, 'normal! ' . l:start_line . 'G=' . l:end_line . 'G')
				endif
			endif
			redraw | echo "LLM: Code Updated"
		elseif type(l:json) == v:t_dict && has_key(l:json, 'error')
			redraw | echoerr "LLM Error: " . l:json.error
		else
			redraw | echoerr "LLM: Unexpected JSON structure"
		endif
	catch
		redraw | echoerr "LLM: Failed to parse response. Content starts with: " . strpart(l:content, 0, 100)
	endtry
endfunction

function! llm#HandleQuestionExit(context, job, status)
	let l:err_msg = ""
	if filereadable(a:context.err_file)
		let l:err_msg = join(readfile(a:context.err_file), " ")
	endif

	if a:status != 0
		redraw | echoerr "LLM Request Failed (" . a:status . "): " . l:err_msg
		call delete(a:context.res_file)
		call delete(a:context.req_file)
		call delete(a:context.err_file)
		return
	endif

	if !filereadable(a:context.res_file)
		redraw | echoerr "LLM: No response file found"
		call delete(a:context.req_file)
		call delete(a:context.err_file)
		return
	endif

	let l:content = join(readfile(a:context.res_file, 'b'), "")

	" Clean up temp files
	call delete(a:context.res_file)
	call delete(a:context.req_file)
	call delete(a:context.err_file)

	if !empty(l:content)
		try
			let l:json = json_decode(l:content)
			if type(l:json) == v:t_dict && has_key(l:json, 'response')
				if bufexists(g:llm_scratch_bufnr)
					call appendbufline(g:llm_scratch_bufnr, '$', split(l:json['response'], "\n"))
					let l:winid = bufwinid(g:llm_scratch_bufnr)
					if l:winid != -1
						call win_execute(l:winid, 'normal! gg')
					endif
				endif
				redraw | echo "LLM: Answer Received"
			elseif type(l:json) == v:t_dict && has_key(l:json, 'error')
				redraw | echoerr "LLM Error: " . l:json.error
			endif
		catch
			redraw | echoerr "LLM: Failed to parse response"
		endtry
	endif
endfunction

function! llm#StartJob(prompt, context, exit_cb)
	redraw | echo "LLM: Thinking..."
	let l:payload_dict = {
				\ 'model': g:llm_model,
				\ 'prompt': a:prompt,
				\ 'stream': v:false
				\ }

	let l:payload = json_encode(l:payload_dict)
	let a:context.req_file = tempname()
	let a:context.res_file = tempname()
	let a:context.err_file = tempname()

	call writefile([l:payload], a:context.req_file, 'b')

	" Use native job_start redirection instead of shell pipes
	" Added -f to curl to return non-zero exit code on HTTP errors
	let l:cmd = ['curl', '-sfS', '-X', 'POST', g:llm_url . '/api/generate', 
				\ '--connect-timeout', '10',
				\ '-d', '@' . a:context.req_file]

	let l:job = job_start(l:cmd, {
				\ 'exit_cb': function(a:exit_cb, [a:context]),
				\ 'out_io': 'file',
				\ 'out_name': a:context.res_file,
				\ 'err_io': 'file',
				\ 'err_name': a:context.err_file
				\ })
endfunction

function! llm#RequestCompletion(is_visual)
	let l:context = {'mode': 'code', 'bufnr': bufnr('%')}
	let l:file_info = "File: " . expand('%:t') . " (type: " . &filetype . ")"
	let l:style = llm#GetStyleInstructions()
	let l:system_prompt = g:llm_system_prompt_code . "\n" . l:style

	if a:is_visual
		let l:context.range_start = getpos("'<")[1]
		let l:context.range_end = getpos("'>")[1]
		let l:selection = join(getline(l:context.range_start, l:context.range_end), "\n")
		let l:instruction = input("Instruction: ")
		redraw

		if empty(l:instruction) && empty(l:selection) | return | endif

		let l:mod_prompt = g:llm_visual_task_prompt . "\n"
		if l:instruction =~? 'refactor' | let l:mod_prompt .= "Instruction: Refactor for efficiency/readability.\n" | endif
		if l:instruction =~? 'fix\|bug' | let l:mod_prompt .= "Instruction: Fix bugs/errors.\n" | endif
		if l:instruction =~? 'doc\|comment' | let l:mod_prompt .= "Instruction: Add documentation.\n" | endif
		if !empty(l:instruction) | let l:mod_prompt .= "Additional Instruction: " . l:instruction . "\n" | endif

		let l:surround = llm#GetSurroundingContext(l:context.range_start, l:context.range_end)
		let l:suffix = join(getline(l:context.range_end + 1, min([l:context.range_end + 100, line('$')])), "\n")

		let l:prompt = l:file_info . "\n" . l:style . "\n\n"
		let l:prompt .= "[CONTEXT - FOR REFERENCE ONLY]\n" . l:surround . "\n"
		if !empty(l:suffix) | let l:prompt .= "[CODE AFTER SELECTION - FOR REFERENCE ONLY]\n" . l:suffix . "\n" | endif
		let l:prompt .= "\n" . l:mod_prompt
		let l:prompt .= "\n[CODE TO REPLACE]\n" . l:selection . "\n\nREPLACEMENT CODE:"

		let l:context.is_replacing = 1
	endif

	call llm#StartJob(l:prompt, l:context, 'llm#HandleCodeExit')
endfunction

function! llm#AskQuestion(is_visual)
	let l:selection = ""
	let l:line_start = line('.')
	let l:line_end = line('.')
	if a:is_visual
		let l:line_start = getpos("'<")[1]
		let l:line_end = getpos("'>")[1]
		let l:selection = join(getline(l:line_start, l:line_end), "\n")
	endif

	let l:question = input("Ask: ")
	redraw
	if empty(l:question) | return | endif

	let l:file_info = "File: " . expand('%:t') . " (type: " . &filetype . ")"
	let l:surround = llm#GetSurroundingContext(l:line_start, l:line_end)
	let l:prompt = l:file_info . "\n" . g:llm_system_prompt_question . "\n\n" . l:surround
	if !empty(l:selection) | let l:prompt .= "\n\nContext Selection:\n" . l:selection | endif
	let l:prompt .= "\n\nQuestion: " . l:question

	let l:bufnr = llm#GetOrCreateScratch()
	silent call deletebufline(l:bufnr, 1, '$')
	call setbufline(l:bufnr, 1, ["Question: " . l:question, "Model: " . g:llm_model, ""])
	let l:winid = bufwinid(l:bufnr)
	if l:winid != -1 | call win_execute(l:winid, 'normal! gg') | endif

	call llm#StartJob(l:prompt, {'mode': 'question'}, 'llm#HandleQuestionExit')
endfunction

function! llm#ListModels()
	let l:cmd = 'curl -sS --connect-timeout 2 ' . g:llm_url . '/api/tags'
	let l:output = system(l:cmd)
	if v:shell_error != 0
		return []
	endif
	try
		let l:json = json_decode(l:output)
		if type(l:json) == v:t_dict && has_key(l:json, 'models')
			return map(l:json.models, 'v:val.name')
		endif
	catch
	endtry
	return []
endfunction

function! llm#CompleteModel(ArgLead, CmdLine, CursorPos)
	let l:models = llm#ListModels()
	return filter(l:models, 'v:val =~# "^" . a:ArgLead')
endfunction

function! llm#SwitchModel(model)
	if empty(a:model)
		echo "LLM: Current model is " . g:llm_model
		return
	endif
	let g:llm_model = a:model
	echo "LLM: Model set to " . g:llm_model
endfunction
