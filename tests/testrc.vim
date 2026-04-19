set runtimepath+=.
set runtimepath+=./deps/mini.nvim
set runtimepath+=./deps/neotest
set runtimepath+=./deps/nvim-treesitter
set runtimepath+=./deps/nvim-nio
lua require('mini.test').setup()
