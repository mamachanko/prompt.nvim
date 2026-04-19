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
  require("prompt.picker").search()
end, { desc = "Search prompt history" })
