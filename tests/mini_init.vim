" Minimal init for mini.test test runner
" Sets up runtime paths for all dependencies

" Add project root to runtime path
let &rtp .= ',' . getcwd()

" Add dependencies to runtime path
set runtimepath+=./deps/mini.nvim
set runtimepath+=./deps/neotest
set runtimepath+=./deps/nvim-nio
set runtimepath+=./deps/nvim-treesitter
set runtimepath+=./deps/plenary.nvim

" Load plenary first (required by neotest)
runtime! plugin/plenary.vim

" Configure mini.test to find *_spec.lua files
lua << EOF
require('mini.test').setup({
  collect = {
    emulate_busted = true,
    find_files = function()
      return vim.fs.find(function(name) return name:match('_spec%.lua$') end, {
        path = 'tests',
        type = 'file',
        limit = math.huge
      })
    end
  }
})
EOF
