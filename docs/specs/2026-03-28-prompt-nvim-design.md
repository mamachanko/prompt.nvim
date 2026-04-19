# prompt.nvim — Design Spec

> **Historical note (2026-04-19):** This document predates the keymap simplification. `prompt.nvim` no longer installs a default `<leader>fP` mapping or supports insert-from-picker. Use `:PromptSearch` and define any keymaps in your own config.

**Date:** 2026-03-28

## Overview

A Neovim plugin for managing prompts when working with AI coding agents. Prompts are written and edited in Neovim, stored in a local SQLite database with full-text search, and automatically copied to the system clipboard on save. Search is integrated via Snacks.nvim picker.

## Problem

Writing prompts for agent CLIs (Cursor, Claude, etc.) in the terminal is a poor editing experience. Users who prefer Vim end up with ad-hoc workflows: a single growing file with manual delimiters, visual-select + yank to copy, and Vim search to find old prompts. This works but doesn't scale and lacks structure.

## Solution

A single Neovim plugin that handles the full prompt lifecycle: create, edit, search, reuse. The plugin stores prompts in SQLite with full-text search and auto-copies to clipboard on save. Users define their own shell aliases to launch it.

## User Experience

### Writing a new prompt

1. User runs their alias (e.g., `nvim -c "PromptNew"`)
2. Neovim opens with an empty buffer, insert mode, wrap enabled
3. User writes the prompt
4. On `:wq` — content is saved to SQLite DB and copied to system clipboard
5. On `:q!` (never saved) — nothing happens, no DB entry, no clipboard
6. User pastes into their agent pane

### Finding an old prompt from the terminal

1. User runs their alias (e.g., `nvim -c "PromptSearch"`)
2. Snacks.nvim picker opens with fuzzy search over all stored prompts
3. Preview pane shows the full prompt text
4. User selects a prompt — it opens in a Neovim buffer
5. User reviews, optionally edits
6. Same save/quit behavior: `:wq` → clipboard + saved as new entry if modified, `:q!` → nothing

### Finding an old prompt from within Neovim (mid-edit)

1. User presses `<leader>fP`
2. Snacks.nvim picker opens over prompt history
3. User selects a prompt — its text is inserted at cursor position in the current buffer
4. User continues editing; normal save+quit flow handles the rest

### The core mental model

- Neovim is always where you decide and act
- Exiting Neovim with a save always means "ready to paste"
- Three entry points (`:PromptNew`, `:PromptSearch`, `<leader>fP`), one consistent behavior

## Architecture

### Single Neovim plugin

All logic lives in the plugin. No external shell scripts to install or maintain.

### Components

1. **Prompt buffer management** — creates scratch buffers with appropriate settings (wrap, filetype, insert mode), tracks whether the buffer was written
2. **SQLite interface** — shells out to `sqlite3` CLI for all DB operations. No compiled Lua dependencies.
3. **Clipboard integration** — detects platform clipboard tool (`pbcopy`, `xclip`, `wl-copy`, or Neovim's `vim.fn.setreg('+', ...)`) and copies prompt content on save+quit
4. **Picker integration** — Snacks.nvim picker with preview as primary search UI, falls back to `vim.ui.select` for users without Snacks

### Storage

- **File:** `~/.prompts.db` (single SQLite file, auto-created on first use)
- **Full-text search:** SQLite FTS5 for fast fuzzy matching
- **Auto-captured metadata:** timestamp, working directory. No manual tagging.
- **Backup:** Copy one file. That's it.

### Dependencies

- `sqlite3` CLI — present on virtually all systems
- Snacks.nvim — optional, used for rich picker with preview. Falls back to `vim.ui.select` if unavailable
- System clipboard tool — `pbcopy` (macOS), `xclip` or `wl-copy` (Linux), or Neovim's built-in clipboard support

No other dependencies. No build step. No compiled extensions.

## Plugin Interface

### Commands

| Command | Description |
|---------|-------------|
| `:PromptNew` | Open empty buffer for a new prompt |
| `:PromptSearch` | Open picker (Snacks if available, else `vim.ui.select`) to search prompt history, selected prompt opens in buffer |

### Keybindings

| Keybinding | Mode | Description |
|------------|------|-------------|
| `<leader>fP` | Normal | Open picker, insert selected prompt at cursor |

### Save/Quit Behavior

- Buffer tracks whether `:w` was called at any point during the session
- On `BufUnload`/`BufDelete`: if the buffer was written, copy content to clipboard and insert into DB
- If the prompt is identical to an existing entry opened via search (unmodified reuse), still copy to clipboard but do not create a duplicate DB entry

## Project Structure

```
prompt.nvim/
├── lua/
│   └── prompt/
│       ├── init.lua          # Plugin setup, command registration
│       ├── db.lua            # SQLite interface (via sqlite3 CLI)
│       ├── buffer.lua        # Buffer creation and lifecycle management
│       ├── clipboard.lua     # Platform clipboard detection and copy
│       └── picker.lua        # Snacks.nvim picker integration
├── plugin/
│   └── prompt.lua            # Auto-load entry point
├── docs/
│   └── specs/
│       └── 2026-03-28-prompt-nvim-design.md
├── README.md
├── LICENSE
├── .gitignore
└── .github/
    └── workflows/
        ├── lint.yml          # stylua + luacheck
        └── test.yml          # Neovim plugin tests
```

## What's Out of Scope

- Prompt templates or library management — may come later, not in v1
- Tagging or categorization — search-first, not organize-first
- Integration with specific agent CLIs — this is agent-agnostic
- Sync across machines — just back up the DB file
- Shell functions or aliases — user defines their own

## Open Questions (Resolved)

- **Storage format?** → SQLite with FTS5. Single file, fast search, trivial backup.
- **Search tool?** → Snacks.nvim picker inside Neovim. No fzf dependency.
- **Shell integration?** → None shipped. User aliases `nvim -c "PromptNew"` etc.
- **Clipboard signal?** → Buffer was written (`:w` called at least once) = clipboard. Never written = no clipboard.
- **Duplicate on reuse?** → Copy to clipboard always. Only create new DB entry if content was modified.
