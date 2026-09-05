set runtimepath+=.
set runtimepath+=./deps/neotest
set runtimepath+=./deps/nvim-treesitter
set runtimepath+=./deps/nvim-nio
" Transitive dependency of neotest itself (see Makefile note); not required
" by neotest-java directly.
set runtimepath+=./deps/plenary.nvim
