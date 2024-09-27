
<section align="center">

  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using <a href="https://github.com/junit-team/junit5">JUnit</a>.</p>

  <a href="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/makefile.yml/badge.svg">
  </a>
  <a href="https://luarocks.org/modules/rcasia/neotest-java">
    <img alt="LuaRocks" src="https://img.shields.io/luarocks/v/rcasia/neotest-java">
  </a>
  
</section>
![image](https://github.com/user-attachments/assets/d1d77980-faab-4110-9b7c-ae6911a3d42c)

## ⭐ Features
- ✅ Maven and Gradle projects
- ✅ Multimodule projects
- ✅ Debugging tests with [`nvim-dap`](https://github.com/mfussenegger/nvim-dap)

> Check [ROADMAP.md](./ROADMAP.md) to see what's coming!

## :wrench: Installation

##### Install in 3 steps :athletic_shoe:

1. Make sure you have installed nvim-treesitter parsers. Use `:TSInstall java groovy`
2. Add neotest-java to your config:

<details>
  <summary><a href="https://github.com/LazyVim/LazyVim">LazyVim</a> distro installation</summary>

  ```lua
  return {
    {
      "rcasia/neotest-java",
      ft = "java",
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

</details>
<details open>
  <summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a> plugin manager</summary>

  ```lua
  {
    "nvim-neotest/neotest",
    ft = "java"
    dependencies = {
      "rcasia/neotest-java",
    },
    opts = {
      adapters = {
        ["neotest-java"] = {},
      },
    },
  },
  ```

</details>

3. Run `:NeotestJava setup`

> [!NOTE]
> It will download the JUnit standalone jar from
> https://mvnrepository.com/artifact/org.junit.platform/junit-platform-console-standalone


## :gear: Configuration

```lua
{
  ignore_wrapper = false, -- whether to ignore maven/gradle wrapper
  junit_jar = nil, -- default: /nvim/neotest-java/junit-platform-console-standalone-[version].jar
  incremental_build = true
}
```

## :octocat: Contributing

Feel free to contribute to this project by creating issues for bug
reports, feature requests, or suggestions.

You can also submit pull requests for any enhancements, bug fixes, or new features.

Your contributions are greatly appreciated. See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md)
