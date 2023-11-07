
<section align="center">
  <a href="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg">
  </a>
  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using JUnit.</p>
</section>


## :white_check_mark: Features

* Support for both [Maven](https://maven.apache.org/) and [Gradle](https://gradle.org/) projects
* Support for [@ParameterizedTest](https://junit.org/junit5/docs/5.0.2/api/org/junit/jupiter/params/ParameterizedTest.html) annotation
* It works with multi-module projects too!


## :wrench: Installation

It requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)

>Make sure you have the java parser installed. Use `:TSInstall java`

Using vim-plug:
```vim
Plug 'rcasia/neotest-java', { 'tag': 'latest' }
```


## :gear: Configuration
```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")({
        ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
    })
  }
})
```
## :octocat: Contributing
Feel free to contribute to this project by creating issues for bug reports, feature requests, or suggestions.

You can also submit pull requests for any enhancements, bug fixes, or new features.

Your contributions are greatly appreciated.
