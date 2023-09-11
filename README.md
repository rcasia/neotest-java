[![Makefile CI](https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg)](https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml)
# neotest-java

[Neotest](https://github.com/rcarriga/neotest) adapter for Java, using JUnit.

## 🔧 Installation

It requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

Using vim-plug:
```vim
Plug 'rcasia/neotest-java', { 'do': ':TSInstall java' }
```

## ⚙ Configuration
```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")
  }
})
```
