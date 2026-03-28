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

  -- Register commands
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
