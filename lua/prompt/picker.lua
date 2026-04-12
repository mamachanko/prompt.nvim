local M = {}

--- Check if Snacks.nvim picker is available
---@return boolean
function M.has_snacks()
  local ok, snacks = pcall(require, "snacks")
  return ok and snacks ~= nil and snacks.picker ~= nil
end

--- Format a prompt item for display in picker list
---@param item table prompt row from DB
---@return string
function M.format_item(item)
  local date = (item.created_at or ""):sub(1, 10)
  local first_line = (item.body or ""):match("^([^\n]*)") or ""
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
      if opts.mode == "insert" then
        local lines = vim.split(p.body, "\n")
        local row = vim.api.nvim_win_get_cursor(0)[1]
        vim.api.nvim_buf_set_lines(0, row, row, false, lines)
      else
        require("prompt.buffer").open_with_content(p.body, p.id)
      end
    end,
    title = "Prompt History",
    layout = { preset = "default" },
    win = {
      preview = {
        wo = {
          wrap = true,
        },
      },
    },
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
      local row = vim.api.nvim_win_get_cursor(0)[1]
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
    pick_with_snacks(prompts, opts)
  else
    pick_with_ui_select(prompts, opts)
  end
end

return M
