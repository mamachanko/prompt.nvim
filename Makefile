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
	@command -v sqlite3 >/dev/null 2>&1 || { echo "Error: sqlite3 is required for 'make test'. Install sqlite3, then rerun 'make test'."; exit 1; }
	@test -n "$(PLENARY_DIR)" || { echo "Error: PLENARY_DIR must point to your plenary.nvim checkout for 'make test'. Example: export PLENARY_DIR=~/.local/share/nvim/lazy/plenary.nvim"; exit 1; }
	@test -d "$(PLENARY_DIR)" || { echo "Error: PLENARY_DIR points to a missing directory: $(PLENARY_DIR)"; exit 1; }
