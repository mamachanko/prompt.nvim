# prompt.nvim — Local Check Workflow Design

**Date:** 2026-04-19

## Overview

Add a small `Makefile` that gives contributors one canonical local verification entrypoint:

- `make lint`
- `make test`
- `make check`

`make check` will run `lint` and `test`. The targets will assume required tools are already installed locally, but they must fail with clear, actionable messages when tools are missing. GitHub Actions should stop duplicating raw shell commands and instead call the same make targets so local and CI workflows stay aligned.

## Context

Today the repo has no `Makefile`. CI runs raw commands directly in workflow files:

- `.github/workflows/lint.yml`
- `.github/workflows/test.yml`

That means contributors can miss issues locally that CI catches later, as happened here with `stylua` formatting and `luacheck` line-length failures.

I also checked for project-local `AGENTS.md` guidance before designing this change; there is no `AGENTS.md` file in this repository.

## Problem

The current workflow has three friction points:

1. **No single local check command** — contributors must remember multiple commands
2. **CI and local drift risk** — workflows embed commands directly instead of sharing a common interface
3. **Poor local ergonomics when tools are missing** — failures happen late, and install expectations are implicit

## Approaches Considered

### 1. Add a local-only `Makefile`

Create `make lint`, `make test`, and `make check` for developers, but leave CI workflows unchanged.

**Pros**
- Smallest change
- Improves local experience immediately

**Cons**
- CI and local commands can drift again
- Still leaves workflows as a second source of truth

### 2. Add canonical make targets and have CI call them directly

Create a `Makefile` as the single command surface, then switch CI jobs to invoke `make lint` and `make test` instead of inline shell commands.

**Pros**
- Keeps local and CI behavior aligned
- Preserves the existing CI split between lint and test jobs
- Supports a clean local `make check` umbrella target

**Cons**
- Adds one small abstraction layer to the repo

### 3. Make CI call only `make check`

Use one umbrella target for both local and CI.

**Pros**
- Simplest mental model
- One command everywhere

**Cons**
- Less natural fit for the current split workflows
- If run inside the test matrix, lint would run redundantly in each matrix job
- If moved to a single job, stable/nightly test separation is weakened

## Recommendation

Choose **Approach 2**.

Use a small `Makefile` as the canonical command interface, with:

- `make lint`
- `make test`
- `make check` → depends on `lint` and `test`

Then update CI to call `make lint` and `make test` rather than repeating the commands directly.

## Design

### Make targets

The `Makefile` should provide these public targets:

- `lint`
- `test`
- `check`

`check` should simply run `lint` and `test` in sequence.

### Tool checks

Each target should validate its required tools before running:

- `make lint` should check for `stylua` and `luacheck`
- `make test` should check for `nvim`
- `make test` should also require `PLENARY_DIR`, and fail with a clear message if it is unset or points to a missing directory

The failure messages should be explicit and helpful, for example:

- which tool is missing
- what environment variable is required
- what command the developer should run after installing dependencies

The goal is not to auto-install tools. The goal is to make missing prerequisites obvious.

### Command behavior

`make lint` should wrap the current CI behavior:

- `stylua --check lua/ plugin/ tests/`
- `luacheck lua/ plugin/`

`make test` should wrap the current headless test command:

- `nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"`

using the provided `PLENARY_DIR` environment variable.

### CI alignment

The GitHub Actions workflows should remain structurally similar:

- lint workflow stays a lint workflow
- test workflow keeps the stable/nightly matrix

But their command bodies should switch to the make targets:

- lint job runs `make lint`
- test job runs `make test`

This preserves the current CI shape while making the `Makefile` the single source of truth for the commands.

### Documentation

The README should gain a short development section documenting:

- `make lint`
- `make test`
- `make check`
- the requirement to have local tools installed
- the requirement to set `PLENARY_DIR` for tests

This section should stay short and practical.

## Scope

In scope:

- adding a `Makefile`
- adding helpful prerequisite checks
- updating CI to use make targets
- documenting the local development commands in `README.md`

Out of scope:

- automatic dependency installation
- containerized local checks
- renaming or restructuring the existing CI job layout beyond swapping in make targets
- adding build/release packaging behavior

## Testing

This change should be verified by checking:

1. `make lint` runs the same lint commands as CI
2. `make test` runs the same test command as CI when `PLENARY_DIR` is set
3. `make check` runs both
4. missing-tool failures produce helpful messages
5. CI workflows invoke the make targets successfully
