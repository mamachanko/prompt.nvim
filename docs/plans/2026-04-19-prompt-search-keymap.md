# Prompt Search Keymap Simplification Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the built-in `<leader>fP` mapping and insert-from-picker workflow so `prompt.nvim` focuses on `:PromptNew` and `:PromptSearch`, with README examples showing user-managed mappings.

**Architecture:** Keep the existing command-first plugin shape and simplify the public surface instead of adding replacement commands or opt-in keymap config. The code change is concentrated in `init.lua`, `picker.lua`, and `plugin/prompt.lua`, while tests lock in “no plugin-owned keymap” and “search always opens a prompt buffer” behavior.

**Tech Stack:** Lua (Neovim), plenary.nvim tests, SQLite3 CLI, Snacks.nvim optional picker integration

---

## File Structure

- `lua/prompt/init.lua` — setup entry point, config defaults, command registration; remove the `keymap` config field and stop installing a normal-mode mapping
- `lua/prompt/picker.lua` — prompt history picker; remove the insert path so selecting a prompt always opens it in a prompt buffer
- `plugin/prompt.lua` — eager command registration for `nvim -c "PromptNew"` / `PromptSearch`; update command callback to use the simplified picker API
- `tests/prompt/integration_spec.lua` — integration-level assertions that setup still registers commands and no plugin-owned normal-mode mapping is created
- `tests/prompt/picker_spec.lua` — picker behavior tests; add coverage for the fallback selection path opening a buffer even when legacy insert options are passed
- `README.md` — remove built-in keymap docs, show concise `lazy.nvim` setup with a user-owned `vim.keymap.set(..., "<cmd>PromptSearch<CR>")` example
- `docs/specs/2026-03-28-prompt-nvim-design.md` — add a short historical note so archived design docs do not look like current behavior
- `docs/plans/2026-03-28-prompt-nvim.md` — add a short historical note for the same reason

### Task 1: Remove plugin-managed keymap setup

**Files:**
- Modify: `tests/prompt/integration_spec.lua:20-48`
- Modify: `lua/prompt/init.lua:3-38`

- [ ] **Step 1: Write the failing integration test that proves setup no longer owns a default keymap**

```lua
  it("does not install a default normal-mode mapping", function()
    local prompt_mapping = nil
    for _, map in ipairs(vim.api.nvim_get_keymap("n")) do
      if map.lhs == "\\fP" or map.desc == "Find and insert a prompt" then
        prompt_mapping = map
        break
      end
    end
    assert.is_nil(prompt_mapping)
  end)

  it("full cycle: setup creates DB and search finds saved prompts", function()
    local db = require("prompt.db")
    db.insert("integration test prompt", "/tmp")
    local results = db.search("integration")
    assert.are.equal(1, #results)
    assert.are.equal("integration test prompt", results[1].body)
  end)
```

Add the new `does not install a default normal-mode mapping` example near the existing command registration checks, and rename the old “insert works” test to remove the stale insert wording.

- [ ] **Step 2: Run the test suite and confirm the new assertion fails before touching implementation**

Run:
```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Expected: FAIL with the new integration example because `require("prompt").setup()` still registers `<leader>fP` / `Find and insert a prompt`.

- [ ] **Step 3: Remove `keymap` from the config contract and stop calling `vim.keymap.set` in setup**

```lua
local M = {}

---@class prompt.Config
---@field db_path? string path to SQLite database (default: ~/.prompts.db)
local defaults = {
  db_path = vim.fn.expand("~/.prompts.db"),
}

M.config = {}

local did_setup = false

function M.setup(opts)
  if did_setup and opts == nil then
    return
  end
  did_setup = true

  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  require("prompt.db").setup(M.config.db_path)

  vim.api.nvim_create_user_command("PromptNew", function()
    require("prompt.buffer").open_new()
  end, { force = true, desc = "Create a new prompt" })

  vim.api.nvim_create_user_command("PromptSearch", function()
    require("prompt.picker").search()
  end, { force = true, desc = "Search prompt history" })
end

return M
```

This task is intentionally narrow: remove the config field, remove the default mapping, and keep the existing commands working.

- [ ] **Step 4: Re-run the test suite and confirm the integration test now passes**

Run:
```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Expected: PASS for the new integration test and the existing suite.

- [ ] **Step 5: Commit the keymap removal checkpoint**

```bash
git add lua/prompt/init.lua tests/prompt/integration_spec.lua
git commit -m "refactor: remove default prompt keymap"
```

### Task 2: Remove insert-mode picker behavior

**Files:**
- Modify: `tests/prompt/picker_spec.lua:3-53`
- Modify: `lua/prompt/picker.lua:22-115`
- Modify: `plugin/prompt.lua:12-15`

- [ ] **Step 1: Write the failing picker spec for the legacy insert path**

```lua
  it("opens the selected prompt in a prompt buffer even when legacy insert opts are passed", function()
    local test_db = "/tmp/test_prompts.db"
    require("prompt").setup({ db_path = test_db })

    local db = require("prompt.db")
    local prompt_id = db.insert("picked prompt", "/tmp")

    local original_select = vim.ui.select
    local original_has_snacks = picker.has_snacks
    local buffer = require("prompt.buffer")
    local original_open = buffer.open_with_content
    local opened = nil

    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "current buffer" })

    vim.ui.select = function(items, _, on_choice)
      on_choice(items[1])
    end
    picker.has_snacks = function()
      return false
    end
    buffer.open_with_content = function(body, id)
      opened = { body = body, id = id }
    end

    picker.search({ mode = "insert" })

    local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    buffer.open_with_content = original_open
    picker.has_snacks = original_has_snacks
    vim.ui.select = original_select

    assert.are.same({ "current buffer" }, current_lines)
    assert.are.same({ body = "picked prompt", id = prompt_id }, opened)
  end)
```

This test locks in the migration behavior that matters: even if an old caller passes `{ mode = "insert" }`, selection should no longer mutate the current buffer.

- [ ] **Step 2: Run the suite and verify the new picker example fails first**

Run:
```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Expected: FAIL in `tests/prompt/picker_spec.lua` because the current picker still inserts text into the current buffer when `mode == "insert"`.

- [ ] **Step 3: Remove the insert branches and make prompt selection always open via `prompt.buffer.open_with_content`**

```lua
local M = {}

function M.has_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks ~= nil and snacks.picker ~= nil
end

function M.format_item(item)
  local date = (item.created_at or ""):sub(1, 10)
  local first_line = (item.body or ""):match("^([^\n]*)") or ""
  if #first_line > 80 then
    first_line = first_line:sub(1, 77) .. "..."
  end
  return string.format("[%s] %s", date, first_line)
end

---@param prompts table[]
local function pick_with_snacks(prompts)
  local items = {}
  for i, p in ipairs(prompts) do
    items[i] = {
      idx = i,
      score = i,
      text = M.format_item(p),
      item = p,
    }
  end

  require("snacks").picker({
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    preview = function(ctx)
      local p = ctx.item.item
      local lines = vim.split(p.body, "\n")
      ctx.preview:set_lines(lines)
      ctx.preview:highlight({ ft = "markdown" })
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      local p = item.item
      require("prompt.buffer").open_with_content(p.body, p.id)
    end,
    title = "Prompt History",
    layout = { preset = "default" },
  })
end

---@param prompts table[]
local function pick_with_ui_select(prompts)
  vim.ui.select(prompts, {
    prompt = "Prompt History: ",
    format_item = function(item)
      return M.format_item(item)
    end,
  }, function(selected)
    if not selected then
      return
    end
    require("prompt.buffer").open_with_content(selected.body, selected.id)
  end)
end

function M.search()
  local config = require("prompt").config
  if not config.db_path then
    require("prompt").setup()
    config = require("prompt").config
  end

  local db = require("prompt.db")
  db.setup(config.db_path)

  local prompts = db.all()
  if #prompts == 0 then
    vim.notify("No prompts found", vim.log.levels.INFO)
    return
  end

  if M.has_snacks() then
    pick_with_snacks(prompts)
  else
    pick_with_ui_select(prompts)
  end
end

return M
```

Also update `plugin/prompt.lua` so the eager `PromptSearch` command calls `require("prompt.picker").search()` with no mode table.

- [ ] **Step 4: Re-run the suite and confirm the picker behavior is now green**

Run:
```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Expected: PASS for the new picker example and the rest of the suite.

- [ ] **Step 5: Commit the picker simplification checkpoint**

```bash
git add lua/prompt/picker.lua plugin/prompt.lua tests/prompt/picker_spec.lua
git commit -m "refactor: remove prompt insert mode"
```

### Task 3: Update public docs and mark historical docs as superseded

**Files:**
- Modify: `README.md:5-62`
- Modify: `docs/specs/2026-03-28-prompt-nvim-design.md:1-92`
- Modify: `docs/plans/2026-03-28-prompt-nvim.md:1-9`

- [ ] **Step 1: Rewrite the README around commands plus user-owned mappings**

```md
# prompt.nvim

A Neovim plugin for managing AI agent prompts. Write prompts in Neovim, store them in SQLite with full-text search, and auto-copy to clipboard on save.

## Features

- **`:PromptNew`** — open a buffer, write a prompt, save+quit → clipboard + stored
- **`:PromptSearch`** — fuzzy search prompt history, pick one → opens in buffer for review/edit

## Requirements

- Neovim >= 0.9
- `sqlite3` CLI (installed on most systems)
- [Snacks.nvim](https://github.com/folke/snacks.nvim) (optional, for rich picker with preview; falls back to `vim.ui.select`)

## Installation

### lazy.nvim

```lua
{
  "mamachanko/prompt.nvim",
  dependencies = { "folke/snacks.nvim" }, -- optional
  opts = {},
  config = function(_, opts)
    require("prompt").setup(opts)
    vim.keymap.set("n", "<leader>fp", "<cmd>PromptSearch<CR>", {
      desc = "Find prompts",
    })
  end,
}
```

## Configuration

```lua
require("prompt").setup({
  db_path = "~/.prompts.db", -- default
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

### Optional keymaps

```lua
vim.keymap.set("n", "<leader>fp", "<cmd>PromptSearch<CR>", { desc = "Find prompts" })
vim.keymap.set("n", "<leader>fn", "<cmd>PromptNew<CR>", { desc = "New prompt" })
```

The plugin does not install any default keymaps; choose bindings that fit your own setup.

## License

Apache 2.0
```

- [ ] **Step 2: Add short historical notes to the archived design and implementation docs**

```md
> **Historical note (2026-04-19):** This document predates the keymap simplification. `prompt.nvim` no longer installs a default `<leader>fP` mapping or supports insert-from-picker. Use `:PromptSearch` and define any keymaps in your own config.
```

Place that note directly under the top-level heading in both `docs/specs/2026-03-28-prompt-nvim-design.md` and `docs/plans/2026-03-28-prompt-nvim.md` so old docs remain useful without reading as current behavior.

- [ ] **Step 3: Verify the old public surface is gone from live code and README**

Run:
```bash
rg -n '<leader>fP|keymap =|insert-from-picker|Find and insert a prompt|mode = "insert"' README.md lua/prompt plugin/prompt.lua
```

Expected: no matches.

- [ ] **Step 4: Run the full verification pass before the final docs commit**

Run:
```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
stylua --check lua/ plugin/ tests/
luacheck lua/ plugin/
```

Expected: tests PASS, `stylua` exits 0, and `luacheck` reports 0 warnings/errors.

- [ ] **Step 5: Commit the documentation and migration notes**

```bash
git add README.md docs/specs/2026-03-28-prompt-nvim-design.md docs/plans/2026-03-28-prompt-nvim.md
git commit -m "docs: document user-managed prompt search mappings"
```
