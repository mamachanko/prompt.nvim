# prompt.nvim

A Neovim plugin for managing AI agent prompts. Write prompts in Neovim, store them in SQLite with full-text search, and auto-copy to clipboard on save.

## Features

- **`:PromptNew`** — open a buffer, write a prompt, save+quit → clipboard + stored
- **`:PromptSearch`** — fuzzy search prompt history, pick one → opens in buffer for review/edit
- **`<leader>fP`** — search and insert an old prompt into your current buffer

## Requirements

- Neovim >= 0.9
- `sqlite3` CLI (installed on most systems)
- [Snacks.nvim](https://github.com/folke/snacks.nvim) (optional, for rich picker with preview; falls back to `vim.ui.select`)

## Installation

### lazy.nvim

```lua
{
  "mamachanko/prompt.nvim",
  opts = {},
  -- optional: for rich picker with preview
  dependencies = { "folke/snacks.nvim" },
}
```

## Configuration

```lua
require("prompt").setup({
  db_path = "~/.prompts.db", -- default
  keymap = "<leader>fP",      -- default
})
```

## Usage

### New prompt

```bash
# From shell (define your own alias)
alias prompt='nvim -c "PromptNew"'
prompt
```

Write your prompt → `:wq` → it's on your clipboard and saved. `:q!` = nothing happens.

### Search history

```bash
alias ps='nvim -c "PromptSearch"'
ps
```

Fuzzy search → pick a prompt → review/edit in buffer → `:wq` → clipboard.

### Insert from picker (mid-edit)

Press `<leader>fP` in normal mode → search → selected prompt inserted at cursor.

## Development

Use the canonical local verification targets:

```bash
make lint
export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim
make test
make check
```

Requirements:

- `make lint` expects `stylua` and `luacheck` to already be installed
- `make test` expects `nvim` and `sqlite3` to be installed
- `make test` and `make check` require `PLENARY_DIR` to point to your local `plenary.nvim` checkout

## License

Apache 2.0
