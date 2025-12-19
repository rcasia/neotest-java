set runtimepath+=.
set runtimepath+=./deps/plenary.nvim
set runtimepath+=./deps/neotest
set runtimepath+=./deps/nvim-treesitter
set runtimepath+=./deps/nvim-nio
runtime! plugin/plenary.vim

lua << EOF
  require('nvim-treesitter.install').install('java'):wait(300000)
EOF
