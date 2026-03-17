# Architecture

This document explains the architecture and design of neotest-java, a Neotest adapter that enables running and debugging Java tests using JUnit within Neovim.

## Table of Contents

- [Overview](#overview)
- [High-Level Architecture](#high-level-architecture)
- [Core Components](#core-components)
- [Test Execution Flow](#test-execution-flow)
- [Data Flow](#data-flow)
- [Integration Points](#integration-points)
- [Directory Structure](#directory-structure)
- [Design Decisions](#design-decisions)

## Overview

neotest-java is a Neotest adapter that bridges the gap between Neovim's testing interface (Neotest) and Java's testing framework (JUnit). It leverages nvim-jdtls for compilation and classpath management, and executes tests using the JUnit Platform Console Standalone.

### Key Responsibilities

1. **Test Discovery**: Parse Java files using Tree-sitter to identify test methods and classes
2. **Compilation**: Trigger incremental or full compilation via nvim-jdtls
3. **Test Execution**: Build and execute JUnit commands with proper classpath and configuration
4. **Result Processing**: Parse JUnit XML reports and convert them to Neotest results
5. **Debugging Support**: Integrate with nvim-dap for breakpoint debugging

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                          Neovim User                             │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                       Neotest Core                               │
│              (Test discovery & execution framework)              │
└────────────────────────┬────────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                     neotest-java Adapter                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │  Positions   │  │     Spec     │  │       Result         │  │
│  │  Discoverer  │→ │    Builder   │→ │      Builder         │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│         │                  │                      │              │
│         ▼                  ▼                      ▼              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Tree-sitter  │  │ JUnit Command│  │   XML Report         │  │
│  │    Parser    │  │   Builder    │  │    Parser            │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└────────────┬───────────────┬───────────────────┬────────────────┘
             │               │                   │
             ▼               ▼                   ▼
┌──────────────────┐ ┌─────────────────┐ ┌──────────────────────┐
│   nvim-jdtls     │ │ JUnit Platform  │ │   File System        │
│  (LSP Server)    │ │    Console      │ │  (XML Reports)       │
│                  │ │   Standalone    │ │                      │
│ • Compilation    │ │                 │ │ target/junit-reports/│
│ • Classpath      │ │ • Test Runner   │ │ build/junit-reports/ │
│ • Java Runtime   │ │ • XML Output    │ │                      │
└──────────────────┘ └─────────────────┘ └──────────────────────┘
```

## Core Components

### 1. Adapter Entry Point (`init.lua`)

The main adapter module that implements the Neotest adapter interface.

**Key Functions:**
- `filter_dir`: Filters directories to include in test discovery
- `is_test_file`: Determines if a file contains tests
- `root`: Finds the project root directory
- `discover_positions`: Discovers test positions in files
- `build_spec`: Builds the test execution specification
- `results`: Processes test results from XML reports

**Interfaces with:**
- Neotest core
- All other neotest-java components

### 2. Position Discoverer (`core/positions_discoverer.lua`)

Parses Java source files using Tree-sitter to identify test positions.

**Responsibilities:**
- Uses Tree-sitter queries to find test classes and methods
- Identifies JUnit annotations: `@Test`, `@ParameterizedTest`, `@TestFactory`, `@CartesianTest`
- Generates unique position IDs for each test
- Resolves package names and fully qualified names

**Output:**
```lua
neotest.Tree {
  type = "file",
  children = {
    {
      type = "namespace",  -- Test class
      id = "com.example.MyTest",
      children = {
        {
          type = "test",  -- Test method
          id = "com.example.MyTest::testMethod",
          ref = function() return "com.example.MyTest#testMethod" end
        }
      }
    }
  }
}
```

### 3. Spec Builder (`core/spec_builder/init.lua`)

Constructs the test execution specification, including command, arguments, and context.

**Workflow:**
1. Detect project type (Maven/Gradle)
2. Identify project structure (single-module vs multi-module)
3. Trigger compilation via JDTLS
4. Build JUnit command with classpath
5. Configure debug settings if using DAP strategy

**Key Dependencies:**
- `BuildTool`: Provides build-system-specific logic
- `Project/Module`: Models project structure
- `CommandBuilder`: Constructs JUnit command
- `LspCompiler`: Triggers compilation

**Output:**
```lua
neotest.RunSpec {
  command = "/path/to/java",
  args = { "-jar", "junit.jar", "--select-method=...", "--reports-dir=..." },
  cwd = "/project/root",
  context = {
    reports_dir = "/project/target/junit-reports/170326143045",
    strategy = "integrated" | "dap"
  }
}
```

### 4. Command Builder (`command/junit_command_builder.lua`)

Builds the JUnit Platform Console command with all necessary arguments.

**Configures:**
- Java binary path
- JUnit jar location
- JVM arguments (memory, debug flags)
- Test selection (method/class)
- Classpath files
- Reports directory
- Spring property files
- Debug port (for DAP strategy)

**Example Command:**
```bash
/path/to/java \
  -Xmx512m \
  -agentlib:jdwp=transport=dt_socket,server=y,suspend=y,address=5005 \
  -jar /path/to/junit-platform-console-standalone.jar \
  --select-method=com.example.MyTest#testMethod \
  --classpath=/tmp/classpath123.txt \
  --reports-dir=/project/target/junit-reports/170326143045 \
  --config=spring.config.location=file:./application-test.yml
```

### 5. LSP Compiler (`core/spec_builder/compiler/lsp_compiler.lua`)

Integrates with nvim-jdtls to compile Java sources before running tests.

**Features:**
- Incremental compilation (only changed files)
- Full compilation (clean rebuild)
- Uses JDTLS `java/buildWorkspace` LSP request
- Obtains classpath from JDTLS

**Compilation Modes:**
- `incremental`: Fast, compiles only changed files (default)
- `full`: Slower, rebuilds entire project

### 6. Result Builder (`core/result_builder.lua`)

Parses JUnit XML reports and converts them to Neotest result format.

**Workflow:**
1. Wait for test execution to complete
2. Scan reports directory for `TEST-*.xml` files
3. Parse XML using `neotest.lib.xml`
4. Group test results by method
5. Match results to test positions
6. **Delete XML report files** after processing

**Report Location:**
```
<build_dir>/junit-reports/<timestamp>/TEST-*.xml

Examples:
- target/junit-reports/170326143045/TEST-MyTest.xml
- build/junit-reports/170326143045/TEST-MyTest.xml
```

**Timestamp Format:** `%d%m%y%H%M%S` (e.g., `170326143045`)

**Output:**
```lua
{
  ["com.example.MyTest::testMethod"] = {
    status = "passed" | "failed" | "skipped",
    errors = { { message = "...", line = 42 } },
    output = "test output..."
  }
}
```

### 7. Project Model (`model/project.lua`, `model/module.lua`)

Models the Java project structure, supporting both single-module and multi-module projects.

**Project:**
- Detects modules by scanning for `pom.xml`/`build.gradle`
- Determines if project is multi-module
- Maps file paths to modules

**Module:**
- Represents a single Maven/Gradle module
- Stores base directory and artifact ID
- Used for per-module test execution

### 8. Build Tool Support (`build_tool/maven.lua`, `build_tool/gradle.lua`)

Provides build-system-specific functionality.

**Responsibilities:**
- Get build directory name (`target` vs `build`)
- Get project filename (`pom.xml` vs `build.gradle`)
- Detect Spring property files
- Extract artifact IDs

### 9. JUnit JAR Management (`install.lua`, `util/junit_version_detector.lua`)

Manages JUnit Platform Console Standalone JAR installation and updates.

**Features:**
- Downloads JAR from Maven Central
- Verifies SHA-256 checksums
- Detects existing versions
- Prompts for upgrades
- Supports JUnit Platform 1.10.x and 1.11.x

## Test Execution Flow

### Normal Test Run (Integrated Strategy)

```
1. User triggers test run
   │
   ▼
2. Neotest calls adapter.build_spec(args)
   │
   ▼
3. Position Discoverer parses file (if needed)
   │
   ▼
4. Spec Builder:
   ├─ Detect project type (Maven/Gradle)
   ├─ Identify module
   ├─ Trigger JDTLS compilation (incremental/full)
   ├─ Get classpath from JDTLS
   ├─ Generate timestamped reports directory
   └─ Build JUnit command
   │
   ▼
5. Neotest executes command asynchronously
   │
   ▼
6. JUnit Platform Console runs tests
   │  └─ Writes XML reports to timestamped directory
   │
   ▼
7. Result Builder:
   ├─ Scans reports directory
   ├─ Parses TEST-*.xml files
   ├─ Maps results to test positions
   └─ Deletes XML files (cleanup)
   │
   ▼
8. Neotest displays results in UI
```

### Debug Test Run (DAP Strategy)

```
1. User triggers debug test run
   │
   ▼
2. Spec Builder adds debug configuration:
   ├─ Allocate random port (5000-9999)
   ├─ Add JDWP agent JVM args
   └─ Set strategy = "dap"
   │
   ▼
3. Launch test process with JDWP
   │  └─ Process waits for debugger on port
   │
   ▼
4. Attach nvim-dap debugger
   │  ├─ Configure DAP with host/port
   │  └─ Connect to JDWP agent
   │
   ▼
5. Test executes with breakpoints
   │
   ▼
6. Results processed normally
```

## Data Flow

### Position ID Resolution

Position IDs uniquely identify tests and must match JUnit's output format.

**File → Position ID:**
```
File: src/test/java/com/example/MyTest.java

Tree-sitter Parse:
  └─ class MyTest
      └─ method testFoo()

Position ID Generation:
  namespace: com.example.MyTest
  test: com.example.MyTest::testFoo

Position Ref (JUnit format):
  com.example.MyTest#testFoo
```

**JUnit XML → Result Mapping:**
```xml
<testcase classname="com.example.MyTest" name="testFoo" />
```

Maps to position ID: `com.example.MyTest::testFoo`

### Classpath Management

```
1. JDTLS maintains project classpath
   │
   ▼
2. Spec Builder requests classpath
   │  └─ LSP request: workspace/executeCommand
   │      command: java.project.getClasspaths
   │
   ▼
3. JDTLS returns classpaths:
   {
     classPaths: ["/path/to/classes", ...],
     modulePaths: [...],
   }
   │
   ▼
4. Write classpath to temp file:
   /tmp/neotest-java-classpath-XXXXXX.txt
   │
   ▼
5. Pass to JUnit:
   --classpath=/tmp/neotest-java-classpath-XXXXXX.txt
```

## Integration Points

### Neotest Core

neotest-java implements the Neotest adapter interface:

```lua
{
  name = "neotest-java",
  root = function(dir) end,
  filter_dir = function(name, rel_path, root) end,
  is_test_file = function(file_path) end,
  discover_positions = function(file_path) end,
  build_spec = function(args) end,
  results = function(spec, result, tree) end,
}
```

### nvim-jdtls (Language Server)

**Used for:**
- Compilation: `java/buildWorkspace` request
- Classpath: `workspace/executeCommand` with `java.project.getClasspaths`
- Java runtime detection: `settings.java.home`

**Requirements:**
- Active JDTLS client for the buffer
- Project must be initialized by JDTLS

### nvim-dap (Debug Adapter Protocol)

**Used for:**
- Attaching debugger to test JVM
- Breakpoint support
- REPL output

**Configuration:**
```lua
{
  type = "java",
  request = "attach",
  hostName = "127.0.0.1",
  port = 5005,  -- Random port allocated by adapter
}
```

### nvim-treesitter

**Used for:**
- Parsing Java source files
- Identifying test classes and methods
- Extracting position information

**Requires:**
- Java parser installed: `:TSInstall java`

### JUnit Platform Console Standalone

**Execution:**
```bash
java -jar junit-platform-console-standalone.jar \
  --select-method=com.example.MyTest#testMethod \
  --reports-dir=/path/to/reports
```

**Input:**
- Test selection (method/class)
- Classpath file
- Reports directory

**Output:**
- XML reports: `TEST-*.xml` in reports directory
- Exit code: 0 (success), 1 (test failures), 2+ (errors)

## Directory Structure

```
lua/neotest-java/
├── init.lua                          # Adapter entry point
├── default_config.lua                # Default configuration
├── health.lua                        # Health check (:checkhealth)
├── logger.lua                        # Logging utilities
├── context_holder.lua                # Global adapter context
├── install.lua                       # JUnit JAR installer
├── method_id_resolver.lua            # Resolves parameterized test IDs
│
├── core/                             # Core adapter logic
│   ├── root_finder.lua               # Find project root
│   ├── file_checker.lua              # Identify test files
│   ├── dir_filter.lua                # Filter test directories
│   ├── positions_discoverer.lua     # Parse test positions
│   ├── result_builder.lua            # Process test results
│   │
│   ├── spec_builder/                 # Build test execution spec
│   │   ├── init.lua                  # Main spec builder
│   │   └── compiler/                 # Compilation subsystem
│   │       ├── init.lua
│   │       ├── lsp_compiler.lua      # JDTLS integration
│   │       ├── client_provider.lua   # LSP client lookup
│   │       └── classpath_provider.lua # Classpath extraction
│   │
│   └── position_ids/                 # Position ID generators
│       ├── namespace_id.lua          # Class IDs
│       ├── test_method_id.lua        # Method IDs
│       └── parameterized_test_method_id.lua
│
├── command/                          # Command execution
│   ├── junit_command_builder.lua     # Build JUnit commands
│   ├── command_executor.lua          # Execute commands
│   ├── binaries.lua                  # Locate Java binaries
│   └── run.lua                       # Run command helpers
│
├── build_tool/                       # Build system support
│   ├── init.lua                      # Build tool registry
│   ├── maven.lua                     # Maven-specific logic
│   └── gradle.lua                    # Gradle-specific logic
│
├── model/                            # Domain models
│   ├── path.lua                      # Path manipulation
│   ├── project.lua                   # Project structure
│   ├── module.lua                    # Maven/Gradle module
│   ├── junit_result.lua              # JUnit result model
│   └── patterns.lua                  # Regex patterns
│
└── util/                             # Utilities
    ├── dir_scan.lua                  # Directory scanning
    ├── read_file.lua                 # File reading
    ├── flat_map.lua                  # Functional utilities
    ├── resolve_package_name.lua      # Extract package from file
    ├── read_xml_tag.lua              # XML parsing helpers
    ├── random_port.lua               # Debug port allocation
    ├── junit_version_detector.lua    # Detect JUnit versions
    ├── spring_property_filepaths.lua # Find Spring config files
    ├── checksum.lua                  # SHA-256 verification
    └── detect_project_type.lua       # Maven vs Gradle detection
```

## Design Decisions

### 1. Why use JDTLS for compilation?

**Rationale:**
- **Speed**: Incremental compilation is much faster than full Maven/Gradle builds
- **Reliability**: Leverages the same compiler used by the LSP
- **Integration**: Already running in Neovim, no external process needed
- **Classpath**: JDTLS maintains accurate classpath information

**Alternative considered:**
- Using Maven/Gradle directly was slow and unreliable for quick test iterations

### 2. Why timestamped report directories?

**Rationale:**
- **Parallelism**: Multiple test runs can execute simultaneously without conflicts
- **Isolation**: Each run has its own reports directory
- **Cleanup**: Easy to identify and delete old reports

**Format:** `<build_dir>/junit-reports/<timestamp>/`

Example: `target/junit-reports/170326143045/`

### 3. Why delete XML reports after processing?

**Rationale:**
- **Cleanliness**: Prevents accumulation of test artifacts
- **Disk space**: XML reports can grow large over time
- **User experience**: Users don't see leftover test files

**Implementation:**
- Reports are deleted immediately after parsing in `result_builder.lua:125-132`
- Errors during deletion are logged but don't fail the test run

### 4. Why use JUnit Platform Console Standalone?

**Rationale:**
- **Standard**: Official JUnit test runner
- **XML output**: Produces structured test results
- **Flexible**: Supports test selection by method/class
- **Portable**: Single JAR, no complex dependencies

**Alternative considered:**
- Custom test runner would require maintaining compatibility with JUnit versions

### 5. Why support both single-module and multi-module projects?

**Rationale:**
- **Real-world projects**: Many Java projects use multi-module structures
- **Correct classpath**: Each module has its own dependencies
- **Isolated execution**: Tests run in the correct module context

**Implementation:**
- `Project.from_dirs_and_project_file()` scans for all `pom.xml`/`build.gradle` files
- `Project.find_module_by_filepath()` maps files to modules

### 6. Why position refs use `#` but position IDs use `::`?

**Rationale:**
- **Position ID (`::`)**: Internal identifier used by Neotest
- **Position ref (`#`)**: Matches JUnit's method descriptor format
- **Conversion**: `ref()` function converts `::` to `#` for JUnit

**Example:**
```lua
position.id = "com.example.MyTest::testFoo"
position.ref() = "com.example.MyTest#testFoo"  -- JUnit format
```

### 7. Why dependency injection pattern?

**Rationale:**
- **Testability**: Easy to mock dependencies in unit tests
- **Flexibility**: Allows swapping implementations
- **Isolation**: Components don't directly depend on global state

**Example:**
```lua
SpecBuilder({
  mkdir = vim.uv.fs_mkdir,  -- Can be mocked in tests
  compile = compilers.lsp.compile,
  classpath_provider = ClasspathProvider(),
})
```

### 8. Why `context_holder.lua`?

**Rationale:**
- **Singleton**: Ensures single adapter instance across Neovim session
- **State management**: Holds global adapter state
- **Access**: Other modules can access adapter context without circular dependencies

**Usage:**
```lua
local ch = require("neotest-java.context_holder")
local adapter = ch.adapter
```

---

## Contributing

When modifying the architecture:

1. **Update this document** to reflect changes
2. **Add tests** for new components
3. **Document dependencies** clearly
4. **Follow existing patterns** for consistency

## References

- [Neotest Adapter API](https://github.com/nvim-neotest/neotest/blob/master/doc/neotest.txt)
- [JUnit Platform Console](https://junit.org/junit5/docs/current/user-guide/#running-tests-console-launcher)
- [nvim-jdtls Documentation](https://github.com/mfussenegger/nvim-jdtls)
- [Tree-sitter Java Grammar](https://github.com/tree-sitter/tree-sitter-java)
