## Why

The plugin uses constructor-based dependency injection internally, but the public adapter entry point (`NeotestJavaAdapter(config, deps)`) only exposes a narrow set of overridable components (`root_finder`, `check_junit_jar_deps`). Users cannot swap core components like `client_provider`, `classpath_provider`, `binaries`, `lsp_compiler`, `build_tool_getter`, or `method_id_resolver`. This blocks real-world use cases: custom LSP clients (coc.nvim), custom classpath resolution (Bazel, custom Gradle plugins), custom build tools (Ant, Bazel), custom compilation strategies (shell commands, skip compilation), and testability for downstream plugins.

## What Changes

- Expand the public `deps` API to allow overriding all major injectable components at the adapter call site
- Add clear `@class` type annotations for each injectable component interface
- Maintain backward compatibility: all overrides are optional, defaults remain unchanged
- Document the public DI API with examples in the README

## Capabilities

### New Capabilities

- `public-di-api`: Public dependency injection API allowing users to override core adapter components (client_provider, classpath_provider, binaries, lsp_compiler, build_tool_getter, method_id_resolver)

### Modified Capabilities

- `build-tool`: Build tool getter becomes overridable via public deps (implementation detail, no spec-level behavior change)

## Impact

- **Code**: `lua/neotest-java/init.lua` — expand `neotest-java.Dependencies` class and wire overrides through component construction
- **APIs**: Public adapter signature gains new optional fields in the `deps` table
- **Dependencies**: None — purely additive, no new external dependencies
- **Systems**: No breaking changes; existing configurations continue to work unchanged
