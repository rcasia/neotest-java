.PHONY: test clean

test: deps/plenary.nvim deps/nvim-treesitter deps/neotest
	./scripts/test

deps/plenary.nvim:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $@

deps/nvim-treesitter:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-treesitter/nvim-treesitter.git $@

deps/neotest:
	mkdir -p deps
	git clone --depth 1 https://github.com/nvim-neotest/neotest $@

clean:
	rm -rf deps/plenary.nvim deps/nvim-treesitter deps/neotest

