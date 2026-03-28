local buffer = require("prompt.buffer")

describe("prompt.buffer", function()
  before_each(function()
    local test_db = "/tmp/test_prompts.db"
    os.remove(test_db)
    require("prompt.db").setup(test_db)
  end)

  it("creates a scratch buffer with correct options", function()
    local bufnr = buffer.open_new()
    assert.is_not_nil(bufnr)
    assert.is_true(vim.api.nvim_buf_is_valid(bufnr))
    assert.are.equal("markdown", vim.bo[bufnr].filetype)
    local winid = vim.fn.bufwinid(bufnr)
    if winid ~= -1 then
      assert.is_true(vim.wo[winid].wrap)
    end
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

  it("opens with multiline content correctly", function()
    local body = "line one\nline two\nline three"
    local bufnr = buffer.open_with_content(body, 1)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    assert.are.equal(3, #lines)
    assert.are.equal("line one", lines[1])
    assert.are.equal("line three", lines[3])
  end)
end)
