
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

- ✅ **Maven & Gradle** - Full support for both build systems (Groovy & Kotlin DSL)
- ✅ **Multi-module projects** - Automatic detection and per-module test execution
- ✅ **JUnit 5 (Jupiter)** - Support for `@Test`, `@ParameterizedTest`, `@TestFactory`, nested tests
- ✅ **JUnit Platform 1.10.x & 6.x** - Compatible with both legacy and latest versions
- ✅ **Spring Framework** - Auto-loads `application.yml`, `application-test.yml`, and `.properties` files
- ✅ **Debugging with nvim-dap** - Full integration with breakpoints, JDWP, and DAP REPL output
- ✅ **Incremental compilation** - Smart compilation of only changed files via nvim-jdtls
- ✅ **Automatic classpath management** - Retrieves runtime and test classpaths from LSP
- ✅ **JUnit JAR management** - Automatic installation, version detection, and upgrade prompts
- ✅ **Health check** - Comprehensive diagnostics with `:checkhealth neotest-java`

> Check [ROADMAP.md](./ROADMAP.md) to see what's coming!

## 📦 Installation

### Prerequisites

- **Neovim 0.10.4+**
- **nvim-treesitter** with Java parser: `:TSInstall java`
- **nvim-jdtls** - Language server for Java
- **nvim-dap** - For debugging support (optional)

### Setup with [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
return {
  {
    "rcasia/neotest-java",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-jdtls",
      "mfussenegger/nvim-dap", -- for debugging (optional)
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
            -- Optional configuration here
          }),
        },
      })
    end,
  },
}
```

### JUnit JAR Installation

After setting up the plugin, run:

```vim
:NeotestJava setup
```

This will automatically download and verify the JUnit Platform Console Standalone JAR from [Maven Central](https://mvnrepository.com/artifact/org.junit.platform/junit-platform-console-standalone) with SHA-256 checksum verification.

> [!TIP]
> The plugin will detect if you have an older JUnit version installed and prompt you to upgrade to the latest version.

## ⚙️ Configuration

All configuration options are optional. Pass them to `require("neotest-java")({})`:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")({
      junit_jar = nil, -- default: auto-detected
      jvm_args = { "-Xmx512m" }, -- custom JVM arguments
      incremental_build = true, -- recompile only changed files
      disable_update_notifications = false, -- show JUnit update prompts
      test_classname_patterns = { "^.*Tests?$", "^.*IT$", "^.*Spec$" },
    }),
  },
})
```

### Options

| Option                        | Type       | Default                                                    | Description                                                                 |
|-------------------------------|------------|------------------------------------------------------------|-----------------------------------------------------------------------------|
| `junit_jar`                   | `string?`  | `stdpath("data")/neotest-java/junit-*.jar`                | Path to JUnit Platform Console Standalone JAR                               |
| `jvm_args`                    | `string[]` | `{}`                                                       | Additional JVM arguments for test execution                                 |
| `incremental_build`           | `boolean`  | `true`                                                     | Enable incremental compilation (recompile only changed files)               |
| `disable_update_notifications`| `boolean`  | `false`                                                    | Disable notifications about available JUnit updates                         |
| `test_classname_patterns`     | `string[]` | `{"^.*Tests?$", "^.*IT$", "^.*Spec$"}`                    | Regex patterns for test class names (classes must match at least one pattern)|

## 🤝 Contributing

Contributions are welcome! Please feel free to:

- 🐛 Report bugs and issues
- 💡 Suggest new features or improvements
- 🔧 Submit pull requests

See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md) for guidelines.

## ✨ Acknowledgements

Thanks to all contributors who have helped improve this project!

[![Contributors](https://contrib.rocks/image?repo=rcasia/neotest-java)](https://github.com/rcasia/neotest-java/graphs/contributors)
