
<section align="center">
  <a href="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg">
  </a>
  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using JUnit.</p>
</section>

## :construction_worker: There is still Work In Progress
 :full_moon: :full_moon: :full_moon: :full_moon: :full_moon: :full_moon: :full_moon: :full_moon: :full_moon: :last_quarter_moon:

## :wrench: Installation

It requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
> [!WARNING]
>Make sure you have the java parser installed. Use `:TSInstall java`

[vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'rcasia/neotest-java'
```

* Run `:NeotestJava setup`
> [!NOTE]
> It will download the JUnit standalone jar from https://mvnrepository.com/artifact/org.junit.platform/junit-platform-console-standalone and place it in the default directory

## :gear: Configuration
```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")({
        ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
        junit_jar = "path/to/junit-standalone.jar",
        -- default: .local/share/nvim/neotest-java/junit-platform-console-standalone-[version].jar
    })
  }
})
```
## :octocat: Contributing
Feel free to contribute to this project by creating issues for bug reports, feature requests, or suggestions.

You can also submit pull requests for any enhancements, bug fixes, or new features.

Your contributions are greatly appreciated. See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md)
