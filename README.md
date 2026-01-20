
<section align="center">

  <h1>neotest-java</h1>
  <p> <a href="https://github.com/rcarriga/neotest">Neotest</a> adapter for Java, using <a href="https://github.com/junit-team/junit5">JUnit</a>.</p>

  <a href="https://github.com/rcasia/neotest-java/actions/workflows/ci-pipeline.yml">
    <img src="https://github.com/rcasia/neotest-java/actions/workflows/ci-pipeline.yml/badge.svg">
  </a>
  <a href="https://luarocks.org/modules/rcasia/neotest-java">
    <img alt="LuaRocks" src="https://img.shields.io/luarocks/v/rcasia/neotest-java">
  </a>

  <a href="https://github.com/rcasia/neotest-java">
    <img alt="GitHub Repo stars" src="https://img.shields.io/github/stars/rcasia/neotest-java">
  </a>
</section>

![image](https://github.com/user-attachments/assets/d1d77980-faab-4110-9b7c-ae6911a3d42c)

## ⭐ Features

- ✅ Maven and Gradle projects
- ✅ Multimodule projects
- ✅ Integrated with [`nvim-dap`](https://github.com/mfussenegger/nvim-dap) for test debugging.

> Check [ROADMAP.md](./ROADMAP.md) to see what's coming!

## :wrench: Installation

##### Install in 3 steps :athletic_shoe:

1. Make sure you have installed nvim-treesitter parsers. Use `:TSInstall java`
2. Add neotest-java to your config:

<details>
  <summary><a href="https://github.com/folke/lazy.nvim">lazy.nvim</a> plugin manager example</summary>

  ```lua
  return {
    {
      "rcasia/neotest-java",
      ft = "java",
      dependencies = {
        "mfussenegger/nvim-jdtls",
        "mfussenegger/nvim-dap", -- for the debugger
        "rcarriga/nvim-dap-ui", -- recommended
        "theHamsta/nvim-dap-virtual-text", -- recommended
      },
    },
   {
    "nvim-neotest/neotest",
      dependencies = {
        "nvim-neotest/nvim-nio",
        "nvim-lua/plenary.nvim",
        "antoinemadec/FixCursorHold.nvim",
        "nvim-treesitter/nvim-treesitter",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-java")({
            -- config here
          }),
        },
      })
    end,
  }
 }
  ```

</details>

3. Run `:NeotestJava setup`

> [!NOTE]
> It will download the JUnit standalone jar from
> <https://mvnrepository.com/artifact/org.junit.platform/junit-platform-console-standalone>

## :gear: Configuration

| Option              | Type        | Default                                                                                         | Description                                             |
|---------------------|-------------|-------------------------------------------------------------------------------------------------|---------------------------------------------------------|
| `junit_jar`         | `string?`   | `stdpath("data") .. /nvim/neotest-java/junit-platform-console-standalone-[version].jar`        | Path to the JUnit Platform Console standalone JAR.      |
| `jvm_args`          | `string[]`  | `{}`                                                                                            | Additional JVM arguments passed when running tests.     |
| `incremental_build` | `boolean`   | `true`                                                                                          | Enable incremental compilation before running tests.   |
| `disable_update_notifications` | `boolean`   | `false`                                                                                          | Disable notifications about available JUnit jar updates. |
| `test_classname_patterns` | `string[]`  | `{"^.*Tests?$", "^.*IT$", "^.*Spec$"}` | Regular expressions used to include only classes whose names match these patterns. Classes not matching any pattern will be ignored. |

## :octocat: Contributing

Feel free to contribute to this project by creating issues for bug
reports, feature requests, or suggestions.

You can also submit pull requests for any enhancements, bug fixes, or new features.

Your contributions are greatly appreciated. See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md)

## :sparkles: Acknowledgements

[![Contributors](https://contrib.rocks/image?repo=rcasia/neotest-java)](https://github.com/rcasia/neotest-java/graphs/contributors)
