.PHONY: clean test test-fail-fast test-e2e

all: hooks test

hooks:
	pre-commit install

test: install
	bash scripts/test

test-fail-fast: install
	bash scripts/test --fail-fast

test-e2e: install
	@tests/e2e/run-all.sh


install: deps/nvim-treesitter deps/nvim-treesitter/parser/java.so deps/neotest deps/nvim-nio deps/plenary.nvim

# plenary.nvim is NOT a dependency of neotest-java (see #317 — our code now
# uses vim.system/vim.uv directly). It IS a transitive dependency of
# nvim-neotest/neotest itself (neotest.lib.file/positions/subprocess require
# plenary.path), so the e2e harness — which builds a real user-like
# environment by hand instead of using a plugin manager — must provide it,
# just as lazy.nvim/packer would in a real setup.
deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	mkdir -p deps
	git clone --branch master --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/neotest:
	mkdir -p deps
	git clone https://github.com/nvim-neotest/neotest $@
	git -C $@ checkout 7bef09d1170f8fb33c41607ca54f963cbdbf708d

deps/nvim-nio:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/nvim-nio $@

deps/nvim-treesitter/parser/java.so: deps/nvim-treesitter
	@if [ ! -d deps/tree-sitter-java ]; then \
		git clone https://github.com/tree-sitter/tree-sitter-java deps/tree-sitter-java; \
	fi
	cd deps/tree-sitter-java && cc -o parser.so -I./src src/parser.c -Os -std=c11 -shared
	mkdir -p $$(dirname $@)
	cp deps/tree-sitter-java/parser.so $@


clean:
	rm -rf deps/nvim-treesitter deps/neotest deps/tree-sitter-java

validate:
	stylua --check .

format:
	stylua .
