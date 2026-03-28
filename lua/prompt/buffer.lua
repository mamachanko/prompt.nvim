local M = {}

-- Track which buffers have been written and their original content
---@type table<number, {written: boolean, original_body: string|nil, original_id: number|nil}>
local buf_state = {}

--- Get the content of a buffer as a string
---@param bufnr number
---@return string
local function get_buf_content(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return ""
  end
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  return table.concat(lines, "\n")
end

--- Handle buffer cleanup: clipboard + DB save
---@param bufnr number
local function on_buf_leave(bufnr)
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

  -- Always copy to clipboard if was written
  require("prompt.clipboard").copy(body)

  -- Save to DB only if content is new or was modified
  if state.original_body ~= body then
    require("prompt.db").insert(body, vim.fn.getcwd())
  end

  buf_state[bufnr] = nil
end

--- Set up autocmds for a prompt buffer to track writes and handle cleanup
---@param bufnr number
local function setup_autocmds(bufnr)
  local group = vim.api.nvim_create_augroup("prompt_buf_" .. bufnr, { clear = true })

  -- Track writes via BufWritePost
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
      on_buf_leave(bufnr)
    end,
  })
end

--- Create a temporary file for the buffer to enable :w
---@return string path
local function create_temp_file()
  local tmpname = vim.fn.tempname()
  return tmpname .. "_prompt.md"
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

--- Check if a buffer was written (for testing)
---@param bufnr number
---@return boolean
function M.was_written(bufnr)
  local state = buf_state[bufnr]
  return state ~= nil and state.written
end

return M
