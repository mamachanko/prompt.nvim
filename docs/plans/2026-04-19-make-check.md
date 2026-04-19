# Make Check Workflow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a small Makefile with `lint`, `test`, and `check` targets, then switch CI and README docs to use those canonical commands.

**Architecture:** The `Makefile` becomes the single command surface for local verification and CI execution. It stays intentionally small: public targets delegate to the existing lint and headless test commands, while lightweight prerequisite checks fail early with actionable messages when `stylua`, `luacheck`, `nvim`, or `PLENARY_DIR` are missing.

**Tech Stack:** GNU make, shell commands, GitHub Actions YAML, Neovim headless tests, stylua, luacheck

---

## File Structure

- `Makefile` — canonical developer and CI entrypoint; defines `lint`, `test`, `check`, and internal prerequisite-check targets
- `.github/workflows/lint.yml` — switches lint jobs from inline tool-specific invocations to `make lint`
- `.github/workflows/test.yml` — keeps the stable/nightly matrix, but switches the test step to `make test`
- `README.md` — adds a short Development section documenting `make lint`, `make test`, `make check`, and the `PLENARY_DIR` prerequisite

### Task 1: Add the canonical Makefile

**Files:**
- Create: `Makefile`

- [ ] **Step 1: Write the failing local command checks by verifying the target does not exist yet**

Run:
```bash
make check
```

Expected: FAIL with `No rule to make target 'check'` because the repository does not yet have a `Makefile`.

- [ ] **Step 2: Create `Makefile` with explicit prerequisite checks and public targets**

```make
.PHONY: check lint test check-lint-tools check-test-tools

check: lint test

lint: check-lint-tools
	stylua --check lua/ plugin/ tests/
	luacheck lua/ plugin/

test: check-test-tools
	nvim --headless -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/ {minimal_init = 'tests/minimal_init.lua'}"

check-lint-tools:
	@command -v stylua >/dev/null 2>&1 || { echo "Error: stylua is required for 'make lint'. Install stylua, then rerun 'make lint'."; exit 1; }
	@command -v luacheck >/dev/null 2>&1 || { echo "Error: luacheck is required for 'make lint'. Install luacheck, then rerun 'make lint'."; exit 1; }

check-test-tools:
	@command -v nvim >/dev/null 2>&1 || { echo "Error: nvim is required for 'make test'. Install Neovim, then rerun 'make test'."; exit 1; }
	@test -n "$(PLENARY_DIR)" || { echo "Error: PLENARY_DIR must point to your plenary.nvim checkout for 'make test'. Example: export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim"; exit 1; }
	@test -d "$(PLENARY_DIR)" || { echo "Error: PLENARY_DIR points to a missing directory: $(PLENARY_DIR)"; exit 1; }
```

Keep the file intentionally small. Do not add auto-install logic, default package-manager assumptions, or extra targets not requested by the spec.

- [ ] **Step 3: Verify the new failure messages for missing dependencies**

Run:
```bash
env -u PLENARY_DIR make test
```

Expected: FAIL with the explicit `PLENARY_DIR must point to your plenary.nvim checkout` message.

Then run:
```bash
PATH="/nonexistent" make lint
```

Expected: FAIL with the `stylua is required` message, because the lint prerequisite check can no longer find the executable on `PATH`.

- [ ] **Step 4: Verify the happy path for the new targets**

Run:
```bash
export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim
make test
make lint
make check
```

Expected:
- `make test` runs the existing headless test suite and passes
- `make lint` runs `stylua --check` and `luacheck`
- `make check` runs `lint` followed by `test`

If `stylua` and `luacheck` are not installed in the local environment, stop after confirming the helpful failure messages and note that final lint verification must be completed in an environment with those tools installed.

- [ ] **Step 5: Commit the Makefile checkpoint**

```bash
git add Makefile
git commit -m "build: add canonical check targets"
```

### Task 2: Switch CI workflows to the canonical targets

**Files:**
- Modify: `.github/workflows/lint.yml`
- Modify: `.github/workflows/test.yml`

- [ ] **Step 1: Write the failing verification by proving CI still duplicates raw commands**

Run:
```bash
rg -n 'stylua --check|luacheck lua/ plugin/|nvim --headless -u tests/minimal_init.lua' .github/workflows
```

Expected: PASS with matches in both workflow files, proving CI still embeds the commands directly instead of calling make targets.

- [ ] **Step 2: Update `.github/workflows/lint.yml` to install tools and run `make lint`**

Replace the current lint workflow body with:

```yaml
name: Lint
on: [push, pull_request]
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install stylua
        uses: taiki-e/install-action@v2
        with:
          tool: stylua
      - name: Install luacheck
        run: |
          sudo apt-get update
          sudo apt-get install -y luarocks
          sudo luarocks install luacheck
      - name: Run lint
        run: make lint
```

Keep the workflow simple: install the tools into the runner environment, then delegate the actual lint command to `make lint`.

- [ ] **Step 3: Update `.github/workflows/test.yml` to run `make test`**

Modify the current test step block to:

```yaml
      - name: Run tests
        env:
          PLENARY_DIR: ~/.local/share/nvim/lazy/plenary.nvim
        run: |
          make test
```

Leave the rest of the test workflow structure intact, including the stable/nightly matrix, Neovim setup, sqlite3 install, and plenary checkout.

- [ ] **Step 4: Verify the workflows now point at the canonical targets**

Run:
```bash
rg -n 'make lint|make test' .github/workflows
rg -n 'stylua --check|luacheck lua/ plugin/|nvim --headless -u tests/minimal_init.lua' .github/workflows
```

Expected:
- first command finds `make lint` in `lint.yml` and `make test` in `test.yml`
- second command returns no matches, proving the workflows no longer duplicate the underlying commands

- [ ] **Step 5: Commit the CI alignment checkpoint**

```bash
git add .github/workflows/lint.yml .github/workflows/test.yml
git commit -m "ci: run verification through make targets"
```

### Task 3: Document the development workflow

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Write the failing documentation check by proving there is no development section yet**

Run:
```bash
rg -n '^## Development$|make check|PLENARY_DIR' README.md
```

Expected: no matches.

- [ ] **Step 2: Add a short Development section to `README.md`**

Insert this section before `## License`:

```md
## Development

Use the canonical local verification targets:

```bash
make lint
export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim
make test
make check
```

Requirements:

- `make lint` expects `stylua` and `luacheck` to already be installed
- `make test` expects `nvim` to be installed
- `make test` and `make check` require `PLENARY_DIR` to point to your local `plenary.nvim` checkout
```

Do not expand this into a large contributor guide. Keep it short and practical.

- [ ] **Step 3: Verify the README now documents the intended workflow**

Run:
```bash
rg -n '^## Development$|make check|make lint|make test|PLENARY_DIR' README.md
```

Expected: matches for the new section and all three commands.

- [ ] **Step 4: Run the full verification pass**

Run:
```bash
export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim
make test
make lint
make check
```

Expected:
- `make test` passes
- `make lint` passes with clean `stylua` and `luacheck` output
- `make check` passes end-to-end

If `stylua` or `luacheck` are unavailable locally, install them first or run this verification in the same environment CI uses before claiming completion.

- [ ] **Step 5: Commit the documentation checkpoint**

```bash
git add README.md
git commit -m "docs: add local make check workflow"
```
