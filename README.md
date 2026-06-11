# neotest-java

[Neotest](https://github.com/rcarriga/neotest) adapter for Java,
using [JUnit](https://github.com/junit-team/junit5).

[![CI](https://github.com/rcasia/neotest-java/actions/workflows/ci-pipeline.yml/badge.svg)](https://github.com/rcasia/neotest-java/actions/workflows/ci-pipeline.yml)
[![LuaRocks](https://img.shields.io/luarocks/v/rcasia/neotest-java)](https://luarocks.org/modules/rcasia/neotest-java)
[![Stars](https://img.shields.io/github/stars/rcasia/neotest-java)](https://github.com/rcasia/neotest-java)

![image](https://github.com/user-attachments/assets/d1d77980-faab-4110-9b7c-ae6911a3d42c)

## ⭐ Features

- ✅ Maven & Gradle support (Groovy & Kotlin DSL)
- ✅ Multi-module projects with automatic detection
- ✅ JUnit 5 (Jupiter): `@Test`, `@ParameterizedTest`,
  `@TestFactory`, nested tests
- ✅ JUnit Platform 1.10.x & 6.x
- ✅ Spring Framework: auto-loads `application.yml`,
  `application-test.yml`, `.properties`
- ✅ Debugging with nvim-dap (breakpoints, JDWP, DAP REPL)
- ✅ Incremental compilation via nvim-jdtls
- ✅ Automatic classpath management from LSP
- ✅ JUnit JAR management with version detection
- ✅ Health check via `:checkhealth neotest-java`

> Check [ROADMAP.md](./ROADMAP.md) to see what's coming!

## 📦 Installation

### Prerequisites

- **Neovim 0.10.4+**
- **nvim-treesitter** with Java parser: `:TSInstall java`
- **A JDTLS-based Java LSP** — either
  [nvim-jdtls](https://github.com/mfussenegger/nvim-jdtls)
  or
  [nvim-java](https://github.com/nvim-java/nvim-java)
  (both are compatible)
- **nvim-dap** - For debugging support (optional)

### Setup with [lazy.nvim](https://github.com/folke/lazy.nvim)

#### Using nvim-jdtls

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

#### Using nvim-java

[nvim-java](https://github.com/nvim-java/nvim-java) is
fully compatible — neotest-java communicates with the LSP
through the standard `vim.lsp.Client` API and does not
depend directly on nvim-jdtls.

```lua
return {
  {
    "rcasia/neotest-java",
    ft = "java",
    dependencies = {
      "mfussenegger/nvim-dap", -- for debugging (optional)
    },
  },
  -- nvim-java handles JDTLS setup separately
  { "nvim-java/nvim-java" },
  {
    "nvim-neotest/neotest",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "nvim-lua/plenary.nvim",
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

This will automatically download and verify the JUnit
Platform Console Standalone JAR from
[Maven Central](https://mvnrepository.com/artifact/org.junit.platform/junit-platform-console-standalone)
with SHA-256 checksum verification.

> The plugin will detect if you have an older JUnit version
> installed and prompt you to upgrade.

## ⚙️ Configuration

All configuration options are optional.
Pass them to `require("neotest-java")({})`:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")({
      junit_jar = nil, -- default: auto-detected
      jvm_args = { "-Xmx512m" }, -- custom JVM arguments
      incremental_build = true, -- recompile changed files
      disable_update_notifications = false,
      test_classname_patterns = {
        "^.*Tests?$", "^.*IT$", "^.*Spec$"
      },
    }),
  },
})
```

### Options

- **`junit_jar`** (`string?`) — default:
  `stdpath("data")/neotest-java/junit-*.jar`
  Path to JUnit Platform Console Standalone JAR
- **`jvm_args`** (`string[]`) — default: `{}`
  Additional JVM arguments for test execution
- **`incremental_build`** (`boolean`) — default: `true`
  Enable incremental compilation (recompile changed files)
- **`disable_update_notifications`** (`boolean`) —
  default: `false`
  Disable JUnit update notifications
- **`test_classname_patterns`** (`string[]`) —
  default: `{"^.*Tests?$", "^.*IT$", "^.*Spec$"}`
  Regex patterns for test class names

## 🔧 Advanced: Dependency Injection API

neotest-java exposes a public dependency injection API
that allows you to override core adapter components.
This is useful for:

- Using custom LSP clients (e.g., coc.nvim)
- Custom classpath resolution (e.g., Bazel)
- Custom build tools (e.g., Ant, Bazel)
- Custom compilation strategies
- Testing downstream plugins/configs

### Usage

Pass a second argument to the adapter constructor
with your overrides:

```lua
require("neotest").setup({
  adapters = {
    require("neotest-java")({
      -- configuration options
    }, {
      -- dependency overrides (all optional)
      client_provider = my_custom_client_provider,
      classpath_provider = my_custom_classpath_provider,
      binaries = my_custom_binaries,
      lsp_compiler = my_custom_compiler,
      build_tool_getter = my_custom_build_tool_getter,
      method_id_resolver = my_custom_method_id_resolver,
    }),
  },
})
```

### Example: Using coc.nvim as LSP client

```lua
local custom_client_provider = function(cwd)
  -- Get coc.nvim's Java client
  local clients = vim.lsp.get_clients({ name = "coc" })
  for _, client in ipairs(clients) do
    local fts = client.config.filetypes or {}
    if vim.tbl_contains(fts, "java") then
      return client
    end
  end
  error("No coc.nvim Java client found")
end

require("neotest").setup({
  adapters = {
    require("neotest-java")({}, {
      client_provider = custom_client_provider,
    }),
  },
})
```

### Example: Custom classpath resolution

```lua
local custom_classpath_provider = {
  get_classpath = function(base_dir, additional_entries)
    -- Your custom classpath resolution logic
    local result = vim.system({
      "bazel", "query", "classpath",
      tostring(base_dir)
    }):wait()
    return result.stdout
  end,
}

require("neotest").setup({
  adapters = {
    require("neotest-java")({}, {
      classpath_provider = custom_classpath_provider,
    }),
  },
})
```

### Type Reference

See the `neotest-java.Dependencies` type annotation in
[`lua/neotest-java/init.lua`](lua/neotest-java/init.lua)
for the full API reference with type signatures.

## ⚠️ Troubleshooting

### Multi-module: "URI does not belong to any Java project"

Tests in one module pass but tests in another fail with:

```text
Error -32001: Given URI does not belong to any
Java project.
```

**Cause:** eclipse.jdt.ls (jdtls) is started once per
module instead of once per workspace. When neotest-java
runs tests for module B, it talks to module A's jdtls
instance, which rejects URIs it doesn't own.

This happens when `pom.xml` or `build.gradle` is used as
a root marker in the jdtls configuration. Because every
module directory contains its own build file, jdtls
resolves `root_dir` to the nearest module root rather
than the repository root.

**Solution:** Remove `pom.xml` and `build.gradle` from
the `root_dir` markers and keep only the repo-level
markers (`.git`, `mvnw`, `gradlew`).

With **nvim-jdtls** (`ftplugin/java.lua` style):

```lua
-- Before (broken for multimodule):
root_dir = require("jdtls.setup").find_root({
  ".git", "mvnw", "gradlew", "pom.xml"
})

-- After (correct):
root_dir = require("jdtls.setup").find_root({
  ".git", "mvnw", "gradlew"
})
```

With the newer `vim.lsp.config` / `vim.fs.root` API
(Neovim 0.11+):

```lua
-- Before (broken for multimodule):
root_dir = vim.fs.root(0, {
  ".git", "mvnw", "gradlew", "pom.xml"
})

-- After (correct):
root_dir = vim.fs.root(0, {
  ".git", "mvnw", "gradlew"
})
```

With this change a single jdtls instance starts at the
repository root and handles all modules. eclipse.jdt.ls
natively understands Maven and Gradle multimodule
projects, so no further configuration is needed.

> The first time you open a Java file after this change,
> jdtls will reindex the whole workspace from a new
> `-data` directory. This can take a couple of minutes
> for large projects.

### Spring Tests: "parameter name information not available"

If you're running Spring tests that use reflection
(e.g., `@MockBean`, `@WebMvcTest`) and encounter
errors like:

```text
java.lang.IllegalArgumentException: Name for argument
of type [int] not specified, and parameter name
information not available via reflection.
Ensure that the compiler uses the '-parameters' flag.
```

**Solution:** Configure the JDTLS compiler to preserve
parameter names in bytecode by adding the following to
your project's
`.settings/org.eclipse.jdt.core.prefs` file:

```properties
org.eclipse.jdt.core.compiler.codegen.methodParameters=generate
```

If the `.settings` directory doesn't exist, create it
in your project root:

```bash
mkdir -p .settings
echo "org.eclipse.jdt.core.compiler.codegen.methodParameters=generate" \
  > .settings/org.eclipse.jdt.core.prefs
```

After adding this setting, restart your LSP server
(`:LspRestart`) and run your tests again.

## 🤝 Contributing

Contributions are welcome! Please feel free to:

- 🐛 Report bugs and issues
- 💡 Suggest new features or improvements
- 🔧 Submit pull requests

See [CONTRIBUTING.md](https://github.com/rcasia/neotest-java/blob/main/CONTRIBUTING.md)
for guidelines.

## ✨ Acknowledgements

Thanks to all contributors who have helped improve
this project!

[![Contributors](https://contrib.rocks/image?repo=rcasia/neotest-java)](https://github.com/rcasia/neotest-java/graphs/contributors)
