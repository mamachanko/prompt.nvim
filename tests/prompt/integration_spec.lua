describe("prompt.nvim integration", function()
  local test_db = "/tmp/test_prompt_integration_" .. os.time() .. ".db"

  before_each(function()
    os.remove(test_db)
    -- Reset the module so setup runs fresh
    package.loaded["prompt"] = nil
    package.loaded["prompt.db"] = nil
    package.loaded["prompt.buffer"] = nil
    package.loaded["prompt.clipboard"] = nil
    package.loaded["prompt.picker"] = nil
    vim.g.loaded_prompt = nil
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
    db.insert("integration test prompt", "/tmp")
    local results = db.search("integration")
    assert.are.equal(1, #results)
    assert.are.equal("integration test prompt", results[1].body)
  end)

  it("idempotent setup does not error on second call", function()
    assert.has_no.errors(function()
      require("prompt").setup({ db_path = test_db })
    end)
  end)
end)
