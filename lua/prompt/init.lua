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

  -- Initialize DB
  require("prompt.db").setup(M.config.db_path)

  -- Register commands
  vim.api.nvim_create_user_command("PromptNew", function()
    require("prompt.buffer").open_new()
  end, { force = true, desc = "Create a new prompt" })

  vim.api.nvim_create_user_command("PromptSearch", function()
    require("prompt.picker").search()
  end, { force = true, desc = "Search prompt history" })
end

return M
