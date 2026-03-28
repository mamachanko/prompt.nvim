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
    assert.is_true(type(has_snacks) == "boolean")
  end)

  it("formats a prompt item for display with date and first line", function()
    local item = {
      id = 1,
      body = "refactor the auth module\nand add tests",
      created_at = "2026-03-28T14:30:00",
      cwd = "/home/user/project",
    }
    local display = picker.format_item(item)
    assert.is_not_nil(display)
    assert.is_truthy(display:find("2026%-03%-28"))
    assert.is_truthy(display:find("refactor the auth module"))
    -- Should NOT include the second line
    assert.is_falsy(display:find("and add tests"))
  end)

  it("truncates long first lines", function()
    local long_line = string.rep("a", 100)
    local item = {
      id = 1,
      body = long_line,
      created_at = "2026-03-28T14:30:00",
      cwd = "/proj",
    }
    local display = picker.format_item(item)
    -- [YYYY-MM-DD] + 77 chars + "..." = ~93 chars max
    assert.is_truthy(display:find("%.%.%."))
    assert.is_true(#display < 100)
  end)

  it("handles empty body gracefully", function()
    local item = { id = 1, body = "", created_at = "2026-03-28T14:30:00", cwd = "/proj" }
    local display = picker.format_item(item)
    assert.is_not_nil(display)
  end)
end)
