local M = {}

local method_cache = nil

--- Detect the available clipboard method
---@return string method name
function M.detect()
  if method_cache then
    return method_cache
  end

  local has_wayland = vim.env.WAYLAND_DISPLAY ~= nil or vim.env.WAYLAND_SOCKET ~= nil
  local has_x11 = vim.env.DISPLAY ~= nil

  if vim.fn.executable("pbcopy") == 1 then
    method_cache = "pbcopy"
  elseif has_wayland and vim.fn.executable("wl-copy") == 1 then
    method_cache = "wl-copy"
  elseif has_x11 and vim.fn.executable("xclip") == 1 then
    method_cache = "xclip"
  elseif has_x11 and vim.fn.executable("xsel") == 1 then
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

--- Reset cached method (for testing)
function M._reset()
  method_cache = nil
end

return M
