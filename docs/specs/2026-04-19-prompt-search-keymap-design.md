# prompt.nvim — Keymap Simplification Design

**Date:** 2026-04-19

## Overview

This change simplifies prompt.nvim by removing its built-in normal-mode keymap and removing the insert-from-picker workflow entirely. The plugin will focus on two explicit entry points:

- `:PromptNew` — create a new prompt
- `:PromptSearch` — search existing prompts and open one for review or reuse

Users who want a keybinding will define it themselves in their Neovim configuration. The README will show a concise `lazy.nvim` example that maps a key to `:PromptSearch`.

## Problem

The current plugin behavior assumes an opinionated workflow:

- it claims a default `<leader>fP` mapping
- that mapping triggers insert-from-picker rather than search/open
- the behavior is surprising in configured environments such as AstroNvim, where users expect leader mappings to remain under their control

This creates two UX problems:

1. **Configuration conflict** — users may already have leader mappings or keybinding conventions in their distribution
2. **Conceptual mismatch** — a mapping that reads like “find prompt” currently performs “insert selected prompt into current buffer,” which is less intuitive than opening prompt history via search

## Approaches Considered

### 1. Keep insert workflow, but remove the default keymap

The plugin would stop claiming `<leader>fP`, but still keep `keymap` as an opt-in setting or keep the insert action as a supported public workflow.

**Pros**
- Minimal code churn
- Preserves all existing capabilities

**Cons**
- Retains a feature that no longer matches the desired product direction
- Keeps additional API and README complexity for a workflow that feels redundant

### 2. Keep both search/open and insert as first-class features

The plugin would expose both workflows clearly and document how users can map either one.

**Pros**
- Maximum flexibility
- No feature removal

**Cons**
- Less cohesive product story
- More commands, config, and docs to explain
- Makes the plugin feel split between “prompt manager” and “prompt inserter”

### 3. Remove insert entirely and let users map `:PromptSearch` themselves

The plugin would focus on creating and finding prompts. No default mapping would be installed. README examples would show user-managed mappings.

**Pros**
- Clearer product scope
- No opinionated leader mapping
- Better fit for lazy.nvim and Neovim distributions
- Easier README and smaller API surface

**Cons**
- Breaking change for anyone using insert-from-picker today

## Recommendation

Choose **Approach 3**.

prompt.nvim should be a focused tool for writing and revisiting prompts, not for inserting prompt snippets into arbitrary buffers. Searching existing prompts and opening them is the more intuitive “find a prompt” action, so that should remain the primary retrieval workflow.

## Design

### Product behavior

The plugin will support two user-facing actions:

- `:PromptNew`
- `:PromptSearch`

The following behavior will be removed:

- built-in default keymap registration
- `keymap` configuration option
- insert-from-picker mode and any dedicated implementation paths for it

### Public interface

After this change, the public interface is command-first:

| Command | Description |
|---------|-------------|
| `:PromptNew` | Open a new prompt buffer |
| `:PromptSearch` | Search prompt history and open the selected prompt |

There will be **no default keybindings**.

Users who want a mapping can define one in their own setup. The documentation should make clear that the key is only an example and should be adapted to the user’s conventions.

### README direction

The README should stop advertising a built-in `<leader>fP` mapping and instead show how users can add their own mapping.

The primary installation example should favor a concise `lazy.nvim` configuration that sets up the plugin and then defines a normal keymap with `vim.keymap.set`, for example:

```lua
{
  "mamachanko/prompt.nvim",
  dependencies = { "folke/snacks.nvim" },
  opts = {},
  config = function(_, opts)
    require("prompt").setup(opts)
    vim.keymap.set("n", "<leader>fp", "<cmd>PromptSearch<CR>", {
      desc = "Find prompts",
    })
  end,
}
```

This keeps the example short while still making it explicit that the mapping belongs to the user config, not the plugin.

A short note may mention that users can also map `:PromptNew` if they prefer a dedicated shortcut for starting a new prompt.

### Internal code changes

The implementation should simplify `lua/prompt/init.lua` and related picker logic:

1. Remove `keymap` from the config type and defaults
2. Stop calling `vim.keymap.set` during plugin setup
3. Remove insert-mode search flow from the picker module
4. Ensure `:PromptSearch` always means search and open in a prompt buffer
5. Update any docs, plans, and tests that mention the old insert workflow

### Compatibility and migration

This is a small breaking change.

Users upgrading from the old version will need to:

- remove any reliance on plugin-managed `keymap` setup
- define their own mapping if desired
- switch from the old insert mental model to `:PromptSearch` for finding prompts

The README should present this cleanly by documenting only the new command-first workflow.

## Testing

The change should be verified with focused tests and manual checks:

1. `require("prompt").setup()` succeeds without any keymap option
2. `:PromptNew` still opens a new prompt buffer
3. `:PromptSearch` still opens the picker and selected prompt buffer
4. No plugin-installed keymap is created during setup
5. README examples align with actual public commands

## Scope

In scope:

- removing built-in keymap support
- removing insert-from-picker
- updating docs to show user-defined mappings to `:PromptSearch`

Out of scope:

- adding new commands beyond `:PromptNew` and `:PromptSearch`
- introducing a plugin-managed opt-in keymap API
- broader workflow changes unrelated to prompt creation and prompt search
