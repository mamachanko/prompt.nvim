local clipboard = require("prompt.clipboard")

describe("prompt.clipboard", function()
  before_each(function()
    clipboard._reset()
  end)

  it("detects a clipboard method without error", function()
    local method = clipboard.detect()
    assert.is_not_nil(method)
    assert.is_true(vim.tbl_contains({ "pbcopy", "xclip", "xsel", "wl-copy", "neovim" }, method))
  end)

  it("copies text without error", function()
    assert.has_no.errors(function()
      clipboard.copy("test prompt content")
    end)
  end)

  it("caches the detection result", function()
    local first = clipboard.detect()
    local second = clipboard.detect()
    assert.are.equal(first, second)
  end)

  it("falls back to neovim in a headless environment", function()
    local original_executable = vim.fn.executable
    local original_display = vim.env.DISPLAY
    local original_wayland_display = vim.env.WAYLAND_DISPLAY
    local original_wayland_socket = vim.env.WAYLAND_SOCKET

    vim.env.DISPLAY = nil
    vim.env.WAYLAND_DISPLAY = nil
    vim.env.WAYLAND_SOCKET = nil
    vim.fn.executable = function(cmd)
      if cmd == "xclip" or cmd == "xsel" or cmd == "wl-copy" then
        return 1
      end
      return original_executable(cmd)
    end

    clipboard._reset()
    local method = clipboard.detect()

    vim.fn.executable = original_executable
    vim.env.DISPLAY = original_display
    vim.env.WAYLAND_DISPLAY = original_wayland_display
    vim.env.WAYLAND_SOCKET = original_wayland_socket

    assert.are.equal("neovim", method)
  end)
end)
