# prompt.nvim Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Neovim plugin that manages AI agent prompts — write in Neovim, store in SQLite with FTS, auto-copy to clipboard on save, search via Snacks.nvim picker with `vim.ui.select` fallback.

**Architecture:** Single Neovim plugin with four modules: `db` (SQLite via `sqlite3` CLI), `buffer` (scratch buffer lifecycle + write tracking), `clipboard` (platform detection + copy), `picker` (Snacks.nvim with `vim.ui.select` fallback). Entry point auto-loads and registers `:PromptNew`, `:PromptSearch`, and `<leader>fP`.

**Tech Stack:** Lua (Neovim), SQLite3 CLI, Snacks.nvim (optional), plenary.nvim (test only)

---

### Task 1: Project Scaffolding

**Files:**
- Create: `lua/prompt/init.lua`
- Create: `plugin/prompt.lua`
- Create: `.gitignore`
- Create: `LICENSE`
- Create: `README.md`
- Create: `.github/workflows/lint.yml`
- Create: `.github/workflows/test.yml`
- Create: `.luacheckrc`
- Create: `.stylua.toml`
- Create: `tests/minimal_init.lua`

- [ ] **Step 1: Create `.gitignore`**

```gitignore
*.db
*.swp
*.swo
*~
.luacheckcache/
```

- [ ] **Step 2: Create `.stylua.toml`**

```toml
column_width = 120
line_endings = "Unix"
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferDouble"
call_parentheses = "Always"
```

- [ ] **Step 3: Create `.luacheckrc`**

```lua
std = "luajit"
globals = { "vim" }
max_line_length = 140
ignore = {
  "212", -- unused argument
}
```

- [ ] **Step 4: Create `lua/prompt/init.lua` with minimal setup**

```lua
local M = {}

---@class prompt.Config
---@field db_path? string path to SQLite database (default: ~/.prompts.db)
---@field keymap? string keymap for insert-from-picker (default: <leader>fP)
local defaults = {
  db_path = vim.fn.expand("~/.prompts.db"),
  keymap = "<leader>fP",
}

M.config = {}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  vim.api.nvim_create_user_command("PromptNew", function()
    require("prompt.buffer").open_new()
  end, { desc = "Create a new prompt" })

  vim.api.nvim_create_user_command("PromptSearch", function()
    require("prompt.picker").search({ mode = "buffer" })
  end, { desc = "Search prompt history" })

  vim.keymap.set("n", M.config.keymap, function()
    require("prompt.picker").search({ mode = "insert" })
  end, { desc = "Find and insert a prompt" })
end

return M
```

- [ ] **Step 5: Create `plugin/prompt.lua` auto-load entry point**

```lua
if vim.g.loaded_prompt then
  return
end
vim.g.loaded_prompt = true

-- Auto-setup with defaults if user hasn't called setup explicitly
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if not require("prompt").config.db_path then
      require("prompt").setup()
    end
  end,
  once = true,
})
```

- [ ] **Step 6: Create `tests/minimal_init.lua`**

```lua
vim.opt.rtp:prepend(".")
vim.opt.rtp:prepend(os.getenv("PLENARY_DIR") or vim.fn.stdpath("data") .. "/lazy/plenary.nvim")
vim.cmd("runtime plugin/plenary.vim")
require("prompt").setup({ db_path = "/tmp/test_prompts.db" })
```

- [ ] **Step 7: Create `.github/workflows/lint.yml`**

```yaml
name: Lint
on: [push, pull_request]
jobs:
  stylua:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: JohnnyMorganz/stylua-action@v4
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          version: latest
          args: --check lua/ plugin/ tests/
  luacheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: lunarmodules/luacheck@v1
        with:
          args: lua/ plugin/
```

- [ ] **Step 8: Create `.github/workflows/test.yml`**

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        neovim: [stable, nightly]
    steps:
      - uses: actions/checkout@v4
      - uses: rhysd/action-setup-vim@v1
        with:
          neovim: true
          version: ${{ matrix.neovim }}
      - name: Install sqlite3
        run: sudo apt-get install -y sqlite3
      - name: Install plenary.nvim
        run: |
          mkdir -p ~/.local/share/nvim/lazy
          git clone --depth 1 https://github.com/nvim-lua/plenary.nvim ~/.local/share/nvim/lazy/plenary.nvim
      - name: Run tests
        env:
          PLENARY_DIR: ~/.local/share/nvim/lazy/plenary.nvim
        run: |
          nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

- [ ] **Step 9: Create placeholder `LICENSE` (MIT)**

```
MIT License

Copyright (c) 2026

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 10: Create placeholder `README.md`**

```markdown
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
  "youruser/prompt.nvim",
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

## Shell Aliases (optional)

```bash
alias prompt='nvim -c "PromptNew"'
alias ps='nvim -c "PromptSearch"'
```

## License

MIT
```

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "chore: project scaffolding with CI, linting, test harness"
```

---

### Task 2: SQLite Database Module

**Files:**
- Create: `lua/prompt/db.lua`
- Create: `tests/prompt/db_spec.lua`

- [ ] **Step 1: Write the failing tests**

Create `tests/prompt/db_spec.lua`:

```lua
local db = require("prompt.db")

describe("prompt.db", function()
  local test_db = "/tmp/test_prompt_db_" .. os.time() .. ".db"

  before_each(function()
    os.remove(test_db)
    db.setup(test_db)
  end)

  after_each(function()
    os.remove(test_db)
  end)

  it("creates the database and tables on setup", function()
    -- Check the file exists
    local f = io.open(test_db, "r")
    assert.is_not_nil(f)
    if f then
      f:close()
    end
  end)

  it("inserts a prompt and retrieves it by id", function()
    local id = db.insert("hello world", "/home/user/project")
    assert.is_not_nil(id)
    assert.is_true(id > 0)

    local prompt = db.get(id)
    assert.is_not_nil(prompt)
    assert.are.equal("hello world", prompt.body)
    assert.are.equal("/home/user/project", prompt.cwd)
    assert.is_not_nil(prompt.created_at)
  end)

  it("searches prompts with full-text search", function()
    db.insert("refactor the authentication module", "/proj/a")
    db.insert("write unit tests for parser", "/proj/b")
    db.insert("fix authentication bug in login", "/proj/c")

    local results = db.search("authentication")
    assert.are.equal(2, #results)
  end)

  it("returns all prompts ordered by most recent first", function()
    db.insert("first prompt", "/proj")
    db.insert("second prompt", "/proj")
    db.insert("third prompt", "/proj")

    local all = db.all()
    assert.are.equal(3, #all)
    assert.are.equal("third prompt", all[1].body)
    assert.are.equal("first prompt", all[3].body)
  end)

  it("checks if a prompt body already exists", function()
    db.insert("unique prompt", "/proj")
    assert.is_true(db.exists("unique prompt"))
    assert.is_false(db.exists("nonexistent prompt"))
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/db_spec.lua"`
Expected: FAIL — module `prompt.db` not found

- [ ] **Step 3: Implement `lua/prompt/db.lua`**

```lua
local M = {}

local db_path = nil

--- Shell-escape a string for passing to sqlite3
---@param s string
---@return string
local function escape(s)
  if s == nil then
    return ""
  end
  -- Escape single quotes for SQL
  return s:gsub("'", "''")
end

--- Run a sqlite3 command and return stdout
---@param args string sqlite3 arguments (flags + SQL)
---@return string
local function exec(args)
  local cmd = string.format("sqlite3 %s %s", vim.fn.shellescape(db_path), args)
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    error("sqlite3 error: " .. result)
  end
  return result
end

--- Run a SQL statement (no output expected)
---@param sql string
local function run(sql)
  exec(vim.fn.shellescape(sql))
end

--- Run a query and return rows as a list of tables
---@param sql string
---@return table[]
local function query(sql)
  local raw = exec("-json " .. vim.fn.shellescape(sql))
  if raw == nil or raw == "" then
    return {}
  end
  local ok, decoded = pcall(vim.json.decode, raw)
  if not ok then
    return {}
  end
  return decoded
end

--- Initialize the database schema
---@param path string
function M.setup(path)
  db_path = path
  run([[
    CREATE TABLE IF NOT EXISTS prompts (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      body TEXT NOT NULL,
      created_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now', 'localtime')),
      cwd TEXT
    );
    CREATE VIRTUAL TABLE IF NOT EXISTS prompts_fts USING fts5(body, content=prompts, content_rowid=id);
    CREATE TRIGGER IF NOT EXISTS prompts_ai AFTER INSERT ON prompts BEGIN
      INSERT INTO prompts_fts(rowid, body) VALUES (new.id, new.body);
    END;
    CREATE TRIGGER IF NOT EXISTS prompts_ad AFTER DELETE ON prompts BEGIN
      INSERT INTO prompts_fts(prompts_fts, rowid, body) VALUES('delete', old.id, old.body);
    END;
    CREATE TRIGGER IF NOT EXISTS prompts_au AFTER UPDATE ON prompts BEGIN
      INSERT INTO prompts_fts(prompts_fts, rowid, body) VALUES('delete', old.id, old.body);
      INSERT INTO prompts_fts(rowid, body) VALUES (new.id, new.body);
    END;
  ]])
end

--- Insert a new prompt
---@param body string
---@param cwd string|nil
---@return number id
function M.insert(body, cwd)
  run(string.format(
    "INSERT INTO prompts (body, cwd) VALUES ('%s', '%s');",
    escape(body),
    escape(cwd or "")
  ))
  local raw = exec(vim.fn.shellescape("SELECT last_insert_rowid();"))
  return tonumber(raw) or 0
end

--- Get a prompt by ID
---@param id number
---@return table|nil
function M.get(id)
  local rows = query(string.format("SELECT id, body, created_at, cwd FROM prompts WHERE id = %d;", id), {})
  if #rows == 0 then
    return nil
  end
  return rows[1]
end

--- Full-text search for prompts
---@param term string
---@return table[]
function M.search(term)
  return query(string.format(
    "SELECT p.id, p.body, p.created_at, p.cwd FROM prompts p INNER JOIN prompts_fts f ON p.id = f.rowid WHERE prompts_fts MATCH '%s' ORDER BY p.id DESC;",
    escape(term)
  ), {})
end

--- Return all prompts, most recent first
---@return table[]
function M.all()
  return query("SELECT id, body, created_at, cwd FROM prompts ORDER BY id DESC;", {})
end

--- Check if a prompt with the exact body already exists
---@param body string
---@return boolean
function M.exists(body)
  local raw = exec(vim.fn.shellescape(string.format(
    "SELECT COUNT(*) FROM prompts WHERE body = '%s';",
    escape(body)
  )))
  return tonumber(raw) ~= nil and tonumber(raw) > 0
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/db_spec.lua"`
Expected: All 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lua/prompt/db.lua tests/prompt/db_spec.lua
git commit -m "feat: SQLite database module with FTS5 full-text search"
```

---

### Task 3: Clipboard Module

**Files:**
- Create: `lua/prompt/clipboard.lua`
- Create: `tests/prompt/clipboard_spec.lua`

- [ ] **Step 1: Write the failing tests**

Create `tests/prompt/clipboard_spec.lua`:

```lua
local clipboard = require("prompt.clipboard")

describe("prompt.clipboard", function()
  it("detects a clipboard method without error", function()
    -- Should not throw; on CI it may fall back to Neovim registers
    local method = clipboard.detect()
    assert.is_not_nil(method)
    assert.is_true(vim.tbl_contains({ "pbcopy", "xclip", "xsel", "wl-copy", "neovim" }, method))
  end)

  it("copies text without error", function()
    -- Smoke test — just ensure it doesn't throw
    assert.has_no.errors(function()
      clipboard.copy("test prompt content")
    end)
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/clipboard_spec.lua"`
Expected: FAIL — module `prompt.clipboard` not found

- [ ] **Step 3: Implement `lua/prompt/clipboard.lua`**

```lua
local M = {}

local method_cache = nil

--- Detect the available clipboard method
---@return string method name
function M.detect()
  if method_cache then
    return method_cache
  end

  if vim.fn.executable("pbcopy") == 1 then
    method_cache = "pbcopy"
  elseif vim.fn.executable("wl-copy") == 1 then
    method_cache = "wl-copy"
  elseif vim.fn.executable("xclip") == 1 then
    method_cache = "xclip"
  elseif vim.fn.executable("xsel") == 1 then
    method_cache = "xsel"
  else
    method_cache = "neovim"
  end

  return method_cache
end

--- Copy text to system clipboard
---@param text string
function M.copy(text)
  local method = M.detect()

  if method == "neovim" then
    vim.fn.setreg("+", text)
    return
  end

  local cmd_map = {
    pbcopy = "pbcopy",
    ["wl-copy"] = "wl-copy",
    xclip = "xclip -selection clipboard",
    xsel = "xsel --clipboard --input",
  }

  local cmd = cmd_map[method]
  local handle = io.popen(cmd, "w")
  if handle then
    handle:write(text)
    handle:close()
  else
    -- Fallback to neovim register
    vim.fn.setreg("+", text)
  end
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/clipboard_spec.lua"`
Expected: All 2 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lua/prompt/clipboard.lua tests/prompt/clipboard_spec.lua
git commit -m "feat: clipboard module with platform detection"
```

---

### Task 4: Buffer Lifecycle Module

**Files:**
- Create: `lua/prompt/buffer.lua`
- Create: `tests/prompt/buffer_spec.lua`

- [ ] **Step 1: Write the failing tests**

Create `tests/prompt/buffer_spec.lua`:

```lua
local buffer = require("prompt.buffer")

describe("prompt.buffer", function()
  before_each(function()
    -- Clean up test DB
    local test_db = "/tmp/test_prompts.db"
    os.remove(test_db)
    require("prompt.db").setup(test_db)
  end)

  it("creates a scratch buffer with correct options", function()
    local bufnr = buffer.open_new()
    assert.is_not_nil(bufnr)
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    assert.are.equal("markdown", vim.bo[bufnr].filetype)
    assert.is_true(vim.wo[vim.fn.bufwinid(bufnr)].wrap)
  end)

  it("creates a buffer with existing content for search results", function()
    local bufnr = buffer.open_with_content("existing prompt", 42)
    assert.is_not_nil(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local text = table.concat(lines, "\n")
    assert.are.equal("existing prompt", text)
  end)

  it("tracks whether buffer was written", function()
    local bufnr = buffer.open_new()
    assert.is_false(buffer.was_written(bufnr))
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/buffer_spec.lua"`
Expected: FAIL — module `prompt.buffer` not found

- [ ] **Step 3: Implement `lua/prompt/buffer.lua`**

```lua
local M = {}

-- Track which buffers have been written and their original content
---@type table<number, {written: boolean, original_body: string|nil, original_id: number|nil}>
local buf_state = {}

--- Get the content of a buffer as a string
---@param bufnr number
---@return string
local function get_buf_content(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

--- Set up autocmds for a prompt buffer to track writes and handle cleanup
---@param bufnr number
local function setup_autocmds(bufnr)
  local group = vim.api.nvim_create_augroup("prompt_buf_" .. bufnr, { clear = true })

  -- Track writes
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    buffer = bufnr,
    callback = function()
      if buf_state[bufnr] then
        buf_state[bufnr].written = true
      end
    end,
  })

  -- On buffer unload: clipboard + DB if was written
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    buffer = bufnr,
    callback = function()
      local state = buf_state[bufnr]
      if not state or not state.written then
        buf_state[bufnr] = nil
        return
      end

      local body = get_buf_content(bufnr)
      if body == "" or body:match("^%s*$") then
        buf_state[bufnr] = nil
        return
      end

      -- Copy to clipboard
      require("prompt.clipboard").copy(body)

      -- Save to DB if content changed (or is new)
      if state.original_body ~= body then
        local db = require("prompt.db")
        db.insert(body, vim.fn.getcwd())
      end

      buf_state[bufnr] = nil
    end,
  })
end

--- Create a temporary file for the buffer to enable :w
---@return string path
local function create_temp_file()
  local tmpdir = vim.fn.tempname()
  return tmpdir .. "_prompt.md"
end

--- Open a new empty prompt buffer
---@return number bufnr
function M.open_new()
  local tmpfile = create_temp_file()
  vim.fn.writefile({}, tmpfile)

  vim.cmd("edit " .. vim.fn.fnameescape(tmpfile))
  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].filetype = "markdown"
  local winid = vim.fn.bufwinid(bufnr)
  if winid ~= -1 then
    vim.wo[winid].wrap = true
  end

  buf_state[bufnr] = { written = false, original_body = nil, original_id = nil }
  setup_autocmds(bufnr)

  -- Enter insert mode
  vim.cmd("startinsert")

  return bufnr
end

--- Open a buffer with existing prompt content (from search)
---@param body string
---@param id number|nil the DB id of the original prompt
---@return number bufnr
function M.open_with_content(body, id)
  local tmpfile = create_temp_file()
  local lines = vim.split(body, "\n")
  vim.fn.writefile(lines, tmpfile)

  vim.cmd("edit " .. vim.fn.fnameescape(tmpfile))
  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].filetype = "markdown"
  local winid = vim.fn.bufwinid(bufnr)
  if winid ~= -1 then
    vim.wo[winid].wrap = true
  end

  buf_state[bufnr] = { written = false, original_body = body, original_id = id }
  setup_autocmds(bufnr)

  return bufnr
end

--- Check if a buffer was written
---@param bufnr number
---@return boolean
function M.was_written(bufnr)
  local state = buf_state[bufnr]
  return state ~= nil and state.written
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/buffer_spec.lua"`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lua/prompt/buffer.lua tests/prompt/buffer_spec.lua
git commit -m "feat: buffer lifecycle with write tracking and auto-clipboard"
```

---

### Task 5: Picker Module (Snacks.nvim + `vim.ui.select` Fallback)

**Files:**
- Create: `lua/prompt/picker.lua`
- Create: `tests/prompt/picker_spec.lua`

- [ ] **Step 1: Write the failing tests**

Create `tests/prompt/picker_spec.lua`:

```lua
local picker = require("prompt.picker")

describe("prompt.picker", function()
  before_each(function()
    local test_db = "/tmp/test_prompts.db"
    os.remove(test_db)
    require("prompt.db").setup(test_db)
  end)

  it("has a search function", function()
    assert.is_function(picker.search)
  end)

  it("detects snacks availability", function()
    local has_snacks = picker.has_snacks()
    -- In test environment, snacks is likely not available
    assert.is_true(type(has_snacks) == "boolean")
  end)

  it("formats a prompt item for display", function()
    local item = {
      id = 1,
      body = "refactor the auth module\nand add tests",
      created_at = "2026-03-28T14:30:00",
      cwd = "/home/user/project",
    }
    local display = picker.format_item(item)
    assert.is_not_nil(display)
    assert.is_true(type(display) == "string")
    -- Should show date and first line
    assert.is_truthy(display:find("2026%-03%-28"))
    assert.is_truthy(display:find("refactor the auth module"))
  end)
end)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/picker_spec.lua"`
Expected: FAIL — module `prompt.picker` not found

- [ ] **Step 3: Implement `lua/prompt/picker.lua`**

```lua
local M = {}

--- Check if Snacks.nvim picker is available
---@return boolean
function M.has_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks.picker ~= nil
end

--- Format a prompt item for display in picker list
---@param item table prompt row from DB
---@return string
function M.format_item(item)
  local date = (item.created_at or ""):sub(1, 10)
  local first_line = (item.body or ""):match("^([^\n]*)") or ""
  -- Truncate long first lines
  if #first_line > 80 then
    first_line = first_line:sub(1, 77) .. "..."
  end
  return string.format("[%s] %s", date, first_line)
end

--- Open picker using Snacks.nvim
---@param prompts table[] list of prompt rows
---@param opts {mode: "buffer"|"insert"}
local function pick_with_snacks(prompts, opts)
  local items = {}
  for i, p in ipairs(prompts) do
    items[i] = {
      idx = i,
      score = i,
      text = M.format_item(p),
      item = p,
      preview = {
        text = p.body,
        ft = "markdown",
      },
    }
  end

  require("snacks").picker({
    items = items,
    format = function(item)
      return { { item.text } }
    end,
    preview = function(ctx)
      local p = ctx.item.item
      ctx.preview:set_lines(vim.split(p.body, "\n"))
      ctx.preview:highlight({ ft = "markdown" })
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      local p = item.item
      if opts.mode == "insert" then
        local lines = vim.split(p.body, "\n")
        local row, col = unpack(vim.api.nvim_win_get_cursor(0))
        vim.api.nvim_buf_set_lines(0, row, row, false, lines)
      else
        require("prompt.buffer").open_with_content(p.body, p.id)
      end
    end,
    title = "Prompt History",
    layout = { preset = "default" },
  })
end

--- Open picker using vim.ui.select fallback
---@param prompts table[] list of prompt rows
---@param opts {mode: "buffer"|"insert"}
local function pick_with_ui_select(prompts, opts)
  vim.ui.select(prompts, {
    prompt = "Prompt History: ",
    format_item = function(item)
      return M.format_item(item)
    end,
  }, function(selected)
    if not selected then
      return
    end
    if opts.mode == "insert" then
      local lines = vim.split(selected.body, "\n")
      local row, _ = unpack(vim.api.nvim_win_get_cursor(0))
      vim.api.nvim_buf_set_lines(0, row, row, false, lines)
    else
      require("prompt.buffer").open_with_content(selected.body, selected.id)
    end
  end)
end

--- Search prompt history and open picker
---@param opts? {mode?: "buffer"|"insert"}
function M.search(opts)
  opts = opts or {}
  opts.mode = opts.mode or "buffer"

  local db = require("prompt.db")
  local config = require("prompt").config
  if not config.db_path then
    require("prompt").setup()
  end

  -- Initialize DB if needed
  db.setup(config.db_path)

  local prompts = db.all()
  if #prompts == 0 then
    vim.notify("No prompts found", vim.log.levels.INFO)
    return
  end

  if M.has_snacks() then
    pick_with_snacks(prompts, opts)
  else
    pick_with_ui_select(prompts, opts)
  end
end

return M
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/picker_spec.lua"`
Expected: All 3 tests PASS

- [ ] **Step 5: Commit**

```bash
git add lua/prompt/picker.lua tests/prompt/picker_spec.lua
git commit -m "feat: picker module with Snacks.nvim and vim.ui.select fallback"
```

---

### Task 6: Integration — Wire Everything Together

**Files:**
- Modify: `lua/prompt/init.lua`
- Modify: `plugin/prompt.lua`
- Create: `tests/prompt/integration_spec.lua`

- [ ] **Step 1: Write the integration tests**

Create `tests/prompt/integration_spec.lua`:

```lua
describe("prompt.nvim integration", function()
  local test_db = "/tmp/test_prompt_integration_" .. os.time() .. ".db"

  before_each(function()
    os.remove(test_db)
    require("prompt").setup({ db_path = test_db })
  end)

  after_each(function()
    os.remove(test_db)
  end)

  it("registers PromptNew command", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands["PromptNew"])
  end)

  it("registers PromptSearch command", function()
    local commands = vim.api.nvim_get_commands({})
    assert.is_not_nil(commands["PromptSearch"])
  end)

  it("PromptNew creates a buffer with correct filetype", function()
    vim.cmd("PromptNew")
    local bufnr = vim.api.nvim_get_current_buf()
    assert.are.equal("markdown", vim.bo[bufnr].filetype)
  end)

  it("full cycle: setup creates DB, insert works, search finds it", function()
    local db = require("prompt.db")
    db.setup(test_db)
    db.insert("integration test prompt", "/tmp")
    local results = db.search("integration")
    assert.are.equal(1, #results)
    assert.are.equal("integration test prompt", results[1].body)
  end)
end)
```

- [ ] **Step 2: Run integration tests**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedFile tests/prompt/integration_spec.lua"`
Expected: All 4 tests PASS

- [ ] **Step 3: Update `plugin/prompt.lua` for lazy-loading**

Replace `plugin/prompt.lua` with:

```lua
if vim.g.loaded_prompt then
  return
end
vim.g.loaded_prompt = true

-- Register commands immediately so they work with `nvim -c "PromptNew"` before VimEnter
vim.api.nvim_create_user_command("PromptNew", function()
  require("prompt").setup()
  require("prompt.buffer").open_new()
end, { desc = "Create a new prompt" })

vim.api.nvim_create_user_command("PromptSearch", function()
  require("prompt").setup()
  require("prompt.picker").search({ mode = "buffer" })
end, { desc = "Search prompt history" })
```

- [ ] **Step 4: Update `lua/prompt/init.lua` for idempotent setup**

Replace `lua/prompt/init.lua` with:

```lua
local M = {}

---@class prompt.Config
---@field db_path? string path to SQLite database (default: ~/.prompts.db)
---@field keymap? string keymap for insert-from-picker (default: <leader>fP)
local defaults = {
  db_path = vim.fn.expand("~/.prompts.db"),
  keymap = "<leader>fP",
}

M.config = {}

local did_setup = false

function M.setup(opts)
  if did_setup and opts == nil then
    return
  end
  did_setup = true

  M.config = vim.tbl_deep_extend("force", defaults, opts or {})

  -- Initialize DB
  require("prompt.db").setup(M.config.db_path)

  -- Register commands (may already exist from plugin/prompt.lua, so override)
  vim.api.nvim_create_user_command("PromptNew", function()
    require("prompt.buffer").open_new()
  end, { force = true, desc = "Create a new prompt" })

  vim.api.nvim_create_user_command("PromptSearch", function()
    require("prompt.picker").search({ mode = "buffer" })
  end, { force = true, desc = "Search prompt history" })

  -- Keybinding for insert-from-picker
  vim.keymap.set("n", M.config.keymap, function()
    require("prompt.picker").search({ mode = "insert" })
  end, { desc = "Find and insert a prompt" })
end

return M
```

- [ ] **Step 5: Run all tests**

Run: `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"`
Expected: All tests PASS (14 total)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: wire up all modules, integration tests, lazy-load support"
```

---

### Task 7: Final Polish — README and Lint

**Files:**
- Modify: `README.md` (already created in Task 1, verify it's accurate)

- [ ] **Step 1: Run stylua**

```bash
stylua lua/ plugin/ tests/
```

- [ ] **Step 2: Run luacheck**

```bash
luacheck lua/ plugin/
```

Fix any issues found.

- [ ] **Step 3: Run full test suite one final time**

```bash
nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"
```

Expected: All tests PASS

- [ ] **Step 4: Commit any lint fixes**

```bash
git add -A
git commit -m "style: format with stylua, fix luacheck warnings"
```

- [ ] **Step 5: Tag initial release**

```bash
git tag v0.1.0
git log --oneline
```
