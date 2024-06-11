
<section align="center">
  <a href="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg">
  </a>
  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using <a href="https://github.com/junit-team/junit5">JUnit</a>.</p>
</section>

## :wrench: Installation

It requires [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
> [!WARNING]
>Make sure you have the java parser installed. Use `:TSInstall java`

[vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'rcasia/neotest-java'
```

[LazyVim](https://github.com/LazyVim/LazyVim) distro:
```lua
return {
  {
    "rcasia/neotest-java",
    init = function()
      -- override the default keymaps.
      -- needed until neotest-java is integrated in LazyVim
      local keys = require("lazyvim.plugins.lsp.keymaps").get()
      -- run test file
      keys[#keys + 1] = {"<leader>tt", function() require("neotest").run.run(vim.fn.expand("%")) end, mode = "n" }
      -- run nearest test
      keys[#keys + 1] = {"<leader>tr", function() require("neotest").run.run() end, mode = "n" }
      -- debug test file
      keys[#keys + 1] = {"<leader>tD", function() require("jdtls.dap").test_class() end, mode = "n" }
      -- debug nearest test
      keys[#keys + 1] = {"<leader>td", function() require("jdtls.dap").test_nearest_method() end, mode = "n" }
    end,
  },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
      "antoinemadec/FixCursorHold.nvim",
      "nvim-treesitter/nvim-treesitter"
    },
    adapters = {
        ["neotest-java"] = {
          -- config here
        },
    },
  },
}
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
