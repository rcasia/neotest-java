
<section align="center">
  <a href="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg">
  </a>
  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using Maven.</p>
</section>


## :white_check_mark: Features

* Support for both [Maven](https://maven.apache.org/) and [Gradle](https://gradle.org/) projects
* Support for [@ParameterizedTest](https://junit.org/junit5/docs/5.0.2/api/org/junit/jupiter/params/ParameterizedTest.html) annotation
* It works with multi-module projects too!


## 🔧 Installation

It requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

>Make sure you have the java parser installed. Use `:TSInstall java`

Using vim-plug:
```vim
Plug 'rcasia/neotest-java'
```


## ⚙ Configuration
```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")
  }
})
```
