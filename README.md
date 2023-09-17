[![Makefile CI](https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg)](https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml)
# neotest-java

[Neotest](https://github.com/rcarriga/neotest) adapter for Java, using Maven.

## :white_check_mark: Features

Gradle support incoming:grey_exclamation:

* Supports Maven projects
* Supports integration tests
* Supports @ParameterizedTest annotation

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
