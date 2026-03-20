.PHONY: clean test test-fail-fast test-e2e test-single

all: hooks test

hooks:
	pre-commit install

# Test targets using mini.test
test: install
	nvim --headless --noplugin -u tests/mini_init.vim -c "lua MiniTest.run()" +q

test-fail-fast: install
	nvim --headless --noplugin -u tests/mini_init.vim -c "lua MiniTest.run()" +q

test-single: install
	@if [ -z "$(FILE)" ]; then echo "Usage: make test-single FILE=tests/unit/foo_spec.lua"; exit 1; fi
	nvim --headless --noplugin -u tests/mini_init.vim -c "lua MiniTest.run_file('$(FILE)')" +q

test-e2e: install
	@tests/e2e/run-all.sh

# Install dependencies
install: deps/mini.nvim deps/plenary.nvim deps/nvim-treesitter deps/nvim-treesitter/parser/java.so deps/neotest deps/nvim-nio

deps/mini.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/echasnovski/mini.nvim.git $@

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	mkdir -p deps
	git clone --branch master --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/neotest:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

deps/nvim-nio:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/nvim-nio $@

deps/nvim-treesitter/parser/java.so: deps/nvim-treesitter
	nvim --headless -u tests/mini_init.vim -c "TSInstallSync java" +q

# Cleanup
clean:
	rm -rf deps/mini.nvim deps/plenary.nvim deps/nvim-treesitter deps/neotest deps/nvim-nio

# Code quality
validate:
	stylua --check .

format:
	stylua .
