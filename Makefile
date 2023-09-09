.PHONY: clean

all: test

test: install
	./scripts/test

test-fail-fast: install
	./scripts/test --fail-fast

install: deps/plenary.nvim deps/nvim-treesitter deps/nvim-treesitter/parser/java.so deps/neotest

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/neotest:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

deps/nvim-treesitter/parser/java.so: deps/nvim-treesitter
	nvim --headless -u tests/minimal_init.vim -c "TSInstallSync java | quit"

clean:
	rm -rf deps/plenary.nvim deps/nvim-treesitter deps/neotest

validate:
	stylua --check .

format:
	stylua .
