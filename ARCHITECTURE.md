# Architecture

This document describes how neotest-java is put together internally: the
module layering, the dependency-injection style used throughout, and the
main flows that connect neotest to a running JUnit process and back.

It is aimed at anyone reading the codebase for the first time. For
contributor conventions (branching, commits, test-writing rules, OpenSpec
workflow) see [AGENTS.md](./AGENTS.md).

## Layering

The codebase is organized in layers, each depending only on the layers
below it:

```text
util/         <- no internal dependencies (wraps I/O, string/xml helpers)
model/        <- depends on util/ (Path, Project, Module, JunitResult, ...)
core/         <- depends on model/ + util/ (discovery, spec building, results)
command/      <- depends on model/ (junit command construction, process exec)
build_tool/   <- depends on model/ + util/ (Maven/Gradle specifics)
init.lua      <- composition root; wires everything into a neotest.Adapter
```

`core/` is the biggest layer and is itself split into sub-areas:
`core/spec_builder/` (building the command that will run tests) and
`core/position_ids/` (computing stable IDs for test/namespace positions).

### The function-as-constructor DI pattern

Almost every component in this codebase is a plain function that takes a
`deps` table and returns a table of public methods — not a class, not a
metatable-based OOP construct (a few low-level types such as
`model/path.lua`, `model/project.lua`, `model/junit_result.lua` and
`command/junit_command_builder.lua` are the exception; see
[Known trade-offs](#known-trade-offs--areas-for-future-improvement)).

```lua
-- lua/neotest-java/core/file_checker.lua
local FileChecker = function(dependencies)
  return {
    is_test_file = function(file_path)
      -- uses dependencies.root_getter, dependencies.patterns
    end,
  }
end
```

Two conventions make this pattern testable and composable:

1. **Constructors accept a `deps` table, not positional args.** This lets
   callers pass only what they need and lets tests inject stub
   collaborators (fake filesystem, fake LSP client, fake command
   executor) without touching real I/O.
2. **Defaults are merged field-by-field, not by replacing the whole
   table.** See `resolve_deps` in `lua/neotest-java/init.lua:96-118`,
   which fills in a real `client_provider`, `classpath_provider`,
   `binaries`, etc. only for fields the caller didn't supply. This is
   also how `lua/neotest-java/util/xml_reader.lua:46-51` and
   `lua/neotest-java/core/junit_result_reader.lua:41-46` behave.

`lua/neotest-java/init.lua` is the composition root: it is the only place
where real dependencies (neotest's `lib`, `nio`, `vim.uv`, `vim.lsp`) are
wired into the constructors described above, and the only exported
`neotest-java.Adapter` table is built there.

## Module responsibilities

- **`util/`** — small, dependency-free (or nearly so) helpers: reading
  files (`read_file.lua`), computing checksums (`checksum.lua`), scanning
  directories (`dir_scan.lua`), a generic dotted-path XML reader
  (`xml_reader.lua`), detecting whether a project is Maven/Gradle
  (`detect_project_type.lua`), resolving a Java file's package name
  (`resolve_package_name.lua`), and detecting/comparing installed JUnit
  jar versions (`junit_version_detector.lua`).
- **`model/`** — value objects used across the codebase: `path.lua`
  (a cross-platform path wrapper — see "Path handling" in AGENTS.md),
  `project.lua`/`module.lua` (a project's modules, derived from scanned
  directories and the build tool's project filename), `patterns.lua`
  (regex helpers), and `junit_result.lua` (wraps a parsed JUnit XML
  `<testcase>` node and converts it into a `neotest.Result`).
- **`core/`** — the adapter's behavior: `file_checker.lua` (is this file
  a test file?), `dir_filter.lua` (which directories to skip when
  scanning), `positions_discoverer.lua` (tree-sitter query → neotest
  position tree), `root_finder.lua` (locate the project root),
  `spec_builder/` (build the `neotest.RunSpec` for a run), and
  `result_builder.lua` + `junit_result_reader.lua` (turn JUnit XML output
  back into `neotest.Result`s).
- **`core/spec_builder/`** — orchestrates everything needed to produce a
  runnable command: build-tool detection, classpath resolution via the
  LSP client (`compiler/classpath_provider.lua`), triggering a
  workspace/incremental compile via `java/buildWorkspace`
  (`compiler/lsp_compiler.lua`), and delegating command construction to
  `command/junit_command_builder.lua`.
- **`core/position_ids/`** — computes the stable position IDs neotest
  uses to correlate tree nodes with JUnit results: `namespace_id.lua` for
  test classes, `test_method_id.lua` for plain `@Test` methods, and
  `parameterized_test_method_id.lua` for `@ParameterizedTest` /
  `@TestFactory` / `@CartesianTest` methods where the same source method
  produces multiple JUnit testcases at runtime.
- **`command/`** — everything related to invoking
  `junit-platform-console-standalone`: `junit_command_builder.lua` (a
  fluent builder assembling the java/JUnit CLI invocation),
  `binaries.lua` (locating `java`/`javap` via the LSP client),
  `command_executor.lua` (a small process-execution wrapper), and
  `run.lua`.
- **`build_tool/`** — the Maven/Gradle strategy implementations (see
  below) plus `launcher.lua`, which starts a JVM with a debug agent
  attached and waits for it to start listening, for `dap` strategy runs.

## End-to-end flows

### Test discovery flow

1. Neotest asks the adapter whether a directory should be scanned at all:
   `filter_dir = dir_filter.filter_dir` in `lua/neotest-java/init.lua:243`
   excludes `target`, `build`, `out`, `bin`, `resources`, `main` (unless
   `test` appears in the path) — see
   `lua/neotest-java/core/dir_filter.lua:1-31`.
2. For each remaining file, neotest asks `is_test_file`, wired to
   `file_checker.is_test_file` in `lua/neotest-java/init.lua:244`. This
   checks the file is not under a `main` directory (relative to the
   project root) and that its filename (without extension) matches one
   of `config.test_classname_patterns` —
   `lua/neotest-java/core/file_checker.lua:14-35`.
3. For matching files, neotest calls `discover_positions`, wired to
   `PositionsDiscoverer(...).discover_positions` in
   `lua/neotest-java/init.lua:245-247`. This runs a tree-sitter query for
   Java `class_declaration`s and `@Test`/`@ParameterizedTest`/
   `@TestFactory`/`@CartesianTest` annotated methods
   (`lua/neotest-java/core/positions_discoverer.lua:117-141`), builds a
   `neotest.Tree`, and computes each node's ID via `position_id`
   (`lua/neotest-java/core/positions_discoverer.lua:59-71`), which
   delegates to `namespace_id.lua` for classes and `test_method_id.lua`
   for methods.
4. Each `test`-type node is given a lazy `ref()` function
   (`lua/neotest-java/core/positions_discoverer.lua:169-202`) that, when
   invoked later, calls `deps.method_id_resolver.resolve_complete_method_id`
   (`lua/neotest-java/method_id_resolver.lua:18-77`) to disambiguate
   overloaded method names using `javap` against the module's classpath.
   This keeps discovery itself fast (no `javap` invocation) while still
   producing a JUnit-compatible selector when a test is actually run.

### Spec building flow

1. Neotest calls `build_spec`, wired in
   `lua/neotest-java/init.lua:259-263`. This first resolves the actual
   JUnit console jar path via `check_junit_jar`
   (`lua/neotest-java/init.lua:120-143`, which falls back to
   auto-detecting an already-downloaded jar), then delegates to
   `spec_builder.build_spec`.
2. `lua/neotest-java/core/spec_builder/init.lua:34-146` does the actual
   work: it re-resolves the project root with `root_finder.find_root`
   (line 45), detects whether the project is Maven or Gradle with
   `detect_project_type` (line 48), and fetches the corresponding
   `neotest-java.BuildTool` from `build_tool_getter` (line 51).
3. It scans the root for project files, builds a `Project`/`Module`
   model (`Project.from_dirs_and_project_file`, line 56-59), and picks
   the module the test file belongs to (or the single module, for
   non-multimodule projects) — lines 61-69.
4. It ensures the module's build directory exists (lines 71-75), locates
   the `java` binary via `deps.binaries.java` (line 83), and computes the
   JUnit report output directory via `report_folder_name_gen` (line 88).
5. It triggers compilation through the injected `compile` function
   (line 98), which in `init.lua` calls
   `resolved.lsp_compiler.compile`, i.e.
   `lua/neotest-java/core/spec_builder/compiler/lsp_compiler.lua:8-45` —
   this sends a `java/buildWorkspace` LSP request (full or incremental,
   depending on `config.incremental_build`) and does not block the
   command from being built (compilation failures are only logged).
6. It asks `classpath_provider.get_classpath` (line 100) for the
   module's runtime + test classpath, obtained via two
   `workspace/executeCommand` (`java.project.getClasspaths`) LSP
   requests —
   `lua/neotest-java/core/spec_builder/compiler/classpath_provider.lua:43-67`.
7. It hands everything to `command/junit_command_builder.lua`, which
   assembles the final `java -jar junit-platform-console-standalone.jar
   execute ...` argument list, including `--select-method`/
   `--select-class` selectors derived from the position tree
   (`add_test_references_from_tree`,
   `lua/neotest-java/command/junit_command_builder.lua:82-122`).
8. If `args.strategy == "dap"`, instead of returning the command to run
   normally, `spec_builder` picks a random debug port
   (`lua/neotest-java/core/spec_builder/init.lua:108-125`), launches the
   JVM itself via `launcher.launch_debug_test`
   (`lua/neotest-java/build_tool/launcher.lua:15-69`, which waits for the
   JDWP agent to report "Listening" before returning), and returns a
   `neotest.RunSpec` whose `strategy` describes a DAP `attach` request —
   neotest's own strategy runner does nothing in this case; the JVM
   process is already running.

### Results flow

1. After the strategy runner (or `launcher.launch_debug_test`) exits,
   neotest calls `results`, wired to `ResultBuilder(...).build_results`
   in `lua/neotest-java/init.lua:248-255`.
2. `lua/neotest-java/core/result_builder.lua:52-103`: if the process
   exited with an unexpected code (not `0` or `1`), it short-circuits
   with a single `JunitResult.ERROR` for the root node (line 53-56). For
   the `dap` strategy it first awaits `terminated_command_event` (line
   58-60) so it doesn't read report files before the JVM has finished
   writing them.
3. It scans `spec.context.reports_dir` for `TEST-*.xml` files (line 43-45)
   and passes them to `junit_result_reader.read_all`
   (`lua/neotest-java/core/junit_result_reader.lua:53-81`), which uses
   `util/xml_reader.lua` to parse each file and wraps every
   `<testcase>` element in a `neotest-java.JunitResult`
   (`lua/neotest-java/model/junit_result.lua:107-110`). Parse errors on
   individual files are logged and skipped; the rest of the batch is
   still processed.
4. Results are grouped by a "method base" ID
   (`group_by_method_base`, `lua/neotest-java/core/result_builder.lua:11-19`)
   because a single `@ParameterizedTest`/`@TestFactory` source method
   produces multiple JUnit testcases (one per invocation/iteration).
   Groups of one are converted directly via `JunitResult:result()`
   (line 73); groups of more than one are combined with
   `JunitResult.merge_results` (line 86,
   `lua/neotest-java/model/junit_result.lua:265-322`), which picks an
   overall pass/fail status, concatenates output, and matches the group
   back to the correct tree node ID by string-stripping the
   `[n]`-iteration suffix (`clean_id`, line 6-8).
5. Report files are deleted after processing (lines 93-100), and the
   final `table<string, neotest.Result>` is returned to neotest, which
   updates the UI.

### Root finding

`lua/neotest-java/core/root_finder.lua:22-55` resolves the project root
with an explicit priority order, using `neotest.lib.files.match_root_pattern`
against `.git`, `pom.xml`, `settings.gradle(.kts)`, `build.gradle(.kts)`,
`mvnw`, and `gradlew`:

1. **`.git` + a build file/wrapper at the same directory** — preferred,
   because in a multi-module project a closer ancestor directory may
   also contain a build file, and the repo root (marked by `.git`) is
   the more useful project root for cross-module lookups.
2. **Nearest build file or wrapper**, with no `.git` requirement — used
   when no `.git` root exists, or the `.git` root has no matching build
   file.
3. **`.git` alone**, as a last resort, if a build file was never found.
4. If none of the above match, `find_root` returns `nil`; the adapter
   still works file-by-file in that case, it just can't resolve
   multi-module structure.

## Build tool strategy: Maven vs Gradle

`lua/neotest-java/build_tool/build_tool.lua` defines a small factory,
`create_build_tool(config, deps)`, that both Maven and Gradle instantiate
in `lua/neotest-java/build_tool/init.lua`. The factory provides the
shared shape of a `neotest-java.BuildTool` (`get_build_dirname`,
`get_project_filename`, `get_artifact_id`, `get_spring_property_filepaths`)
and forwards each call to tool-specific config functions plus a shared
`deps` table (`read_xml_tag`, `generate_spring_property_filepaths`).

What differs between the two configs:

- **Project filename**: Maven uses the literal `"pom.xml"`; Gradle uses
  the Lua pattern `"%.gradle"` (matched against `build.gradle` or
  `build.gradle.kts`), since Gradle projects don't have one fixed name.
- **Build directory**: Maven reads `project.build.directory` out of
  `pom.xml` via `read_xml_tag` (defaulting to `target`); Gradle always
  returns `bin` (the default output directory used by JDT.LS'
  `java.project.getClasspaths` bridge for Gradle projects).
- **Artifact ID**: Maven reads `project.artifactId` from `pom.xml`
  (falling back to the directory name); Gradle just uses the directory
  name, since Gradle has no single canonical "artifact id" tag to read.
- **Spring config subdirectories**: used to build the
  `spring.config.additional-location` JVM argument so Spring Boot tests
  pick up `application.properties`/`.yml` from the compiled output.
  Maven looks under `classes`/`test-classes`; Gradle looks under
  `main`/`test`, matching each tool's own output layout.

## Testing

See [AGENTS.md](./AGENTS.md) for full contributor conventions, including
the unit vs. "social" spec distinction, the `mini.test` framework, the
`async_helpers` wrapper for `nio`-dependent tests, and the pre-commit
hook chain.

## Known trade-offs / areas for future improvement

- **Inconsistent construction style.** Most of the codebase follows the
  function-as-constructor DI pattern described above, but a handful of
  core types (`model/path.lua`, `model/project.lua`,
  `model/junit_result.lua`, `command/junit_command_builder.lua`) are
  implemented as classic Lua metatable "classes" instead. This is a
  reasonable choice for value objects/builders with many small methods,
  but it means two different construction idioms coexist in the same
  codebase and a new contributor has to learn both.
- **`model/junit_result.lua` carries a lot of JUnit XML parsing
  heuristics in one 300+ line file** — regex-based failure-message
  extraction (`failure_message_from_output`, `failure_from_node`),
  special-casing for `xml2lua`'s single-vs-array node ambiguity, and
  line-number recovery from stack-trace text
  (`JunitResult:errors`). It works, but it is dense and any change to
  the JUnit report format (or the underlying XML library) touches many
  code paths in this one file at once.
- **`core/positions_discoverer.lua` calls into `nio.run(...).wait()`
  inside a `vim.schedule` callback** to resolve overloaded method names
  lazily (`ref()`, lines 169-202). This works, but the control flow
  (fast event → scheduler → nio coroutine → command executor → back)
  is hard to follow from a single read and would benefit from an inline
  comment trail or a small sequence diagram if it needs to be modified
  again.
- **Build-tool detection and root-finding are somewhat duplicated.**
  `spec_builder/init.lua` re-derives the "real" project root via
  `root_finder.find_root` even though `init.lua`'s own `root_getter`
  already caches one — this is intentional (spec building may run for a
  file outside the cached root in monorepo-like setups) but is not
  obvious without reading both files together.
- **Windows support is patched in via targeted branches** (e.g.
  `method_id_resolver.lua`'s `platform("win32")` check to avoid
  `bash -c`, `classpath_provider.lua`'s path separator injection) rather
  than a single cross-platform abstraction, so Windows-specific behavior
  is spread across several files instead of centralized in one place.
</content>
