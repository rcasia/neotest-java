
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
      keys[#keys + 1] = {"<leader>tD", function() require("neotest").run.run({ strategy = "dap" }) end, mode = "n" }
      -- debug nearest test
      keys[#keys + 1] = {"<leader>td", function() require("neotest").run.run({ vim.fn.expand("%"), strategy = "dap" }) end, mode = "n" }
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
    opts = {
      adapters = {
          ["neotest-java"] = {
            -- config here
          },
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
        java_runtimes = {
            -- there are no runtimes defined by default, if you wish to have neotest-java resolve them based on your environment define them here, one could also define environment variables with the same key/names i.e. `JAVA_HOME_8` or `JAVA_HOME_11` or `JAVA_HOME_17` etc.
            ["JAVA_HOME_8"] = "/absolute/path/to/jdk8/home/directory",
            ["JAVA_HOME_11"] = "/absolute/path/to/jdk11/home/directory",
            ["JAVA_HOME_17"] = "/absolute/path/to/jdk17/home/directory",
        },
        junit_jar = nil,
        -- default: .local/share/nvim/neotest-java/junit-platform-console-standalone-[version].jar
    })
  }
})
```

Neotest java would try it's best to determine the current project's runtime based on the currently running lsp servers. Note that, neotest-java supports both native neovim lsp and coc.nvim, it would try to fallback to your project configuration, supports both maven (reading from pom.xml) & gradle (reading from build.gradle or gradle.properties). In case the runtime is found but the location of it is not defined, neotest-java would prompt the user to input the absolute directory for the specific runtime version (only once).

## :octocat: Contributing
Feel free to contribute to this project by creating issues for bug reports, feature requests, or suggestions.

You can also submit pull requests for any enhancements, bug fixes, or new features.

Your contributions are greatly appreciated. See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md)

## Limitations
* Does not support multimodule projects yet https://github.com/rcasia/neotest-java/issues/100

