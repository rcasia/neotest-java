.PHONY: clean

all: hooks test

hooks:
	pre-commit install

test: install
	bash scripts/test

test-fail-fast: install
	bash scripts/test --fail-fast


install: deps/plenary.nvim deps/nvim-treesitter deps/nvim-treesitter/parser/java.so deps/neotest deps/nvim-nio

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
	nvim --headless -u tests/testrc.vim -c "TSInstallSync java" +q


clean:
	rm -rf deps/plenary.nvim deps/nvim-treesitter deps/neotest

validate:
	stylua --check .

format:
	stylua .
