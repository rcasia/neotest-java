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
	@-$(MAKE) _install_groovy_parser 2>/dev/null || echo "Note: Groovy parser not compiled (optional for Java-only development)"

_install_groovy_parser: deps/nvim-treesitter/parser/groovy.so

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

deps/nvim-treesitter/parser/groovy.so: deps/nvim-treesitter
	@if [ ! -d deps/tree-sitter-groovy ]; then \
		git clone https://github.com/tree-sitter/tree-sitter-groovy deps/tree-sitter-groovy; \
	fi
	cd deps/tree-sitter-groovy && cc -o parser.so -I./src src/parser.c src/scanner.c -Os -std=c11 -shared
	mkdir -p $$(dirname $@)
	cp deps/tree-sitter-groovy/parser.so $@


clean:
	rm -rf deps/nvim-treesitter deps/neotest deps/tree-sitter-java deps/tree-sitter-groovy

validate:
	stylua --check .

format:
	stylua .
