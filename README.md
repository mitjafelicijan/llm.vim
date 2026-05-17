# llm.vim

Asynchronous Vim plugin for Ollama LLMs.

## Features
- **Code Completion & Refactoring (`<leader>l`)**: Replaces or appends code using the File Skeleton and Local Context as prompts.
- **Conversational Questions (`<leader>k`)**: Opens a vertical right-split scratch buffer (`ft=markdown`) for queries.
- **Model Management (`:LLMModel`)**: Command with tab-completion for switching `g:llm_model` based on local Ollama tags.
- **Asynchronous Execution**: Uses Vim 8 jobs and temporary files for non-blocking I/O.
- **Indentation Aware**: Uses Vim's `=` operator on inserted code.

## Installation
```vim
Plug 'mitjafelicijan/llm.vim'
```

## Configuration
Override defaults in your `.vimrc`:

Check for available models https://ollama.com/search.

```vim
let g:llm_model = 'granite4.1:3b'
let g:llm_url = 'http://127.0.0.1:11434'
```

### Custom Mappings
To disable default mappings and define your own, set `g:llm_disable_mappings` and use the following functions:

```vim
let g:llm_disable_mappings = 1

" Normal mode question
nnoremap <C-k> :call llm#AskQuestion(0)<CR>
" Visual mode question
xnoremap <C-k> :<C-u>call llm#AskQuestion(1)<CR>
" Visual mode completion
xnoremap <C-l> :<C-u>call llm#RequestCompletion(1)<CR>
```

## Mappings & Commands (Defaults)
- `<leader>l` (Visual): Refactor or replace selection.
- `<leader>k` (Normal/Visual): Open `[LLM Answer]` buffer on the right.
- `:LLMModel`: Switch `g:llm_model`. Supports `<Tab>` completion via Ollama API.
