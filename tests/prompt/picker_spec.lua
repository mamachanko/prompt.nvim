local picker = require("prompt.picker")

describe("prompt.picker", function()
  local test_db

  before_each(function()
    test_db = vim.fn.tempname() .. "_prompt_picker.db"
    os.remove(test_db)
    require("prompt.db").setup(test_db)
  end)

  after_each(function()
    os.remove(test_db)
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

  it("opens the selected prompt in a prompt buffer even when legacy insert opts are passed", function()
    require("prompt").setup({ db_path = test_db })

    local db = require("prompt.db")
    local prompt_id = db.insert("picked prompt", "/tmp")

    local original_select = vim.ui.select
    local original_has_snacks = picker.has_snacks
    local buffer = require("prompt.buffer")
    local original_open = buffer.open_with_content
    local opened = nil

    vim.cmd("enew")
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "current buffer" })

    vim.ui.select = function(items, _, on_choice)
      on_choice(items[1])
    end
    picker.has_snacks = function()
      return false
    end
    buffer.open_with_content = function(body, id)
      opened = { body = body, id = id }
    end

    picker.search({ mode = "insert" })

    local current_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)

    buffer.open_with_content = original_open
    picker.has_snacks = original_has_snacks
    vim.ui.select = original_select

    assert.are.same({ "current buffer" }, current_lines)
    assert.are.same({ body = "picked prompt", id = prompt_id }, opened)
  end)
end)
